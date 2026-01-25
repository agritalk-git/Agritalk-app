// pages/home_page.dart
import 'package:flutter/material.dart';
import 'home_tabs/home_tab.dart';
import 'home_tabs/war_room_tab.dart';
import 'home_tabs/advanced.dart';
import 'home_tabs/profile_tab.dart';
import 'home_tabs/about.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _tabs = [
    HomeTab(), 
    WarRoomTab(),AdvancedTab(), ProfileTab(), AboutTab()];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final shouldLogout = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('是否要登出？'),
                content: const Text('確定要登出並返回登入畫面？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('是'),
                  ),
                ],
              ),
        );

        if (shouldLogout == true) {
         

          final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');

    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
        }

        return false; // 阻止預設 pop 行為
      },
      child: Scaffold(
        body: _tabs[_selectedIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '首頁',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: '戰情室',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune),
              selectedIcon: Icon(Icons.tune),
              label: '進階',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '我的',
            ),
            NavigationDestination(
              icon: Icon(Icons.public),
              selectedIcon: Icon(Icons.public),
              label: '關於我們',
            ),
          ],
        ),
      ),
    );
  }
}
