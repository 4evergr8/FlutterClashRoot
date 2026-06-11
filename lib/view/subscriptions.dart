import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mihomoR/service/path.dart';
import 'package:mihomoR/service/subscriptions.dart';
import 'package:mihomoR/widget.dart';

class SubscriptionView extends StatefulWidget {
  const SubscriptionView({super.key});

  @override
  State<SubscriptionView> createState() => _SubscriptionViewState();
}

class _SubscriptionViewState extends State<SubscriptionView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false;
  List<Map<String, dynamic>> subscriptions = [];
  bool isLoading = true;

  String formatSize(int bytes) {
    const mb = 1024 * 1024;
    const gb = mb * 1024;
    const tb = gb * 1024;

    final valueMB = bytes / mb;

    if (valueMB < 1024) {
      return '${valueMB.toStringAsFixed(1)}M';
    }

    final valueGB = bytes / gb;
    if (valueGB < 1024) {
      return '${valueGB.toStringAsFixed(1)}G';
    }

    final valueTB = bytes / tb;
    return '${valueTB.toStringAsFixed(1)}T';
  }

  String formatTimeAgo(String timestampMsStr) {
    final pastMs = int.tryParse(timestampMsStr);
    if (pastMs == null) return '时间格式错误';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    int seconds = (nowMs - pastMs) ~/ 1000;

    if (seconds <= 0) return '刚刚';

    const int secsPerMin = 60;
    const int secsPerHour = secsPerMin * 60;
    const int secsPerDay = secsPerHour * 24;
    const int secsPerMonth = secsPerDay * 30;
    const int secsPerYear = secsPerDay * 365;

    final years = seconds ~/ secsPerYear;
    seconds %= secsPerYear;
    final months = seconds ~/ secsPerMonth;
    seconds %= secsPerMonth;
    final days = seconds ~/ secsPerDay;
    seconds %= secsPerDay;
    final hours = seconds ~/ secsPerHour;
    seconds %= secsPerHour;
    final minutes = seconds ~/ secsPerMin;

    final List<String> parts = [];
    if (years > 0) parts.add('$years年');
    if (months > 0) parts.add('$months个月');
    if (days > 0) parts.add('$days天');
    if (hours > 0) parts.add('$hours小时');
    if (minutes > 0) parts.add('$minutes分');

    if (parts.isEmpty) return '刚刚';
    return '${parts.join()}前';
  }

  void applySubscriptions(List<Map<String, dynamic>> list) {
    final normalized = list.map((e) => Map<String, dynamic>.from(e)).toList();

    normalized.sort((a, b) {
      final aFav = a['favorite'] == true ? 0 : 1;
      final bFav = b['favorite'] == true ? 0 : 1;

      if (aFav != bFav) return aFav - bFav;

      final al = (a['label'] ?? '').toString();
      final bl = (b['label'] ?? '').toString();
      return al.compareTo(bl);
    });

    subscriptions = normalized;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _onSubscriptionTap(String id) async {
    final close = await showLoadingDialogGlobal();
    try {
      final settings = await readYamlAsMap(settingsPath);
      final port = settings['port'];
      final base = await readYamlAsMap("$mainPath/config/$id.yaml");
      final override = await readYamlAsMap(overridePath);
      final yaml = overrideMap(base, override);
      await writeYamlFromMap(yaml, configPath);
      final dio = Dio();
      final params = {'force': 'true'};
      final data = {"path": configPath};
      await dio.put(
        'http://127.0.0.1:$port/configs',
        queryParameters: params,
        data: data,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      await dio.delete(
        'http://127.0.0.1:$port/connections',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
    } catch (e) {
      showErrorSnackBarGlobal('$e');
    } finally {
      close();
    }
  }

  Future<void> _refreshSubscriptions() async {
    final close = await showLoadingDialogGlobal();
    try {
      final data = await readYamlAsMap(subscriptionsPath);
      final settings = await readYamlAsMap(settingsPath);

      final list =
          (data['subscriptions'] is List)
              ? List<Map<String, dynamic>>.from(data['subscriptions'])
              : <Map<String, dynamic>>[];

      final ua = settings['ua'];
      final timeout = settings['timeout'];

      final Map<String, Map<String, dynamic>> resultMap = {for (var s in list) s['id']: Map<String, dynamic>.from(s)};

      final futures =
          list.map((sub) async {
            final id = sub['id'];
            try {
              final downloadResult = await downloadYamlFile(sub['link'], ua, id, timeout);
              return {'id': id, 'data': downloadResult};
            } catch (e) {
              showErrorSnackBarGlobal('${sub['label'] ?? id} 失败: $e');
              return null;
            }
          }).toList();

      final results = await Future.wait(futures);

      for (var r in results) {
        if (r == null) continue;

        final id = r['id'];
        final data = r['data'] as Map<String, dynamic>?;

        if (data == null) continue;

        final old = resultMap[id] ?? {};

        resultMap[id] = {
          ...old,

          // 只允许这些字段被刷新覆盖
          'expire': data['expire'] ?? old['expire'],
          'update': data['update'] ?? old['update'],
          'upload': data['upload'] ?? old['upload'],
          'download': data['download'] ?? old['download'],
          'total': data['total'] ?? old['total'],
        };
      }

      final newList = resultMap.values.toList();
      applySubscriptions(newList); // ✅ 这里会自动 setState
      await writeYamlFromMap({'subscriptions': newList}, subscriptionsPath);
    } catch (e) {
      showErrorSnackBarGlobal('刷新订阅失败: $e');
    } finally {
      close();
    }
  }

  Future<void> _loadSubscriptions() async {
    final close = await showLoadingDialogGlobal();

    try {
      final data = await readYamlAsMap(subscriptionsPath);
      final list = (data['subscriptions'] as List?) ?? [];
      subscriptions = List<Map<String, dynamic>>.from(list);
      applySubscriptions(subscriptions);
    } catch (e) {
      subscriptions = [];
      showErrorSnackBarGlobal('$e');
    } finally {
      close();
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _deleteSubscription(BuildContext context, Map<String, dynamic> sub) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定删除订阅 "${sub['label']}" 吗？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认')),
            ],
          ),
    );

    if (confirm != true) return;

    final close = await showLoadingDialogGlobal();
    try {
      subscriptions.removeWhere((s) => s['id'] == sub['id']);
      final data = {'subscriptions': subscriptions};
      await writeYamlFromMap(data, subscriptionsPath);
      await Process.run('su', ['-c', 'rm -f $mainPath/config/${sub['id']}.yaml']);
      if (sub['select'] == true && subscriptions.isNotEmpty) {
        subscriptions.first['select'] = true;
      }
      applySubscriptions(subscriptions);
      await writeYamlFromMap({'subscriptions': subscriptions}, subscriptionsPath);
    } catch (e) {
      showErrorSnackBarGlobal('$e');
    } finally {
      close();
    }
  }

  Future<void> _addSubscription() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加订阅'),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: controller,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(hintText: '每行一个订阅地址', border: OutlineInputBorder()),
            ),
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                final text = data?.text;
                if (text != null) controller.text = text;
              },
              icon: const Icon(Icons.paste),
              label: const Text('粘贴'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, controller.text),
              icon: const Icon(Icons.check),
              label: const Text('确认'),
            ),
          ],
        );
      },
    );

    if (result == null || result.trim().isEmpty) return;
    if (!mounted) return;

    final close = await showLoadingDialogGlobal();

    try {
      final settings = await readYamlAsMap(settingsPath);
      final ua = settings['ua'];
      final timeout = settings['timeout'];

      final data = await readYamlAsMap(subscriptionsPath);
      final list =
          (data['subscriptions'] is List)
              ? List<Map<String, dynamic>>.from(data['subscriptions'])
              : <Map<String, dynamic>>[];

      final existingIds = list.map((e) => e['id']).toSet();

      final inputLinks = result
          .split('\n')
          .map((e) => canonicalUrl(e))
          .where((e) => e.isNotEmpty)
          .toList();

      // 输入内部去重（保留顺序）
      final seen = <String>{};
      final links = <String>[];
      for (var l in inputLinks) {
        if (!seen.contains(l)) {
          seen.add(l);
          links.add(l);
        }
      }

      // 分离重复 & 新增
      final newLinks = <String>[];

      for (var link in links) {
        final id = sha256Prefix(link);

        if (existingIds.contains(id)) {
          showErrorSnackBarGlobal('订阅已存在: $link');
        } else {
          newLinks.add(link);
        }
      }

      // 并行下载
      final futures =
          newLinks.map((link) async {
            final id = sha256Prefix(link);
            try {
              final r = await downloadYamlFile(canonicalUrl(link), ua, id, timeout);
              return r;
            } catch (e) {
              showErrorSnackBarGlobal('$link 添加失败: $e');
              return null;
            }
          }).toList();

      final results = await Future.wait(futures);

      // 只加入成功的
      for (var r in results) {
        if (r != null) {
          list.add(r);
        }
      }
      applySubscriptions(list);

      await writeYamlFromMap({'subscriptions': list}, subscriptionsPath);
    } catch (e) {
      showErrorSnackBarGlobal('$e');
    } finally {
      close();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: const Text('订阅')),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : subscriptions.isEmpty
              ? const Center(child: Text('暂无订阅'))
              : RefreshIndicator(
                onRefresh: _refreshSubscriptions,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: subscriptions.length + 1, // 👈 多一个
                  itemBuilder: (context, index) {
                    if (index == subscriptions.length) {
                      return const SizedBox(height: 100); // 👈 底部空白
                    }
                    final sub = subscriptions[index];
                    final totalValue = sub['total'] as int;

                    int scale(int value) {
                      if (totalValue == 0) return 0;
                      final v = value * 100 ~/ totalValue;
                      return v.clamp(0, 100);
                    }

                    final isSelected = sub['select'] == true;

                    return Card(
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surface,
                      //     margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () async {
                          setState(() {
                            for (final s in subscriptions) {
                              s['select'] = false;
                            }
                            sub['select'] = true;
                          });
                          applySubscriptions(subscriptions);
                          await writeYamlFromMap({'subscriptions': subscriptions}, subscriptionsPath);
                          await _onSubscriptionTap(sub['id']);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. 第一行：count 和 label
                              Row(
                                children: [
                                  Container(
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          (() {
                                            final cs = Theme.of(context).colorScheme;
                                            final count = sub['count'] ?? 0;
                                            final alive = sub['alive'] ?? 0;

                                            if (count == 0) return cs.error;

                                            final r = count == 0 ? 0.0 : alive / count;

                                            if (r >= 2 / 3) return cs.primary;      // 健康
                                            if (r >= 1 / 3) return cs.secondary;    // 一般
                                            if (r > 0) return cs.tertiary;          // 较差

                                            return cs.error;                        // 全挂
                                          })(),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${sub['alive'] ?? 0}/${sub['count'] ?? 0}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1,
                                        color:
                                            (() {
                                              final cs = Theme.of(context).colorScheme;
                                              final count = sub['count'] ?? 0;
                                              final alive = sub['alive'] ?? 0;

                                              if (count == 0) return cs.onError;

                                              final r = count == 0 ? 0.0 : alive / count;

                                              if (r >= 2 / 3) return cs.onPrimary;     // 健康
                                              if (r >= 1 / 3) return cs.onSecondary;   // 一般
                                              if (r > 0) return cs.onTertiary;         // 较差

                                              return cs.onError;                      // 全挂
                                            })(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      sub['label'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // 2. 第二行：进度条
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  height: 10,
                                  child: Row(
                                    children: [
                                      if ((sub['upload'] as int) > 0)
                                        Expanded(
                                          flex: scale(sub['upload'] as int),
                                          child: Container(color: Theme.of(context).colorScheme.primary),
                                        ),
                                      if ((sub['download'] as int) > 0)
                                        Expanded(
                                          flex: scale(sub['download'] as int),
                                          child: Container(color: Theme.of(context).colorScheme.secondary),
                                        ),
                                      Expanded(
                                        flex: (100 - scale(sub['upload'] as int) - scale(sub['download'] as int))
                                            .clamp(0, 100),
                                        child: Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // 3. 第三行：左侧三行文字 + 右侧两个按钮
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 左侧文字列
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          totalValue == 0
                                              ? '上传: ∞  下载: ∞  总量: ∞'
                                              : '上传: ${formatSize(sub['upload'] as int)} 下载: ${formatSize(sub['download'] as int)} 总量: ${formatSize(totalValue)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          (sub['expire'] as int) == 0
                                              ? '到期时间: ∞'
                                              : '到期时间: ${DateTime.fromMillisecondsSinceEpoch((sub['expire'] as int) * 1000).toString().split(" ")[0]}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '上次更新: ${formatTimeAgo(sub['update'] as String)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 右侧按钮列，水平排列，无间隔
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          (sub['favorite'] ?? false) ? Icons.star : Icons.star_border,
                                          size: 20,
                                          color:
                                              (sub['favorite'] ?? false)
                                                  ? Theme.of(context).colorScheme.primary
                                                  : Theme.of(context).colorScheme.onSurface,
                                        ),
                                        onPressed: () async {
                                          final value = !(sub['favorite'] ?? false);

                                          setState(() => sub['favorite'] = value);
                                          applySubscriptions(subscriptions);

                                          final close = await showLoadingDialogGlobal();
                                          try {
                                            final data = await readYamlAsMap(subscriptionsPath);
                                            final list =
                                                (data['subscriptions'] as List)
                                                    .map((e) => Map<String, dynamic>.from(e))
                                                    .toList();

                                            final index = list.indexWhere((s) => s['id'] == sub['id']);

                                            if (index != -1) {
                                              list[index]['favorite'] = value;
                                              await writeYamlFromMap({'subscriptions': list}, subscriptionsPath);
                                            }
                                          } catch (e) {
                                            showErrorSnackBarGlobal('保存失败: $e');
                                          } finally {
                                            close();
                                          }
                                        },
                                      ),

                                      PopupMenuButton<int>(
                                        icon: Icon(
                                          Icons.more_vert,
                                          size: 20,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                        onSelected: (value) async {
                                          final settings = await readYamlAsMap(settingsPath);
                                          final ua = settings['ua'];
                                          final timeout = settings['timeout'];

                                          switch (value) {
                                            case 1:
                                              final close = await showLoadingDialogGlobal();
                                              try {
                                                final downloadResult = await downloadYamlFile(
                                                  sub['link'],
                                                  ua,
                                                  sub['id'],
                                                  timeout,
                                                );

                                                final index = subscriptions.indexWhere((s) => s['id'] == sub['id']);

                                                if (index != -1) {
                                                  subscriptions[index] = {...subscriptions[index], ...downloadResult};
                                                }

                                                await writeYamlFromMap({
                                                  'subscriptions': subscriptions,
                                                }, subscriptionsPath);

                                                setState(() {});
                                              } catch (e) {
                                                showErrorSnackBarGlobal('刷新失败: $e');
                                              } finally {
                                                close();
                                              }
                                              break;

                                            case 2:
                                              _deleteSubscription(context, sub);
                                              break;

                                            case 3:
                                              await Clipboard.setData(ClipboardData(text: sub['link']));
                                              showErrorSnackBarGlobal('链接已复制');
                                              break;
                                          }
                                        },
                                        itemBuilder:
                                            (_) => const [
                                              PopupMenuItem(
                                                value: 1,
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.refresh, size: 18),
                                                    SizedBox(width: 8),
                                                    Text('刷新'),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 2,
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete, size: 18),
                                                    SizedBox(width: 8),
                                                    Text('删除'),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 3,
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.copy, size: 18),
                                                    SizedBox(width: 8),
                                                    Text('复制'),
                                                  ],
                                                ),
                                              ),
                                            ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add',
        onPressed: _addSubscription,
        child: const Icon(Icons.add),
      ),
    );
  }
}
