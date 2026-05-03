import 'dart:async';
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:mihomoR/service/path.dart';
import 'package:mihomoR/service/subscriptions.dart';
import 'package:web_socket_client/web_socket_client.dart';

/// =======================
/// 全局配置
/// =======================
int port = 9090;
int interval = 1000;

/// =======================
/// 数据状态
/// =======================
class TrafficState {
  int up = 0;
  int down = 0;
  bool connected = false;
}

/// =======================
/// WS（无手动重连）
/// =======================
class WsManager {
  WebSocket? _ws;
  final TrafficState state;

  WsManager(this.state);

  void connect() {
    _ws = WebSocket(Uri.parse('ws://127.0.0.1:$port/traffic'));

    _ws!.messages.listen(
          (event) {
        final data = jsonDecode(event);

        state.up = data['up'] ?? 0;
        state.down = data['down'] ?? 0;
        state.connected = true;
      },
      onError: (_) {
        state.connected = false;
      },
      onDone: () {
        state.connected = false;
      },
    );
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
    try {
      final settings = await readYamlAsMap(settingsPath);

      port = settings['port'];
      interval = settings['interval'];

      ws = WsManager(state);
      ws.connect();

      _startNotifyLoop();
    } catch (e) {
      _startErrorLoop(e.toString());
    }
  }

  /// =======================
  /// 正常通知循环
  /// =======================
  void _startNotifyLoop() {
    _timer?.cancel();

    _timer = Timer.periodic(Duration(milliseconds: interval), (_) {
      if (state.connected) {
        FlutterForegroundTask.updateService(
          notificationTitle: 'mihomo 网速监控',
          notificationText:
          '↑ ${formatSpeed(state.up)}  ↓ ${formatSpeed(state.down)}',
        );
      } else {
        FlutterForegroundTask.updateService(
          notificationTitle: 'mihomo 网速监控',
          notificationText: '正在连接核心...',
        );
      }
    });
  }

  /// =======================
  /// 错误通知循环（关键）
  /// =======================
  void _startErrorLoop(String error) {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      FlutterForegroundTask.updateService(
        notificationTitle: 'mihomo 错误',
        notificationText: error,
      );
    });
  }

  /// =======================
  /// 按钮：断开连接
  /// =======================



  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isSuccess) async {
    _timer?.cancel();
    ws.close();
  }
}

/// =======================
/// entry point
/// =======================
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

/// =======================
/// 启动服务
/// =======================
void initAndStartService() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'mihomo_channel',
      channelName: 'mihomo 核心监控',
      channelDescription: '用于展示核心流量与连接状态的前台服务通知',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      autoRunOnBoot: false,
      allowWakeLock: true,
      eventAction: ForegroundTaskEventAction.repeat(1000),
    ),
    iosNotificationOptions:
    IOSNotificationOptions(showNotification: false, playSound: false),
  );

  FlutterForegroundTask.startService(
    notificationTitle: '服务启动中',
    notificationText: '初始化中...',
    callback: startCallback,
  );
}

/// =======================
/// 速度格式化
/// =======================
String formatSpeed(int bps) {
  if (bps < 1024) {
    return '$bps B/s';
  }

  double value = bps.toDouble();

  if (value < 1024 * 1024) {
    return '${(value / 1024).toStringAsFixed(1)} KB/s';
  }

  return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB/s';
}