import 'package:clashroot/service/path.dart';
import 'package:clashroot/service/subscriptions.dart';
import 'package:clashroot/service/yaml.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';

import '../widget.dart';

class SplitView extends StatefulWidget {
  const SplitView({super.key});

  @override
  State<SplitView> createState() => _SplitViewState();
}

class _SplitViewState extends State<SplitView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false;

  List<AppInfo> apps = [];
  List<AppInfo> filteredApps = [];
  String searchQuery = '';
  bool isLoading = true;

  Set<String> selectedPackages = {};
  Set<String> yamlPackages = {};

  // 新增：名单模式开关，true = 白名单，false = 黑名单
  bool isWhitelist = false;

  @override
  void initState() {
    super.initState();
    _loadAppsAndYaml();
  }

  Future<void> _loadAppsAndYaml() async {
    final close = showSnackBarGlobal("load", "请稍候...");

    try {
      // 分流配置存放在 data.yaml 顶层，config.yaml 只在切换/保存时被写入
      final data = await yamlRead(dataPath);

      // 黑名单优先：有 exclude-package 就是黑名单，否则看 include-package，都没有则默认黑名单
      if (data['exclude-package'] != null) {
        isWhitelist = false;
        yamlPackages = List<String>.from(data['exclude-package']).toSet();
      } else if (data['include-package'] != null) {
        isWhitelist = true;
        yamlPackages = List<String>.from(data['include-package']).toSet();
      } else {
        isWhitelist = false;
        yamlPackages = {};
      }
      selectedPackages = yamlPackages.toSet();

      final appList = await FlutterDeviceApps.listApps(includeSystem: true, includeIcons: true, onlyLaunchable: false);
      final validApps = appList.where((a) => a.packageName != null && a.appName != null).toList();

      for (final pkg in yamlPackages) {
        if (!validApps.any((a) => a.packageName == pkg)) {
          validApps.add(AppInfo(appName: null, packageName: pkg, iconBytes: null));
        }
      }

      validApps.sort((a, b) {
        final aSelected = selectedPackages.contains(a.packageName);
        final bSelected = selectedPackages.contains(b.packageName);

        if (aSelected && !bSelected) return -1;
        if (!aSelected && bSelected) return 1;

        return (a.appName ?? '').toLowerCase().compareTo((b.appName ?? '').toLowerCase());
      });

      if (mounted) {
        setState(() {
          apps = validApps;
          filteredApps = List.from(validApps);
          isLoading = false;
        });
      }
      close();
    } catch (e) {
      close();
      showSnackBarGlobal("error", "$e");
    }
  }

  void _filterApps(String query) {
    final q = query.toLowerCase();
    setState(() {
      searchQuery = query;
      filteredApps =
          apps
              .where(
                (app) =>
                    (app.appName ?? '').toLowerCase().contains(q) || (app.packageName ?? '').toLowerCase().contains(q),
              )
              .toList();
    });
  }

  Future<void> _saveSelection() async {
    final checkedPackages =
        apps.where((a) => selectedPackages.contains(a.packageName)).map((a) => a.packageName!).toSet();

    final data = await subscriptionsLoad();
    final key = isWhitelist ? 'include-package' : 'exclude-package';
    data.remove('include-package');
    data.remove('exclude-package');
    data[key] = checkedPackages.toList();
    await yamlWrite(data, dataPath);

    // 切换订阅时会把 data.yaml 里的分流配置写入 config.yaml 并重启内核
    final subs = data['subscriptions'];
    final selectedSub = subs.firstWhere((sub) => sub['select'] == true);
    await subscriptionsSwitch(selectedSub['id']);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: const Text('分流')),
      body:
          isLoading
              ? const SizedBox.shrink()
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(hintText: '筛选应用', border: OutlineInputBorder()),
                            onChanged: _filterApps,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Row(
                          children: [
                            Text(isWhitelist ? '白名单' : '黑名单'),
                            Switch(
                              value: isWhitelist,
                              onChanged: (v) {
                                setState(() {
                                  isWhitelist = v;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredApps.length,
                      itemBuilder: (context, index) {
                        final app = filteredApps[index];
                        final isChecked = selectedPackages.contains(app.packageName);
                        Uint8List? iconBytes = app.iconBytes;
                        final displayName = app.appName ?? app.packageName ?? '';

                        return GestureDetector(
                          onLongPress: () {
                            if (app.packageName != null) {
                              Clipboard.setData(ClipboardData(text: app.packageName!));
                            }
                          },
                          child: CheckboxListTile(
                            value: isChecked,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  selectedPackages.add(app.packageName!);
                                } else {
                                  selectedPackages.remove(app.packageName);
                                }
                              });
                            },
                            title: Text(displayName),
                            subtitle: Text(app.packageName ?? ''),
                            secondary:
                                iconBytes != null
                                    ? Image.memory(iconBytes, width: 40, height: 40)
                                    : const Icon(Icons.android, size: 40),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton(onPressed: _saveSelection, child: const Icon(Icons.save)),
    );
  }
}
