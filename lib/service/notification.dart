import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mihomoR/service/path.dart';
import 'package:mihomoR/service/subscriptions.dart';
import 'package:web_socket_client/web_socket_client.dart';

/// =======================
/// 全局配置
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
/// WS 管理
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
      onError: (_) => state.connected = false,
      onDone: () => state.connected = false,
    );
  }

  void close() {
    _ws?.close();
    _ws = null;
  }
}

/// =======================
/// 通知配置
/// =======================
const String notificationChannelId = 'mihomo_channel';
const int notificationId = 888;

/// =======================
/// 启动服务（包含初始化）
/// =======================
Future<void> startMonitorService() async {
  final service = FlutterBackgroundService();

  // ==================== 初始化部分（只执行一次） ====================
  if (!await service.isRunning()) {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'mihomo 核心监控',
      description: '用于展示核心流量与连接状态的前台服务通知',
      importance: Importance.low,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'mihomo 网速监控',
        initialNotificationContent: '准备监控...',
        foregroundServiceNotificationId: notificationId,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
      ),
    );
  }

  // ==================== 启动服务 ====================
  bool isRunning = await service.isRunning();
  if (!isRunning) {
    await service.startService();
  }
}

/// =======================
/// 后台入口
/// =======================
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final TrafficState state = TrafficState();
  late final WsManager ws;
  bool isInitialized = false;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // 读取配置并启动 WS
  try {
    final settings = await readYamlAsMap(settingsPath);
    port = settings['port'] ?? 9090;

    ws = WsManager(state);
    ws.connect();
    isInitialized = true;
  } catch (e) {
    isInitialized = false;
  }

  // 定时更新通知（每1秒），通知会一直存在
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (!isInitialized) {
      await flutterLocalNotificationsPlugin.show(
        notificationId,
        'mihomo 网速监控',
        '正在读取核心配置...',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            notificationChannelId,
            'mihomo 核心监控',
            icon: 'ic_bg_service_small',
            ongoing: true,           // 关键：保持通知常驻
            autoCancel: false,
          ),
        ),
      );
      return;
    }

    if (state.connected) {
      final String speedText = '↑ ${formatSpeed(state.up)} ↓ ${formatSpeed(state.down)}';
      final String totalText = '总上传: ${formatTotal(state.upTotal)} 总下载: ${formatTotal(state.downTotal)}';

      await flutterLocalNotificationsPlugin.show(
        notificationId,
        speedText,
        totalText,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            notificationChannelId,
            'mihomo 核心监控',
            icon: 'ic_bg_service_small',
            ongoing: true,
            autoCancel: false,
          ),
        ),
      );
    } else {
      await flutterLocalNotificationsPlugin.show(
        notificationId,
        'mihomo 网速监控',
        '正在连接核心...',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            notificationChannelId,
            'mihomo 核心监控',
            icon: 'ic_bg_service_small',
            ongoing: true,
            autoCancel: false,
          ),
        ),
      );
    }
  });

  // 可选：停止服务
  service.on('stopService').listen((event) {
    ws.close();
    service.stopSelf();
  });
}

/// =======================
/// 格式化函数（保持不变）
/// =======================
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