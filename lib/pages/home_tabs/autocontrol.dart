import 'package:flutter/material.dart';
import 'package:chcg_iot_app/pages/home_tabs/TimeControlTab.dart';
import 'package:chcg_iot_app/pages/home_tabs/ConditionControlTab.dart';
import 'package:chcg_iot_app/pages/home_tabs/CycleControlTab.dart';
import 'package:chcg_iot_app/pages/home_tabs/PulseControlTab.dart';
class AutoControlPage extends StatefulWidget {
  final Object obs; 
  final String deviceUUID;
  final String featureEnglishName;
  final String serialId;

  const AutoControlPage({
    super.key,
    required this.obs,
    required this.deviceUUID,
    required this.featureEnglishName,
    required this.serialId,
  });

  @override
  State<AutoControlPage> createState() => _AutoControlPageState();
}

class _AutoControlPageState extends State<AutoControlPage> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;
  

  @override
  void initState() {
    super.initState();
    
    _pages = [
      TimeControlTab(
        deviceUUID: widget.deviceUUID,
        featureEnglishName: widget.featureEnglishName,
        serialId: widget.serialId,
      ),
      ConditionControlTab(
        deviceUUID: widget.deviceUUID,
        featureEnglishName: widget.featureEnglishName,
        serialId: widget.serialId,
      ),
      CycleControlTab(
        deviceUUID: widget.deviceUUID,
        featureEnglishName: widget.featureEnglishName,
        serialId: widget.serialId,
      ),
      PulseControlTab( // ✅ 新增
        deviceUUID: widget.deviceUUID,
        featureEnglishName: widget.featureEnglishName,
        serialId: widget.serialId,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '自動控制',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF7B4DBB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          
          NavigationDestination(
            icon: Icon(Icons.access_time),
            label: "定時控制",
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud),
            label: "環境條件",
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud),
            label: "循環控制",
          ),
          NavigationDestination( // ✅ 新增
            icon: Icon(Icons.flash_on),
            label: "秒數控制",
          ),
        ],
      ),
    );
  }
}
