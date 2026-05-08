import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';
import 'package:mihomoR/service/path.dart';
import 'package:mihomoR/service/subscriptions.dart';

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

  // 存储勾选的包名，包括 YAML 里存在但未安装的包名
  Set<String> selectedPackages = {};
  Set<String> yamlPackages = {};

  @override
  void initState() {
    super.initState();
    _loadAppsAndYaml();
  }

  Future<void> _loadAppsAndYaml() async {
    final close = await showLoadingDialogGlobal();

    try {
      final override = await readYamlAsMap(overridePath);

      final includePackages = List<String>.from(override['tun']['include-package'] ?? []);

      yamlPackages = includePackages.toSet();

      selectedPackages = includePackages.toSet();

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
    } finally {
      close();
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

    // YAML 中原本存在但不在 apps 列表中的包名也保留
    final newInclude = {...checkedPackages, ...yamlPackages.difference(apps.map((e) => e.packageName!).toSet())};

    // 更新 overridePath
    final override = await readYamlAsMap(overridePath);
    override['tun']['include-package'] = newInclude.toList();
    await writeYamlFromMap(override, overridePath);

    // 更新 mergePath，完全替换 include-package
    final merge = await readYamlAsMap(mergePath);
    merge['tun']['include-package'] = newInclude.toList();
    await writeYamlFromMap(merge, mergePath);
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
                    child: TextField(
                      decoration: const InputDecoration(hintText: '筛选应用', border: OutlineInputBorder()),
                      onChanged: _filterApps,
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
