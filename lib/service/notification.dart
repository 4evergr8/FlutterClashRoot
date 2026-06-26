import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clashroot/service/path.dart';
import 'package:clashroot/service/yaml.dart';
import 'package:dio/dio.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:web_socket_support/web_socket_support.dart';

int port = 9090;

class MyTaskHandler extends TaskHandler {
  int up = 0;
  int down = 0;
  int upTotal = 0;
  int downTotal = 0;

  late WebSocketClient _client;
  WebSocketConnection? _conn;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final settings = await yamlRead(dataPath);
    port = settings['port'];

    _client = WebSocketClient(
      DefaultWebSocketListener.forTextMessages(
        (c) {
          _conn = c;
        },
        (_, __) {
          _conn = null;
        },
        (msg) {
          final data = jsonDecode(msg);

          up = data['up'] ?? 0;
          down = data['down'] ?? 0;
          upTotal = data['upTotal'] ?? 0;
          downTotal = data['downTotal'] ?? 0;
        },
        (_, __) {},
        (e) {
          _conn = null;
        },
      ),
    );

    await _client.connect('ws://127.0.0.1:$port/traffic', options: WebSocketOptions(autoReconnect: true));
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    final speedText = '↑ ${formatSpeed(up)}  ↓ ${formatSpeed(down)}';

    final totalText = '上传: ${formatTotal(upTotal)}  下载: ${formatTotal(downTotal)}';

    FlutterForegroundTask.updateService(notificationTitle: speedText, notificationText: totalText);
  }

  @override
  Future<void> onNotificationButtonPressed(String id) async {
    if (id == 'close') {
      await Process.run('su', ['-c', 'am force-stop app.flutter.clashroot']);
      return;
    }

    await Dio().delete(
      'http://127.0.0.1:$port/connections',
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isSuccess) async {
    await _client.disconnect();
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
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
