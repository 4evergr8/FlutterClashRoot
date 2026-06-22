import 'package:flutter/material.dart';
import 'package:clashroot/service/control.dart';
import 'package:clashroot/service/path.dart';
import 'package:clashroot/service/subscriptions.dart';
import 'package:clashroot/widget.dart';
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

  // 1. 声明持久化的 Controller
  late final TextEditingController _startController;
  late final TextEditingController _stopController;
  late final TextEditingController _displayController;


  @override
  void initState() {
    super.initState();
    // 2. 在 initState 中初始化并赋予初始值
    _startController = TextEditingController(text: '--');
    _stopController = TextEditingController(text: '--');
    _displayController = TextEditingController(text: '--');
    _runCheck();
  }

  @override
  void dispose() {
    // 3. 必须在 dispose 中销毁所有控制器，防止内存泄漏
    _startController.dispose();
    _stopController.dispose();
    _displayController.dispose();
    super.dispose();
  }

  Future<void> openWeb() async {
    final settings = await readYamlAsMap(settingsPath);
    final port = settings['port'];
    String webuiUrl = 'http://127.0.0.1:$port/ui';
    final uri = Uri.parse(webuiUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _runCheck() async {
    final close = await showLoadingDialogGlobal();
    try {
      final result = await checkMihomo();
      if (!mounted) return;
      setState(() {
        // 4. 更新文本时，直接修改 text 属性
        _displayController.text = result;
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
        _displayController.text = result;
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
        _startController.text = result;
      });
      await QuickSettings.syncTile(
        Tile(
          label: "ClashRoot",
          tileStatus: TileStatus.active,
          drawableName: 'alarm_on',
          contentDescription: "Clash核心已启动",
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
        _stopController.text = result;
      });
      await QuickSettings.syncTile(
        Tile(
          label: "ClashRoot",
          tileStatus: TileStatus.inactive,
          drawableName: 'alarm_off',
          contentDescription: "Clash核心已停止",
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
                    controller: _startController, // 5. 绑定持久化实例
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
                    controller: _stopController, // 5. 绑定持久化实例
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

            // 测试和 WEBUI 按钮并排
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

            // 显示框
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  TextField(
                    controller: _displayController,
                    // 5. 绑定持久化实例
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
