import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mihomoR/service/control.dart';
import 'package:quick_settings_with_flutter_plugins/quick_settings.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mihomoR/service/subscriptions.dart';
import 'package:mihomoR/service/path.dart';

class ControlView extends StatefulWidget {
  const ControlView({super.key});

  @override
  State<ControlView> createState() => _ControlViewState();
}

class _ControlViewState extends State<ControlView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false;

  String startCmd = '';
  String stopCmd = '';
  String webuiUrl = '';
  String checkCmd = '';
  String testCmd = '';
  String currentLog = '--';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await readYamlAsMap(settingsPath);
    setState(() {
      startCmd = settings['start'] ?? '';
      stopCmd = settings['kill'] ?? '';
      webuiUrl = 'http://127.0.0.1:${settings['port'] ?? 9090}/ui/#/proxies';
      checkCmd = settings['check'] ?? '';
      testCmd = settings['test'] ?? '';
    });
    _runCheck();
  }

  Future<void> openWeb() async {
    if (webuiUrl.isEmpty) return;
    final uri = Uri.parse(webuiUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _runCheck() async {
    if (checkCmd.isEmpty) return;
    try {
      final result = await Process.run("sh", ["-c", checkCmd]);
      if (!mounted) return;
      setState(() {
        currentLog = result.stdout.toString().trim() + result.stderr.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        currentLog = '错误: $e';
      });
    }
  }

  Future<void> _runTest() async {
    if (testCmd.isEmpty) return;
    try {
      final result = await Process.run("sh", ["-c", testCmd]);
      if (!mounted) return;
      setState(() {
        currentLog = result.stdout.toString() + result.stderr.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        currentLog = '错误: $e';
      });
    }
  }

  Widget _buildButtonRow({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required String value,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              minimumSize: const Size(120, 50),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: value),
              readOnly: true,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ),
        ],
      ),
    );
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
            _buildButtonRow(
              label: '重启',
              icon: Icons.restart_alt_outlined,
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
              value: startCmd,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            _buildButtonRow(
              label: '停止',
              icon: Icons.stop,
              onPressed: () async {
                await stopMihomo();
                QuickSettings.syncTile(
                  Tile(
                    label: "mihomo",
                    tileStatus: TileStatus.inactive,
                    drawableName: 'quick_settings_base_icon',
                    contentDescription: "mihomo 已停止",
                  ),
                );
              },
              value: stopCmd,
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            _buildButtonRow(
              label: '测试',
              icon: Icons.bug_report,
              onPressed: _runTest,
              value: testCmd,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            _buildButtonRow(
              label: 'WEBUI',
              icon: Icons.language,
              onPressed: openWeb,
              value: webuiUrl,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                    child: IconButton(
                      icon: const Icon(Icons.refresh),
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: _runCheck,
                    ),
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
