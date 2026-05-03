import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:mihomoR/service/control.dart';
import 'package:quick_settings_with_flutter_plugins/quick_settings.dart';
import 'package:mihomoR/theme/theme.dart';
import 'package:mihomoR/theme/util.dart';
import 'package:mihomoR/widget.dart';






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
      allowWakeLock: true,eventAction: ForegroundTaskEventAction.nothing(),
    ),
    iosNotificationOptions: IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
  );

  FlutterForegroundTask.startService(
    notificationTitle: '测试服务已启动',
    notificationText: '这是一个前台通知Demo',
  );
}
/// Tile 点击回调
@pragma('vm:entry-point')
Tile onTileClicked(Tile tile) {
  final isActive = tile.tileStatus == TileStatus.active;

  if (isActive) {
    stopMihomo();

    tile
      ..tileStatus = TileStatus.inactive
      ..label = "mihomo"
      ..drawableName = "quick_settings_base_icon"
      ..contentDescription = "mihomo 已停止";
  } else {
    startMihomo();

    tile
      ..tileStatus = TileStatus.active
      ..label = "mihomo"
      ..drawableName = "quick_settings_base_icon"
      ..contentDescription = "mihomo 已启动";
  }

  return tile;
}

/// Tile 添加回调
@pragma('vm:entry-point')
Tile? onTileAdded(Tile tile) {
  tile.label = "mihomo";
  tile.drawableName = "quick_settings_base_icon";
  tile.contentDescription = "mihomo 核心控制";
  return tile;
}

/// Tile 移除回调
@pragma('vm:entry-point')
void onTileRemoved() {}


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  QuickSettings.setup(
    onTileClicked: onTileClicked,
    onTileAdded: onTileAdded,
    onTileRemoved: onTileRemoved,
  );

  runApp(const MyApp());
  initAndStartService();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = View.of(context).platformDispatcher.platformBrightness;
    TextTheme textTheme = createTextTheme(context, "Noto Sans", "Noto Sans");
    MaterialTheme theme = MaterialTheme(textTheme);

    return MaterialApp(
      navigatorKey: navigatorKey, // 绑定全局 key
      title: 'mihomoR',
      theme: brightness == Brightness.light ? theme.light() : theme.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return BottomNavBar();
  }
}
