import 'package:flutter/material.dart';
import 'package:mihomoR/service/control.dart';
import 'package:mihomoR/service/path.dart';
import 'package:mihomoR/service/subscriptions.dart';
import 'package:quick_settings_with_flutter_plugins/quick_settings.dart';
import 'package:url_launcher/url_launcher.dart';

class ControlView extends StatefulWidget {
  const ControlView({super.key});

  @override
  State<ControlView> createState() => _ControlViewState();
}

class _ControlViewState extends State<ControlView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false;

  String webuiUrl = '';
  String currentLog = '--';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await readYamlAsMap(settingsPath);

    setState(() {
      webuiUrl = 'http://127.0.0.1:${settings['port'] ?? 9090}/ui/#/proxies';
    });

    _runCheck();
  }

  Future<void> openWeb() async {
    if (webuiUrl.isEmpty) return;
    final uri = Uri.parse(webuiUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _runCheck() async {
    try {
      await checkMihomo();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        currentLog = '错误: $e';
      });
    }
  }

  Future<void> _runTest() async {
    try {
      await testMihomo();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        currentLog = '错误: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(title: const Text('控制')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await startMihomo();
                    await QuickSettings.syncTile(
                      Tile(
                        label: "mihomo",
                        tileStatus: TileStatus.active,
                        drawableName: 'quick_settings_base_icon',
                        contentDescription: "mihomo 已启动",
                      ),
                    );
                  },
                  icon: const Icon(Icons.restart_alt_outlined),
                  label: const Text("重启"),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(120, 50)),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await stopMihomo();
                    await QuickSettings.syncTile(
                      Tile(
                        label: "mihomo",
                        tileStatus: TileStatus.inactive,
                        drawableName: 'quick_settings_base_icon',
                        contentDescription: "mihomo 已停止",
                      ),
                    );
                  },
                  icon: const Icon(Icons.stop),
                  label: const Text("停止"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    minimumSize: const Size(120, 50),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _runTest,
                  icon: const Icon(Icons.bug_report),
                  label: const Text("测试"),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(120, 50)),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: openWeb,
                  icon: const Icon(Icons.language),
                  label: const Text("WEBUI"),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(120, 50)),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  TextField(
                    controller: TextEditingController(text: currentLog),
                    readOnly: true,
                    maxLines: null,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.all(8),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(icon: const Icon(Icons.refresh), onPressed: _runCheck),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
