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

  List<DelayItem> delayList = [];
  bool isTesting = false;
  int successCount = 0;
  int totalCount = 0;
  int timeout = 0;
  String? message;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadProxyList();
      _testDelay();
    });
  }

  Future<void> _loadProxyList() async {
    try {
      final config = await yamlRead(configPath);

      final proxies = (config['proxies'] as List? ?? []).map((e) => e['name'] as String).toList();

      delayList = proxies.map((e) => DelayItem(e, -1)).toList();

      totalCount = delayList.length;
      successCount = 0;

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      showSnackBarGlobal("error", '$e');
    }
  }

  Future<void> _testDelay() async {
    final close = showSnackBarGlobal("load", "请稍候...");

    if (mounted) {
      setState(() => isTesting = true);
    }

    try {
      final config = await yamlRead(configPath);

      final proxies = (config['proxies'] as List? ?? []).map((e) => e['name'] as String).toList();

      final settings = await yamlRead(dataPath);

      final port = settings['port'];
      final url = settings['url'];

      timeout = settings['testtimeout'];
      final expected = settings['expected'];

      for (int i = 1; i < 7; i++) {
        try {
          final r = await HttpClient().getUrl(Uri.parse('http://127.0.0.1:$port/version')).then((req) => req.close());

          if (r.statusCode == 200) {
            break;
          }
        } catch (_) {}

        if (i == 6) return;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final uri = Uri.parse('http://127.0.0.1:$port/group/GLOBAL/delay?url=$url&timeout=$timeout&expected=$expected');


      final req = await HttpClient().getUrl(uri);
      final res = await req.close();

      final body = await res.transform(utf8.decoder).join();

      final Map<String, dynamic> jsonData = json.decode(body);

      if (jsonData.containsKey('message')) {
        message = jsonData['message'] as String?;

        successCount = 0;
      } else {
        message = null;

        final List<DelayItem> list = [];

        for (final name in proxies) {
          final delay = jsonData[name];

          if (delay == null) {
            list.add(DelayItem(name, 0));
          } else {
            list.add(DelayItem(name, delay as int));
          }
        }

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
      }
      close();
    } catch (e) {
      close();
      showSnackBarGlobal("error", '$e');
    }
    if (mounted) {
      setState(() {});
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
            if (message != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(message!, style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold)),
                ),
              )
            else ...[
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
              }).toList(),
            ],
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
