import 'dart:async';
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:mihomoR/service/path.dart';
import 'package:mihomoR/service/subscriptions.dart';
import 'package:web_socket_client/web_socket_client.dart';

/// =======================
/// 全局配置（无默认值）
/// =======================
int port = 9090;

/// =======================
/// 数据状态
/// =======================
class TrafficState {
  int up = 0;
  int down = 0;
  int upTotal = 0;
  int downTotal = 0;
  bool connected = false;
}

/// =======================
/// WS（独立的网络监听循环）
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

    _ws!.messages.listen(
          (event) {
        final data = jsonDecode(event);

        state.up = data['up'] ?? 0;
        state.down = data['down'] ?? 0;
        state.upTotal = data['upTotal'] ?? 0;
        state.downTotal = data['downTotal'] ?? 0;
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

  // 标志位，确保在配置未读取完成前，定时循环不执行错误逻辑
  bool _isInitialized = false;

  /// =======================
  /// 后台进程启动时，自己读取文件配置
  /// =======================
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      // 1. 独立在后台进程中读取 YAML 配置文件
      final settings = await readYamlAsMap(settingsPath);

      // 2. 赋值全局变量 port
      port = settings['port'];

      // 3. 初始化并启动 WebSocket 连接
      ws = WsManager(state);
      ws.connect();

      // 4. 标记初始化完成
      _isInitialized = true;
    } catch (e) {
      // 错误处理：如果文件读取失败，可以在这里捕获
      _isInitialized = false;
    }
  }

  /// =======================
  /// 独立的前端刷新循环（死等1000ms周期）
  /// =======================
  @override
  void onRepeatEvent(DateTime timestamp) {
    // 如果后台还未读取完配置文件，显示正在初始化
    if (!_isInitialized) {
      FlutterForegroundTask.updateService(
        notificationTitle: 'mihomo 网速监控',
        notificationText: '正在读取核心配置...',
      );
      return;
    }

    if (state.connected) {
      final String speedText = '↑ ${formatSpeed(state.up)}  ↓ ${formatSpeed(state.down)}';
      final String totalText = '上传: ${formatTotal(state.upTotal)}  下载: ${formatTotal(state.downTotal)}';

      FlutterForegroundTask.updateService(
        notificationTitle: speedText,
        notificationText: totalText,
      );
    } else {
      FlutterForegroundTask.updateService(
        notificationTitle: 'mihomo 网速监控',
        notificationText: '正在连接核心...',
      );
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isSuccess) async {
    // 只有初始化成功了，才需要关闭 ws
    if (_isInitialized) {
      ws.close();
    }
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
  // 1. 初始化配置
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
      eventAction: ForegroundTaskEventAction.repeat(1000), // 固定 1000ms 周期
    ),
    iosNotificationOptions: const IOSNotificationOptions(showNotification: false, playSound: false),
  );

  // 2. 直接启动服务即可，不需要 withReceivePort，也不需要 sendDataToTask
  await FlutterForegroundTask.startService(
    notificationTitle: '服务已启动',
    notificationText: '准备监控...',
    callback: startCallback,
  );
}

/// =======================
/// 网速格式化（B/s -> KB/s 或 MB/s）
/// =======================
String formatSpeed(int bytesPerSecond) {
  double value = bytesPerSecond.toDouble();
  if (value < 1024 * 1024) {
    return '${(value / 1024).toStringAsFixed(1)} KB/s';
  }
  return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB/s';
}

/// =======================
/// 流量格式化（B -> MB 或 GB）
/// =======================
String formatTotal(int totalBytes) {
  double value = totalBytes.toDouble();
  double mb = value / (1024 * 1024);
  if (mb < 1024) {
    return '${mb.toStringAsFixed(1)} MB';
  }
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}