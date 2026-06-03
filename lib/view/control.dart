import 'package:flutter/material.dart';
import 'package:mihomoR/service/control.dart';
import 'package:mihomoR/service/path.dart';
import 'package:mihomoR/service/subscriptions.dart';
import 'package:mihomoR/widget.dart';
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

  String startCmd = '--';
  String stopCmd = '--';
  String testCmd = '--';
  String currentLog = '--';
  String webuiUrl = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await readYamlAsMap(settingsPath);
      setState(() {
        startCmd = settings['start'] ?? '--';
        stopCmd = settings['kill'] ?? '--';
        testCmd = settings['test'] ?? '--';
        webuiUrl = 'http://127.0.0.1:${settings['port'] ?? 9090}/ui/#/proxies';
      });
      await _runCheck();
    } catch (e) {
      showErrorSnackBarGlobal('$e');
    }
  }

  Future<void> openWeb() async {
    if (webuiUrl.isEmpty) return;
    final uri = Uri.parse(webuiUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _runCheck() async {
    final close = await showLoadingDialogGlobal();
    try {
      final log = await checkMihomo();
      if (!mounted) return;
      setState(() {
        currentLog = log;
      });
    } catch (e) {
      showErrorSnackBarGlobal('$e');
    } finally {
      close();
    }
  }

  Future<void> _runTest() async {
    final close = await showLoadingDialogGlobal();
    try {
      final log = await testMihomo();
      if (!mounted) return;
      setState(() {
        currentLog = log;
      });
    } catch (e) {
      showErrorSnackBarGlobal('$e');
    } finally {
      close();
    }
  }

  Future<void> _restartMihomo() async {
    final close = await showLoadingDialogGlobal();
    try {
      final log = await startMihomo();
      if (!mounted) return;
      setState(() {
        currentLog = log;
      });
      await QuickSettings.syncTile(
        Tile(
          label: "mihomo",
          tileStatus: TileStatus.active,
          drawableName: 'quick_settings_base_icon',
          contentDescription: "mihomo 已启动",
        ),
      );
    } catch (e) {
      showErrorSnackBarGlobal('$e');
    } finally {
      close();
    }
  }

  Future<void> _stopMihomo() async {
    final close = await showLoadingDialogGlobal();
    try {
      final log = await stopMihomo();
      if (!mounted) return;
      setState(() {
        currentLog = log;
      });
      await QuickSettings.syncTile(
        Tile(
          label: "mihomo",
          tileStatus: TileStatus.inactive,
          drawableName: 'quick_settings_base_icon',
          contentDescription: "mihomo 已停止",
        ),
      );
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
      appBar: AppBar(title: const Text('控制')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 重启按钮 + 输出框
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _restartMihomo,
                  icon: const Icon(Icons.restart_alt_outlined),
                  label: const Text('重启'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(120, 50)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: startCmd),
                    readOnly: true,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 停止按钮 + 输出框
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _stopMihomo,
                  icon: const Icon(Icons.stop),
                  label: const Text('停止'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    minimumSize: const Size(120, 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: stopCmd),
                    readOnly: true,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 测试和 WEBUI 按钮并排
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _runTest,
                    icon: const Icon(Icons.bug_report),
                    label: const Text('测试'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: openWeb,
                    icon: const Icon(Icons.language),
                    label: const Text('WEBUI'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 输出框显示当前日志
            TextField(
              controller: TextEditingController(text: currentLog),
              readOnly: true,
              maxLines: null,
              style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
              decoration: InputDecoration(border: OutlineInputBorder(), contentPadding: const EdgeInsets.all(8)),
            ),
          ],
        ),
      ),
    );
  }
}
