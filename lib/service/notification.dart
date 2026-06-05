import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:mihomoR/service/path.dart';
import 'package:mihomoR/service/subscriptions.dart';
import 'package:web_socket_client/web_socket_client.dart';

int port = 9090;

class TrafficState {
  int up = 0;
  int down = 0;
  int upTotal = 0;
  int downTotal = 0;
  bool connected = false;
}


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


class MyTaskHandler extends TaskHandler {
  final TrafficState state = TrafficState();
  late final WsManager ws;


  bool _isInitialized = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {

      final settings = await readYamlAsMap(settingsPath);


      port = settings['port'];

      ws = WsManager(state);
      ws.connect();

      // 4. 标记初始化完成
      _isInitialized = true;
    } catch (e) {
      // 错误处理：如果文件读取失败，可以在这里捕获
      _isInitialized = false;
    }
  }


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
  Future<void> onNotificationButtonPressed(String id) async {
    await Process.run('su', ['-c', 'am force-stop a.forevergreat.mihomoroot']);;
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isSuccess) async {
    // 只有初始化成功了，才需要关闭 ws
    if (_isInitialized) {
      ws.close();
    }
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}


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
    notificationButtons: [
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