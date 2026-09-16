import 'dart:convert';
import 'dart:io';

import 'package:clashroot/service/path.dart';
import 'package:clashroot/service/yaml.dart';
import 'package:clashroot/widget.dart';
import 'package:flutter/material.dart';

class ProxiesView extends StatefulWidget {
  const ProxiesView({super.key});

  @override
  State<ProxiesView> createState() => _ProxiesViewState();
}

class DelayItem {
  final String name;
  final int delay;

  DelayItem(this.name, this.delay);
}

class _ProxiesViewState extends State<ProxiesView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false;

  final HttpClient _client = HttpClient();

  // 分组与内置类型，从 /proxies 的返回里剔除，只留真实节点
  static const _groupTypes = {
    'Selector',
    'URLTest',
    'Fallback',
    'LoadBalance',
    'Relay',
    'Direct',
    'Reject',
    'RejectDrop',
    'Compatible',
    'Pass',
  };

  List<DelayItem> delayList = [];
  bool isTesting = false;
  int successCount = 0;
  int totalCount = 0;
  int timeout = 0;

  @override
  void dispose() {
    _client.close(force: true);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadProxyList();
      if (delayList.isNotEmpty) _testDelay();
    });
  }

  /// 等待核心就绪
  Future<bool> _waitReady(dynamic port, String secret) async {
    for (var i = 0; i < 6; i++) {
      try {
        final req = await _client.getUrl(Uri.parse('http://127.0.0.1:$port/version'));
        req.headers.set('Authorization', 'Bearer $secret');

        final r = await req.close();

        if (r.statusCode == 200) return true;
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 500));
    }

    return false;
  }

  /// 节点由 proxy-providers 提供，只有核心知道运行时的真实名单
  Future<List<String>> _fetchProxyNames(dynamic port, String secret) async {
    final req = await _client.getUrl(Uri.parse('http://127.0.0.1:$port/proxies'));
    req.headers.set('Authorization', 'Bearer $secret');

    final res = await req.close();

    final body = await res.transform(utf8.decoder).join();

    final jsonData = json.decode(body) as Map<String, dynamic>;

    final all = (jsonData['proxies'] as Map?) ?? {};

    return all.entries
        .where((e) {
          final type = (e.value as Map?)?['type'];
          return type is String && !_groupTypes.contains(type);
        })
        .map((e) => e.key.toString())
        .toList();
  }

  /// 单个节点测速，失败或超时记 0
  Future<int> _fetchDelay(String name, dynamic port, String secret, String url, int timeout) async {
    try {
      final uri = Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: port,
        path: '/proxies/${Uri.encodeComponent(name)}/delay',
        queryParameters: {'url': url, 'timeout': '$timeout'},
      );

      final req = await _client.getUrl(uri);
      req.headers.set('Authorization', 'Bearer $secret');

      final res = await req.close();

      final body = await res.transform(utf8.decoder).join();

      final jsonData = json.decode(body) as Map<String, dynamic>;

      return jsonData['delay'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _loadProxyList() async {
    try {
      final settings = await yamlRead(dataPath);

      final port = settings['port'];
      final secret = settings['secret'] ?? '';

      if (!await _waitReady(port, secret)) {
        throw Exception('核心未响应');
      }

      final proxies = await _fetchProxyNames(port, secret);

      delayList = proxies.map((e) => DelayItem(e, -1)).toList();

      totalCount = delayList.length;
      successCount = 0;

      setState(() {});
    } catch (e) {
      showSnackBarGlobal("error", '$e');
    }
  }

  Future<void> _testDelay() async {
    final close = showSnackBarGlobal("load", "请稍候...");

    setState(() => isTesting = true);

    try {
      final settings = await yamlRead(dataPath);

      final port = settings['port'];
      final secret = settings['secret'] ?? '';
      final url = settings['url'];

      timeout = settings['testtimeout'];

      if (!await _waitReady(port, secret)) {
        throw Exception('核心未响应');
      }

      final proxies = await _fetchProxyNames(port, secret);

      final delays = <String, int>{};

      const batchSize = 32;

      for (var start = 0; start < proxies.length; start += batchSize) {
        final batch = proxies.skip(start).take(batchSize).toList();

        await Future.wait(
          batch.map((name) async {
            delays[name] = await _fetchDelay(name, port, secret, '$url', timeout);
          }),
        );
      }

      final list = proxies.map((e) => DelayItem(e, delays[e] ?? 0)).toList();

      totalCount = list.length;

      successCount = list.where((e) => e.delay > 0 && e.delay < timeout).length;

      list.sort((a, b) {
        if (a.delay <= 0) return 1;
        if (b.delay <= 0) return -1;
        return a.delay.compareTo(b.delay);
      });

      delayList = list;

      final data = await yamlRead(dataPath);

      final subs =
          (data['subscriptions'] is List)
              ? List<Map<String, dynamic>>.from(data['subscriptions'])
              : <Map<String, dynamic>>[];

      final selectedSub = subs.firstWhere((sub) => sub['select'] == true);

      selectedSub['count'] = totalCount;
      selectedSub['alive'] = successCount;

      await yamlWrite(data, dataPath);

      close();
      setState(() {});
    } catch (e) {
      close();
      showSnackBarGlobal("error", '$e');
    }
  }

  Color _getColor(BuildContext context, int delay) {
    final cs = Theme.of(context).colorScheme;
    final t = timeout;

    // 未测试
    if (delay == -1) return cs.outline;

    // timeout 或不可用（包含 0 / 超时）
    if (delay <= 0 || delay > t) return cs.error;

    final step = t / 3;

    if (delay <= 0) return cs.error;
    if (delay >= t) return cs.error;

    if (delay < step) return cs.primary;
    if (delay < step * 2) return cs.secondary;

    return cs.tertiary;
  }

  String _formatDelay(int delay) {
    if (delay == -1) return '--';
    if (delay <= 0 || delay >= timeout) return 'timeout';
    return '$delay ms';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('节点')),
      body: RefreshIndicator(
        onRefresh: _testDelay,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                title: const Text('节点可用率'),
                subtitle: totalCount == 0 ? const Text('暂无可用节点') : Text('$successCount / $totalCount'),
                trailing: Text(
                  totalCount == 0 ? '--' : '${(successCount * 100 ~/ totalCount)}%',
                  style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            ...delayList.map((item) {
              final color = _getColor(context, item.delay);

              final isAlive = item.delay > 0 && item.delay < timeout;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                color: colorScheme.surface,
                child: ListTile(
                  title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(_formatDelay(item.delay)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_formatDelay(item.delay), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: item.delay == -1 ? colorScheme.outline : (isAlive ? color : colorScheme.error),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isTesting ? null : _testDelay,
        child: const Icon(Icons.speed),
      ),
    );
  }
}
