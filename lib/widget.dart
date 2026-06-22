import 'package:clashroot/main.dart';
import 'package:clashroot/view/control.dart';
import 'package:clashroot/view/proxies.dart';
import 'package:clashroot/view/split.dart';
import 'package:clashroot/view/subscriptions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  static final List<Widget> _widgetOptions = <Widget>[SubscriptionView(), ProxiesView(), SplitView(), ControlView()];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // 禁止手势滑动
        children: _widgetOptions,
        onPageChanged: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: '订阅'),
          BottomNavigationBarItem(icon: Icon(Icons.link), label: '节点'),
          BottomNavigationBarItem(icon: Icon(Icons.call_split), label: '分流'),
          BottomNavigationBarItem(icon: Icon(Icons.power_settings_new), label: '控制'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.secondary,
        backgroundColor: colorScheme.surface,
        onTap: _onItemTapped,
      ),
    );
  }
}

VoidCallback showSnackBarGlobal(String type, String text) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return () {};

  final context = messenger.context;

  if (type == "load") {
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(hours: 1),
        content: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  } else if (type == "success") {
    messenger.showSnackBar(
      SnackBar(
        content: GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: text));
          },
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 3),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      ),
    );
  } else {
    messenger.showSnackBar(
      SnackBar(
        content: GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: text));
          },
          child: Row(
            children: [
              Icon(Icons.error, size: 16, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      ),
    );
  }

  return () {
    scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  };
}