import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clashroot/service/path.dart';
import 'package:clashroot/service/yaml.dart';
import 'package:clashroot/widget.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:web_socket_support/web_socket_support.dart';

int port = 9090;

class TrafficState {
  int up = 0;
  int down = 0;
  int upTotal = 0;
  int downTotal = 0;
}

class WsManager {
  late final WebSocketClient _wsClient;
  WebSocketConnection? _wsConnection;
  final TrafficState state;

  WsManager(this.state) {
    _wsClient = WebSocketClient(
      DefaultWebSocketListener.forTextMessages(
        _onWsOpened,    // 1: onOpen
        _onWsClosed,    // 2: onClosed
        _onMessage,     // 3: onTextMessage
            (_, __) => {},  // 4: onBinaryMessage (不需要，传空)
        _onError,       // 5: onError
      ),
    );
  }

  void _onWsOpened(WebSocketConnection wsc) {
    _wsConnection = wsc;
  }

  void _onWsClosed(int code, String reason) {
    _wsConnection = null;
  }

  void _onMessage(String msg) {
    try {
      final data = jsonDecode(msg);
      state.up = data['up'] ?? 0;
      state.down = data['down'] ?? 0;
      state.upTotal = data['upTotal'] ?? 0;
      state.downTotal = data['downTotal'] ?? 0;
    } catch (_) {}
  }

  void _onError(Exception ex) {
    _wsConnection = null;
  }

  Future<void> connect() async {
    try {
      await _wsClient.connect(
        'ws://127.0.0.1:$port/traffic',
        options: WebSocketOptions(autoReconnect: true),
      );
    } on PlatformException catch (e) {
      showSnackBarGlobal("error", "WS连接失败: $e");
    }
  }

  Future<void> close() async {
    await _wsClient.disconnect();
  }
}

class MyTaskHandler extends TaskHandler {
  final TrafficState state = TrafficState();
  late final WsManager ws = WsManager(state);

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      final settings = await yamlRead(dataPath);
      port = settings['port'];
      await ws.connect();
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
    await ws.close();
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