import 'dart:async';
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:screen_lock_detector/screen_lock_detector.dart';
import 'package:web_socket_client/web_socket_client.dart';

/// =======================
/// 全局配置
/// =======================
int port = 9090;

/// =======================
/// 状态
/// =======================
class TrafficState {
  int up = 0;
  int down = 0;
  int upTotal = 0;
  int downTotal = 0;
  bool connected = false;
}

/// =======================
/// WebSocket 管理
/// =======================
class WsManager {
  WebSocket? _ws;
  final TrafficState state;

  WsManager(this.state);

  void connect() {
    _ws = WebSocket(
      Uri.parse('ws://127.0.0.1:$port/traffic'),
      backoff: const ConstantBackoff(Duration(seconds: 1)),
    );

    _ws!.messages.listen((event) {
      final data = jsonDecode(event);

      state.up = data['up'] ?? 0;
      state.down = data['down'] ?? 0;
      state.upTotal = data['upTotal'] ?? 0;
      state.downTotal = data['downTotal'] ?? 0;
      state.connected = true;
    }, onError: (_) {
      state.connected = false;
    }, onDone: () {
      state.connected = false;
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

  bool _wsRunning = false;
  bool _initialized = false;
  bool _isScreenLocked = false;

  StreamSubscription? _lockSub;

  /// =======================
  /// 启动
  /// =======================
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      ws = WsManager(state);

      /// 🔥 关键：监听锁屏状态
      _lockSub = ScreenLockDetector.statusStream.listen((status) {
        if (status == ScreenStatus.locked) {
          _onLock();
        } else if (status == ScreenStatus.unlocked) {
          _onUnlock();
        }
      });

      _initialized = true;
    } catch (e) {
      _initialized = false;
    }
  }

  /// =======================
  /// 🔒 锁屏处理
  /// =======================
  void _onLock() {
    _isScreenLocked = true;

    if (_wsRunning) {
      ws.close();
      _wsRunning = false;
    }

    FlutterForegroundTask.updateService(
      notificationTitle: 'mihomo 网速监控',
      notificationText: '已暂停（锁屏）',
    );
  }

  /// =======================
  /// 🔓 解锁处理
  /// =======================
  void _onUnlock() {
    _isScreenLocked = false;

    if (!_wsRunning) {
      ws.connect();
      _wsRunning = true;
    }
  }

  /// =======================
  /// UI刷新循环
  /// =======================
  @override
  void onRepeatEvent(DateTime timestamp) {
    if (!_initialized || _isScreenLocked) return;

    if (state.connected) {
      final speedText =
          '↑ ${formatSpeed(state.up)}  ↓ ${formatSpeed(state.down)}';

      final totalText =
          '上传: ${formatTotal(state.upTotal)}  下载: ${formatTotal(state.downTotal)}';

      FlutterForegroundTask.updateService(
        notificationTitle: speedText,
        notificationText: totalText,
      );
    }
  }

  /// =======================
  /// 销毁
  /// =======================
  @override
  Future<void> onDestroy(DateTime timestamp, bool isSuccess) async {
    ws.close();
    await _lockSub?.cancel();
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
void startMonitorService() async {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'mihomo_channel',
      channelName: 'mihomo 核心监控',
      channelDescription: '流量监控',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      autoRunOnBoot: false,
      allowWakeLock: true,
      eventAction: ForegroundTaskEventAction.repeat(1000),
    ),
    iosNotificationOptions:
    const IOSNotificationOptions(showNotification: false),
  );

  await FlutterForegroundTask.startService(
    notificationTitle: '启动中',
    notificationText: '准备监控...',
    callback: startCallback,
  );
}

/// =======================
/// 格式化
/// =======================
String formatSpeed(int bytes) {
  double v = bytes.toDouble();
  if (v < 1024 * 1024) return '${(v / 1024).toStringAsFixed(1)} KB/s';
  return '${(v / 1024 / 1024).toStringAsFixed(1)} MB/s';
}

String formatTotal(int bytes) {
  double mb = bytes / 1024 / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}