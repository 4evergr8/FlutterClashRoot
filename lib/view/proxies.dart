import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mihomoR/service/path.dart';
import 'package:mihomoR/service/subscriptions.dart';
import 'package:mihomoR/widget.dart';

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

class _ProxiesViewState extends State<ProxiesView>
    with AutomaticKeepAliveClientMixin {
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
      final config = await readYamlAsMap(configPath);

      final proxies = (config['proxies'] as List? ?? [])
          .map((e) => e['name'] as String)
          .toList();

      delayList = proxies.map((e) => DelayItem(e, -1)).toList();

      totalCount = delayList.length;
      successCount = 0;

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      showErrorSnackBarGlobal('$e');
    }
  }

  Future<void> _testDelay() async {
    final close = await showLoadingDialogGlobal();

    if (mounted) {
      setState(() => isTesting = true);
    }

    try {
      final config = await readYamlAsMap(configPath);

      final proxies = (config['proxies'] as List? ?? [])
          .map((e) => e['name'] as String)
          .toList();

      final settings = await readYamlAsMap(settingsPath);

      final port = settings['port'];
      final url = settings['url'];

      timeout = settings['testtimeout'];

      final uri = Uri.parse(
        'http://127.0.0.1:$port/group/GLOBAL/delay?url=$url&timeout=$timeout',
      );

      final req = await HttpClient().getUrl(uri);
      final res = await req.close();

      final body = await res.transform(utf8.decoder).join();

      final Map<String, dynamic> data = json.decode(body);

      if (data.containsKey('message')) {
        message = data['message'] as String?;

        successCount = 0;
      } else {
        message = null;

        final List<DelayItem> list = [];

        for (final name in proxies) {
          final delay = data[name];

          if (delay == null) {
            list.add(DelayItem(name, 0));
          } else {
            list.add(DelayItem(name, delay as int));
          }
        }

        totalCount = list.length;

        successCount = list.where((e) => e.delay > 0 && e.delay < timeout).length;

        list.sort((a, b) {
          final at = a.delay;
          final bt = b.delay;

          final aBad = at <= 0 || at >= timeout;
          final bBad = bt <= 0 || bt >= timeout;

          if (aBad && !bBad) return 1;
          if (!aBad && bBad) return -1;

          return at.compareTo(bt);
        });

        delayList = list;

        final subsData = await readYamlAsMap(subscriptionsPath);

        final subs = (subsData['subscriptions'] is List)
            ? List<Map<String, dynamic>>.from(
          subsData['subscriptions'],
        )
            : <Map<String, dynamic>>[];

        final selectedSub = subs.firstWhere(
              (sub) => sub['select'] == true,
        );

        selectedSub['count'] = totalCount;
        selectedSub['alive'] = successCount;

        await writeYamlFromMap(
          {'subscriptions': subs},
          subscriptionsPath,
        );
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      showErrorSnackBarGlobal('$e');
    } finally {
      close();

      if (mounted) {
        setState(() => isTesting = false);
      }
    }
  }

  Color _getColor(BuildContext context, int delay) {
    final cs = Theme.of(context).colorScheme;
    final t = timeout;

    if (delay == -1) return cs.outline;        // 未测试
    if (delay <= 0 || delay > t) return cs.error; // 完全不可用

    if (delay <= 1000) return cs.primary;       // 很健康
    if (delay <= 2000) return cs.secondary;     // 一般
    if (delay <= t) return cs.tertiary;        // 很差

    return cs.error; // 冗余兜底
  }
  String _formatDelay(int delay) {
    if (delay == -1) return '--';
    if (delay <= 0) return 'timeout';
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
                  child: Text(
                    message!,
                    style: TextStyle(
                      color: colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            else ...[
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  title: const Text('节点可用率'),
                  subtitle: totalCount == 0
                      ? const Text('暂无可用节点')
                      : Text('$successCount / $totalCount'),
                  trailing: Text(
                    totalCount == 0
                        ? '--'
                        : '${(successCount * 100 ~/ totalCount)}%',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              ...delayList.map((item) {
                final color = _getColor(context, item.delay);

                final isAlive = item.delay > 0 && item.delay < timeout;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  color: colorScheme.surface,
                  child: ListTile(
                    title: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(_formatDelay(item.delay)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatDelay(item.delay),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: item.delay == -1
                              ? colorScheme.outline
                              : (isAlive
                              ? color
                              : colorScheme.error),
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