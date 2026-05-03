import 'dart:async';
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:web_socket_client/web_socket_client.dart';

/// =======================
/// 数据状态（共享层）
/// =======================
class TrafficState {
  int up = 0;
  int down = 0;
  bool connected = false;
}

/// =======================
/// WS（独立运行）
/// =======================
class WsManager {
  WebSocket? _ws;
  final TrafficState state;

  WsManager(this.state);

  void connect() {
    try {
      _ws = WebSocket(Uri.parse('ws://127.0.0.1:9090/traffic'));

      _ws!.messages.listen(
            (event) {
          final data = jsonDecode(event);

          state.up = data['up'] ?? 0;
          state.down = data['down'] ?? 0;
          state.connected = true;
        },
        onError: (_) => _reconnect(),
        onDone: () => _reconnect(),
      );
    } catch (_) {
      _reconnect();
    }
  }

  void _reconnect() {
    state.connected = false;

    Future.delayed(const Duration(seconds: 1), () {
      connect();
    });
  }

  void close() {
    _ws?.close();
    _ws = null;
  }
}

/// =======================
/// Foreground Task Handler
/// =======================
class MyTaskHandler extends TaskHandler {
  final TrafficState state = TrafficState();
  late final WsManager ws;

  Timer? _timer;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    ws = WsManager(state);
    ws.connect();

    _startNotifyLoop();
  }

  /// =======================
  /// 通知定时器（1秒刷新）
  /// =======================
  void _startNotifyLoop() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.connected) {
        FlutterForegroundTask.updateService(
          notificationTitle: 'mihomo 网络监控',
          notificationText: '↑ ${formatSpeed(state.up)}  ↓ ${formatSpeed(state.down)}',
        );
      } else {
        FlutterForegroundTask.updateService(
          notificationTitle: 'mihomo 网络监控',
          notificationText: '连接异常 / 重连中...',
        );
      }
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isSuccess) async {
    _timer?.cancel();
    ws.close();
  }
}

/// =======================
/// entry point（必须）
/// =======================
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

/// =======================
/// 启动前台服务
/// =======================
void initAndStartService() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'test_channel',
      channelName: '测试通知',
      channelDescription: 'demo',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      autoRunOnBoot: false,
      allowWakeLock: true,
      eventAction: ForegroundTaskEventAction.repeat(1000),
    ),
    iosNotificationOptions: IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
  );

  FlutterForegroundTask.startService(
    notificationTitle: '测试服务已启动',
    notificationText: '这是一个前台通知Demo',
    callback: startCallback,
  );
}
String formatSpeed(int bps) {
  if (bps < 1024) {
    return '$bps B/s';
  }

  double value = bps.toDouble();

  if (value < 1024 * 1024) {
    value = value / 1024;
    return '${value.toStringAsFixed(1)} KB/s';
  }

  value = value / (1024 * 1024);
  return '${value.toStringAsFixed(1)} MB/s';
}