import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clashroot/service/path.dart';
import 'package:clashroot/service/yaml.dart';
import 'package:clashroot/widget.dart';
import 'package:dio/dio.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:web_socket_client/web_socket_client.dart';

int port = 9090;

class TrafficState {
  int up = 0;
  int down = 0;
  int upTotal = 0;
  int downTotal = 0;
}

class WsManager {
  WebSocket? _ws;
  final TrafficState state;

  WsManager(this.state);

  void connect() {
    _ws = WebSocket(Uri.parse('ws://127.0.0.1:$port/traffic'), backoff: const ConstantBackoff(Duration(seconds: 1)));

    _ws!.messages.listen((event) {
      final data = jsonDecode(event);

      state.up = data['up'] ?? 0;
      state.down = data['down'] ?? 0;
      state.upTotal = data['upTotal'] ?? 0;
      state.downTotal = data['downTotal'] ?? 0;
    });
  }

  void close() {
    _ws?.close();
    _ws = null;
  }
}

class MyTaskHandler extends TaskHandler {
  final TrafficState state = TrafficState();
  late final WsManager ws;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      final settings = await yamlRead(dataPath);

      port = settings['port'];

      ws = WsManager(state);
      ws.connect();
    } catch (e) {
      showSnackBarGlobal("error", "$e");
      rethrow;
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    final String speedText = '↑ ${formatSpeed(state.up)}  ↓ ${formatSpeed(state.down)}';

    final String totalText = '上传: ${formatTotal(state.upTotal)}  下载: ${formatTotal(state.downTotal)}';

    FlutterForegroundTask.updateService(notificationTitle: speedText, notificationText: totalText);
  }

  @override
  Future<void> onNotificationButtonPressed(String id) async {
    if (id == 'close') {
      await Process.run('su', ['-c', 'am force-stop app.flutter.clashroot']);
    } else {
      final dio = Dio();
      await dio.delete(
        'http://127.0.0.1:$port/connections',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isSuccess) async {
    ws.close();
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

Future<void> startMonitorService() async{
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'clash_channel',
      channelName: 'Clash核心监控',
      channelDescription: '用于展示核心流量与连接状态的前台服务通知',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      autoRunOnBoot: false,
      allowWakeLock: true,
      eventAction: ForegroundTaskEventAction.repeat(1000),
    ),
    iosNotificationOptions: const IOSNotificationOptions(showNotification: false, playSound: false),
  );

  await FlutterForegroundTask.startService(
    notificationButtons: [
      const NotificationButton(id: 'delete', text: '断开连接'),
      const NotificationButton(id: 'close', text: '关闭监控'),
    ],
    serviceTypes: [ForegroundServiceTypes.dataSync],
    notificationTitle: '服务已启动',
    notificationText: '准备监控...',
    callback: startCallback,
  );
}

String formatSpeed(int bytesPerSecond) {
  double value = bytesPerSecond.toDouble();
  if (value < 1024 * 1024) {
    return '${(value / 1024).toStringAsFixed(1)} KB/s';
  }
  return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB/s';
}

String formatTotal(int totalBytes) {
  double value = totalBytes.toDouble();
  double mb = value / (1024 * 1024);
  if (mb < 1024) {
    return '${mb.toStringAsFixed(1)} MB';
  }
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}
