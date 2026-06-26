import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clashroot/service/path.dart';
import 'package:clashroot/service/yaml.dart';
import 'package:clashroot/widget.dart';
import 'package:dio/dio.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:web_socket_support/web_socket_support.dart';

int port = 9090;

class MyTaskHandler extends TaskHandler {
  int _up = 0, _down = 0, _upTotal = 0, _downTotal = 0;
  late final WebSocketClient _wsClient;
  WebSocketConnection? _wsConn;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      final settings = await yamlRead(dataPath);
      port = settings['port'];

      _wsClient = WebSocketClient(
        DefaultWebSocketListener.forTextMessages(
          (conn) => _wsConn = conn,
          (_, __) => _wsConn = null,
          (msg) {
            final data = jsonDecode(msg);
            _up = data['up'] ?? 0;
            _down = data['down'] ?? 0;
            _upTotal = data['upTotal'] ?? 0;
            _downTotal = data['downTotal'] ?? 0;
          },
          (_, __) {},
          (_) => _wsConn = null,
        ),
      );

      await _wsClient.connect('ws://127.0.0.1:$port/traffic', options: WebSocketOptions(autoReconnect: true));
    } catch (e) {
      showSnackBarGlobal("error", "$e");
      rethrow;
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.updateService(
      notificationTitle: '↑ ${formatSpeed(_up)}  ↓ ${formatSpeed(_down)}',
      notificationText: '上传: ${formatTotal(_upTotal)}  下载: ${formatTotal(_downTotal)}',
    );
  }

  @override
  Future<void> onNotificationButtonPressed(String id) async {
    if (id == 'close') {
      await Process.run('su', ['-c', 'am force-stop app.flutter.clashroot']);
    } else {
      await Dio().delete(
        'http://127.0.0.1:$port/connections',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isSuccess) async {
    await _wsClient.disconnect();
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

void startMonitorService() async {
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
  double v = bytesPerSecond.toDouble();
  return v < 1024 * 1024 ? '${(v / 1024).toStringAsFixed(1)} KB/s' : '${(v / (1024 * 1024)).toStringAsFixed(1)} MB/s';
}

String formatTotal(int totalBytes) {
  double mb = totalBytes / (1024 * 1024);
  return mb < 1024 ? '${mb.toStringAsFixed(1)} MB' : '${(mb / 1024).toStringAsFixed(2)} GB';
}
