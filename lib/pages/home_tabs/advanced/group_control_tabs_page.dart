import 'package:flutter/material.dart';
import 'package:chcg_iot_app/pages/home_tabs/advanced/group_control_items_page.dart';
import 'package:chcg_iot_app/pages/home_tabs/advanced/group_control_execute_page.dart';

class GroupControlTabsPage extends StatefulWidget {
  final String groupUUID;
  const GroupControlTabsPage({super.key, required this.groupUUID});

  @override
  State<GroupControlTabsPage> createState() => _GroupControlTabsPageState();
}

class _GroupControlTabsPageState extends State<GroupControlTabsPage>
    with SingleTickerProviderStateMixin {
  static const Color _primaryColor = Color(0xFF7B4DBB);

  late final TabController _tabController;

  // ✅ 讓 Tabs 可以呼叫 ItemsPageState.openAddDialog()
  final GlobalKey<GroupControlItemsPageState> _itemsKey =
      GlobalKey<GroupControlItemsPageState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isItemsTab => _tabController.index == 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '群組控制',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.65),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: '項目', icon: Icon(Icons.view_list)),
            Tab(text: '一般', icon: Icon(Icons.power_settings_new)),
            Tab(text: '秒數', icon: Icon(Icons.timer)),
            Tab(text: '定時', icon: Icon(Icons.schedule)),
            Tab(text: '循環', icon: Icon(Icons.loop)),
          ],
        ),
      ),

      // ✅ 把新增 FAB 放在 TabsPage（Items tab 才顯示）
      floatingActionButton: _isItemsTab
          ? FloatingActionButton.extended(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              onPressed: () => _itemsKey.currentState?.openAddDialog(),
              icon: const Icon(Icons.add),
              label: const Text('新增項目'),
            )
          : null,

      body: TabBarView(
        controller: _tabController,
        children: [
          GroupControlItemsPage(
            key: _itemsKey, // ✅ 一定要給 key
            groupUUID: widget.groupUUID,
            asEmbedded: true,
          ),
          GroupControlExecutePage(groupUUID: widget.groupUUID),
          const _ComingSoonPage(
            title: '秒數控制（PULSE）',
            desc: '下一步會做每個 item 的秒數控制與批次操作。',
          ),
          const _ComingSoonPage(
            title: '定時控制（Schedule）',
            desc: '依星期/時間設定觸發（固定時間點）。',
          ),
          const _ComingSoonPage(
            title: '循環控制（Loop）',
            desc: 'ON X 秒 / OFF Y 秒 的循環控制。',
          ),
        ],
      ),
    );
  }
}

class _ComingSoonPage extends StatelessWidget {
  final String title;
  final String desc;

  const _ComingSoonPage({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction, size: 40),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(desc, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
