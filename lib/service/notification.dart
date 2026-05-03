import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:mihomoR/service/path.dart';
import 'package:mihomoR/service/subscriptions.dart';
import 'package:web_socket_client/web_socket_client.dart';

/// =======================
/// 全局配置（无默认值）
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
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      final settings = await readYamlAsMap(settingsPath);

      port = settings['port'];
      interval = settings['interval'];
    } catch (e) {
      // 直接用通知显示错误
      FlutterForegroundTask.updateService(
        notificationTitle: 'mihomo 错误',
        notificationText: '$e',
      );

      // 启动一个简单的“静态错误循环”，防止系统回收
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        FlutterForegroundTask.updateService(
          notificationTitle: 'mihomo 错误',
          notificationText: '$e',
        );
      });

      return; // 关键：阻止后续 WS / Timer 正常流程
    }

    ws = WsManager(state);
    ws.connect();

    _startNotifyLoop();
  }

  /// =======================
  /// 通知刷新（interval控制）
  /// =======================
  void _startNotifyLoop() {
    _timer?.cancel();

    _timer = Timer.periodic(Duration(milliseconds: interval), (_) {
      if (state.connected) {
        FlutterForegroundTask.updateService(
          notificationTitle: 'mihomo 网速监控',
          notificationText: '↑ ${formatSpeed(state.up)}  ↓ ${formatSpeed(state.down)}',
        );
      } else {
        FlutterForegroundTask.updateService(notificationTitle: 'mihomo 网速监控', notificationText: '正在连接核心...');
      }
    });
  }

  /// =======================
  /// 按钮：断开所有连接（仅发 HTTP DELETE）
  /// =======================
  @override
  void onReceiveData(Object data) {
    if (data is Map && data['id'] == 'disconnect') {
      _disconnectAll();
    }
  }

  Future<void> _disconnectAll() async {
    final dio = Dio();

    await dio.delete(
      'http://127.0.0.1:$port/connections',
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
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
    iosNotificationOptions: IOSNotificationOptions(showNotification: false, playSound: false),
  );
  FlutterForegroundTask.startService(
    notificationTitle: '服务已启动',
    notificationText: 'mihomo 监控运行中',
    notificationButtons: const [NotificationButton(id: 'disconnect', text: '断开连接')],
    callback: startCallback,
  );
}

/// =======================
/// 速度格式化（B基准，不除以8）
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
