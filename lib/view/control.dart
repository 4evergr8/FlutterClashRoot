import 'package:clashroot/service/control.dart';
import 'package:clashroot/service/path.dart';
import 'package:clashroot/service/yaml.dart';
import 'package:clashroot/widget.dart';
import 'package:flutter/material.dart';
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
  late final TextEditingController _displayController;

  @override
  void initState() {
    super.initState();
    _displayController = TextEditingController(text: '');
    _runCheck();
  }

  @override
  void dispose() {
    // 3. 必须在 dispose 中销毁所有控制器，防止内存泄漏
    _displayController.dispose();
    super.dispose();
  }

  Future<void> openWeb() async {
    final data = await yamlRead(dataPath);
    final port = data['port'];
    String webuiUrl = 'http://127.0.0.1:$port/ui';
    final uri = Uri.parse(webuiUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _runCheck() async {
    try {
      final result = await clashCheck();
      setState(() {
        _displayController.text = result;
      });
    } catch (e) {
      showSnackBarGlobal("error", '$e');
    }
  }

  Future<void> _runTest() async {
    try {
      final result = await clashTest();
      setState(() {
        _displayController.text = result;
      });
    } catch (e) {
      showSnackBarGlobal("error", '$e');
    }
  }

  Future<void> _startClash() async {
    try {
      await clashStart();
    } catch (e) {
      showSnackBarGlobal("error", '$e');
    }
  }

  Future<void> _killClash() async {
    try {
      await clashKill();
    } catch (e) {
      showSnackBarGlobal("error", '$e');
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
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _startClash,
                    icon: const Icon(Icons.restart_alt_outlined),
                    label: const Text('重启'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _killClash,
                    icon: const Icon(Icons.stop),
                    label: const Text('停止'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

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
