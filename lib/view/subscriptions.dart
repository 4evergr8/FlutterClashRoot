import 'dart:io';

import 'package:clashroot/service/path.dart';
import 'package:clashroot/service/subscriptions.dart';
import 'package:clashroot/service/yaml.dart';
import 'package:clashroot/widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SubscriptionView extends StatefulWidget {
  const SubscriptionView({super.key});

  @override
  State<SubscriptionView> createState() => _SubscriptionViewState();
}

class _SubscriptionViewState extends State<SubscriptionView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false;
  Map<String, dynamic> data = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      data = await subscriptionsLoad();
    } catch (e) {
      showSnackBarGlobal("error", '$e');
    }
    setState(() {});
  }

  Future<void> _subscriptionsSwitch(String id) async {
    try {
      setState(() {
        for (final s in data['subscriptions']) {
          s['select'] = s['id'] == id;
        }
      });
      await subscriptionsSwitch(id);
    } catch (e) {
      showSnackBarGlobal("error", '$e');
    }
  }

  Future<void> _subscriptionsRefresh() async {
    try {
      data = await subscriptionsRefresh(data);
      data = await subscriptionsLoad(data);
      await yamlWrite(data, dataPath);
      final subs =
      (data['subscriptions'] is List)
          ? List<Map<String, dynamic>>.from(data['subscriptions'])
          : <Map<String, dynamic>>[];
      final selectedSub = subs.firstWhere((sub) => sub['select'] == true);
      await subscriptionsSwitch(selectedSub['id']);

      showSnackBarGlobal("success", "刷新完成");
    } catch (e) {
      showSnackBarGlobal("error", '$e');
    }
    setState(() {});
  }

  Future<void> _subscriptionsAdd(String input) async {
    final close = showSnackBarGlobal("load", "请稍候...");
    try {
      data = await subscriptionsAdd(data, input);
      data = await subscriptionsLoad(data);
      await yamlWrite(data, dataPath);
      close();
      showSnackBarGlobal("success", "全部添加完成");
    } catch (e) {
      close();
      showSnackBarGlobal("error", '$e');
    }
    setState(() {});
  }

  Future<void> _subscriptionDelete(String id) async {
    try {
      data['subscriptions'].removeWhere((s) => s['id'] == id);
      await Process.run('su', ['-c', 'rm -f $mainPath/config/$id.yaml']);
      data = await subscriptionsLoad(data);
      await yamlWrite(data, dataPath);
    } catch (e) {
      showSnackBarGlobal("error", '$e');
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: const Text('订阅')),
      body: RefreshIndicator(
        onRefresh:  _subscriptionsRefresh,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: data['subscriptions'].length + 1, // 👈 多一个
          itemBuilder: (context, index) {
            if (index == data['subscriptions'].length) {
              return const SizedBox(height: 100); // 👈 底部空白
            }
            final sub = data['subscriptions'][index];
            final totalValue = sub['total'] as int;

            int scale(int value) {
              if (totalValue == 0) return 0;
              final v = value * 100 ~/ totalValue;
              return v.clamp(0, 100);
            }

            final isSelected = sub['select'] == true;

            return Card(
              color:
                  isSelected ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surface,
              //     margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () async {
                  await _subscriptionsSwitch(sub['id']);
                  await yamlWrite(data['subscriptions'], dataPath);
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

                                    if (r >= 2 / 3) return cs.primary; // 健康
                                    if (r >= 1 / 3) return cs.secondary; // 一般
                                    if (r > 0) return cs.tertiary; // 较差

                                    return cs.error; // 全挂
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

                                      if (r >= 2 / 3) return cs.onPrimary; // 健康
                                      if (r >= 1 / 3) return cs.onSecondary; // 一般
                                      if (r > 0) return cs.onTertiary; // 较差

                                      return cs.onError; // 全挂
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
                                flex: (100 - scale(sub['upload'] as int) - scale(sub['download'] as int)).clamp(
                                  0,
                                  100,
                                ),
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
                                  data = await subscriptionsLoad(data);

                                  try {
                                    final data = await yamlRead(dataPath);
                                    final list =
                                        (data['subscriptions'] as List)
                                            .map((e) => Map<String, dynamic>.from(e))
                                            .toList();

                                    final index = list.indexWhere((s) => s['id'] == sub['id']);

                                    if (index != -1) {
                                      list[index]['favorite'] = value;
                                      await yamlWrite(data, dataPath);
                                    }
                                  } catch (e) {
                                    showSnackBarGlobal("error", '保存失败: $e');
                                  }
                                },
                              ),

                              PopupMenuButton<int>(
                                icon: Icon(Icons.more_vert, size: 20, color: Theme.of(context).colorScheme.onSurface),
                                onSelected: (value) async {
                                  final ua = data['ua'];
                                  final timeout = data['timeout'];

                                  switch (value) {
                                    case 1:
                                      final close = showSnackBarGlobal("load", "请稍候...");
                                      try {
                                        final downloadResult = await yamlDownload(sub['link'], ua, sub['id'], timeout);

                                        final list =
                                            (data['subscriptions'] as List)
                                                .map((e) => Map<String, dynamic>.from(e))
                                                .toList();

                                        final index = list.indexWhere((s) => s['id'] == sub['id']);

                                        if (index != -1) {
                                          list[index] = {
                                            ...Map<String, dynamic>.from(list[index]),
                                            ...Map<String, dynamic>.from(downloadResult),
                                          };
                                        }

                                        data['subscriptions'] = list;
                                        await yamlWrite(data, dataPath);
                                        if (sub['select'] == true) {
                                          await subscriptionsSwitch(sub['id']);
                                        }
                                        close();
                                        showSnackBarGlobal("success", "刷新成功");
                                        setState(() {});
                                      } catch (e) {
                                        close();
                                        showSnackBarGlobal("error", '刷新失败: $e');
                                      }
                                      break;

                                    case 2:
                                      final result = await _dialogSubscriptionDelete(context, sub);
                                      if (result == true) {
                                        await _subscriptionDelete(sub['id']);
                                      }
                                      break;

                                    case 3:
                                      await Clipboard.setData(ClipboardData(text: sub['link']));
                                      showSnackBarGlobal("success", '链接已复制');
                                      break;
                                  }
                                },
                                itemBuilder:
                                    (_) => const [
                                      PopupMenuItem(
                                        value: 1,
                                        child: Row(
                                          children: [Icon(Icons.refresh, size: 18), SizedBox(width: 8), Text('刷新')],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 2,
                                        child: Row(
                                          children: [Icon(Icons.delete, size: 18), SizedBox(width: 8), Text('删除')],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 3,
                                        child: Row(
                                          children: [Icon(Icons.copy, size: 18), SizedBox(width: 8), Text('复制')],
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
        onPressed: () async {
          final links = await _dialogSubscriptionAdd(context);

          if (links != null && links.trim().isNotEmpty) {
            await _subscriptionsAdd(links);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<String?> _dialogSubscriptionAdd(BuildContext context) {
  final controller = TextEditingController();

  return showDialog<String>(
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
}

Future<bool?> _dialogSubscriptionDelete(BuildContext context, Map<String, dynamic> sub) {
  return showDialog<bool>(
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
}
