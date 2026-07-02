import 'package:clashroot/service/notification.dart';
import 'package:clashroot/service/tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quick_settings_with_flutter_plugins/quick_settings.dart';

import 'theme/theme.dart';
import 'theme/util.dart';
import 'widget.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  QuickSettings.setup(onTileClicked: onTileClicked, onTileAdded: onTileAdded, onTileRemoved: onTileRemoved);
  runApp(const MyApp());
  startMonitorService();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = View.of(context).platformDispatcher.platformBrightness;
    TextTheme textTheme = createTextTheme(context, "Noto Sans", "Noto Sans");
    MaterialTheme theme = MaterialTheme(textTheme);

    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'ClashRoot',
      theme: brightness == Brightness.light ? theme.light() : theme.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return BottomNavBar();
  }
}
