import 'package:flutter/material.dart';
import 'package:mihomoR/service/control.dart';
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

  String startOutput = '--';
  String stopOutput = '--';
  String testOutput = '--';
  String checkOutput = '--';
  String webuiUrl = 'http://127.0.0.1:9090/ui';

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  Future<void> openWeb() async {
    final uri = Uri.parse(webuiUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _runCheck() async {
    final close = await showLoadingDialogGlobal();
    try {
      final result = await checkMihomo();
      if (!mounted) return;
      setState(() {
        checkOutput = result;
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
      final result = await testMihomo();
      if (!mounted) return;
      setState(() {
        testOutput = result;
      });
    } catch (e) {
      showErrorSnackBarGlobal('$e');
    } finally {
      close();
    }
  }

  Future<void> _startMihomo() async {
    final close = await showLoadingDialogGlobal();
    try {
      final result = await startMihomo();
      if (!mounted) return;
      setState(() {
        startOutput = result;
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
      final result = await stopMihomo();
      if (!mounted) return;
      setState(() {
        stopOutput = result;
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
            // 重启按钮 + 显示输出
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _startMihomo,
                  icon: const Icon(Icons.restart_alt_outlined),
                  label: const Text('重启'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    minimumSize: const Size(120, 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: startOutput),
                    readOnly: true,
                    maxLines: null,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 停止按钮 + 显示输出
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
                    controller: TextEditingController(text: stopOutput),
                    readOnly: true,
                    maxLines: null,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 测试和 WEBUI 按钮并排，没有显示框
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _runTest,
                    icon: const Icon(Icons.bug_report),
                    label: const Text('测试'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      minimumSize: const Size(120, 50),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: openWeb,
                    icon: const Icon(Icons.language),
                    label: const Text('WEBUI'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      minimumSize: const Size(120, 50),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 显示框，显示 check 输出
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  TextField(
                    controller: TextEditingController(text: checkOutput),
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
