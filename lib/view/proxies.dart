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

  bool _disposed = false;

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

  // GLOBAL 里除了真实节点，还包含其他代理组和 DIRECT 等内置代理
  static const _builtinNames = {'GLOBAL', 'DIRECT', 'REJECT', 'REJECT-DROP', 'COMPATIBLE', 'PASS'};

  List<DelayItem> delayList = [];
  bool isTesting = false;
  bool isWaiting = false;
  int successCount = 0;
  int totalCount = 0;
  int timeout = 0;

  @override
  void dispose() {
    _disposed = true;
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

  /// 请求失败就一直重试，核心没起来或还没加载完节点时不会放弃
  Future<HttpClientResponse> _get(Uri uri, String secret) async {
    while (!_disposed) {
      try {
        final req = await _client.getUrl(uri);
        req.headers.set('Authorization', 'Bearer $secret');
        return await req.close();
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 500));
    }

    throw Exception('页面已关闭');
  }

  /// 节点由 proxy-providers 提供，只有核心知道运行时的真实名单
  ///
  /// 核心刚启动时 provider 可能还没拉完订阅，名单会是空的，所以空名单也继续等
  Future<List<String>> _fetchProxyNames(dynamic port, String secret) async {
    while (!_disposed) {
      try {
        final res = await _get(Uri.parse('http://127.0.0.1:$port/proxies'), secret);

        final body = await res.transform(utf8.decoder).join();

        final jsonData = json.decode(body) as Map<String, dynamic>;

        final all = (jsonData['proxies'] as Map?) ?? {};

        final names =
            all.entries
                .where((e) {
                  if (_builtinNames.contains(e.key.toString())) return false;

                  final item = e.value as Map?;
                  if (item == null) return false;

                  final type = item['type'];
                  if (type is String && _groupTypes.contains(type)) return false;

                  // 代理组都带成员列表，真实节点没有
                  return !item.containsKey('all');
                })
                .map((e) => e.key.toString())
                .toList();

        if (names.isNotEmpty) return names;
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 500));
    }

    return [];
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

      final res = await _get(uri, secret);

      final body = await res.transform(utf8.decoder).join();

      final jsonData = json.decode(body) as Map<String, dynamic>;

      return jsonData['delay'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _loadProxyList() async {
    setState(() => isWaiting = true);

    try {
      final settings = await yamlRead(dataPath);

      final port = settings['port'];
      final secret = settings['secret'] ?? '';

      final proxies = await _fetchProxyNames(port, secret);

      if (!mounted) return;

      delayList = proxies.map((e) => DelayItem(e, -1)).toList();

      totalCount = delayList.length;
      successCount = 0;

      setState(() => isWaiting = false);
    } catch (e) {
      if (!mounted) return;

      setState(() => isWaiting = false);
      showSnackBarGlobal("error", '$e');
    }
  }

  Future<void> _testDelay() async {
    if (isTesting) return;

    final close = showSnackBarGlobal("load", "请稍候...");

    setState(() {
      isTesting = true;
      isWaiting = true;
    });

    try {
      final settings = await yamlRead(dataPath);

      final port = settings['port'];
      final secret = settings['secret'] ?? '';
      final url = settings['url'];

      timeout = settings['testtimeout'];

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

      if (!mounted) return;

      setState(() {
        isTesting = false;
        isWaiting = false;
      });
    } catch (e) {
      close();

      if (!mounted) return;

      setState(() {
        isTesting = false;
        isWaiting = false;
      });

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
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (isWaiting)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
                      ),
                      const SizedBox(width: 8),
                      Text('等待核心响应…', style: TextStyle(color: colorScheme.secondary)),
                    ],
                  ),
                ),
              ),

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
