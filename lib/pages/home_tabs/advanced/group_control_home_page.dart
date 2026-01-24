import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:chcg_iot_app/pages/home_tabs/advanced/group_control_items_page.dart';
import 'package:chcg_iot_app/pages/home_tabs/advanced/group_control_tabs_page.dart';

final apiService = ApiService();

class GroupControlHomePage extends StatefulWidget {
  const GroupControlHomePage({super.key});

  @override
  State<GroupControlHomePage> createState() => _GroupControlHomePageState();
}

class _GroupControlHomePageState extends State<GroupControlHomePage> {
  static const Color _primaryColor = Color(0xFF7B4DBB);

  bool _loading = true;
  String? _error;
  List<dynamic> _groups = [];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty || token == 'GUEST_MODE') return null;
    return token;
  }

  Future<void> _requireLoginIfNeeded() async {
    final token = await _getToken();
    if (token != null) return;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('請先登入'),
        content: const Text('您需要登入才能使用群組控制功能。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/');
            },
            child: const Text('前往登入'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadGroups() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    await _requireLoginIfNeeded();
    final token = await _getToken();
    if (token == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    try {
      final list = await apiService.fetchActuatorObservationGroups(token: token);

      if (!mounted) return;

      if (list == null) {
        setState(() {
          _loading = false;
          _error = '取得群組失敗（回傳為 null）';
        });
        return;
      }

      setState(() {
        _groups = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _createGroup() async {
    final nameCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('新增群組'),
          content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: '群組名稱',
              hintText: '例如：溫室A 致動器群組',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('建立'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('群組名稱不能為空')),
      );
      return;
    }

    try {
      final token = await _getToken();
      if (token == null) throw Exception('請先登入');

      await apiService.createActuatorObservationGroup(
        token: token,
        name: name,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已建立群組')),
      );

      await _loadGroups();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('建立失敗：$e')),
      );
    }
  }

  Future<void> _deleteGroup(String groupUUID) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除群組'),
        content: const Text('確定要刪除此群組？（群組內 items 也會一併刪除）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final token = await _getToken();
      if (token == null) throw Exception('請先登入');

      await apiService.deleteActuatorObservationGroup(
        token: token,
        groupUUID: groupUUID,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已刪除群組')),
      );

      await _loadGroups();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刪除失敗：$e')),
      );
    }
  }

  void _openGroup(dynamic g) {
  final groupUUID = (g['groupUUID'] ?? g['uuid'] ?? g['id'] ?? '').toString();
  if (groupUUID.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('群組缺少 groupUUID')),
    );
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => GroupControlTabsPage(groupUUID: groupUUID),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '群組控制',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        actions: [
          // IconButton(
          //   tooltip: '重新整理',
          //   icon: const Icon(Icons.refresh),
          //   onPressed: _loadGroups,
          // ),
          IconButton(
            tooltip: '新增群組',
            icon: const Icon(Icons.add),
            onPressed: _createGroup,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadGroups,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: FilledButton(
                          onPressed: _loadGroups,
                          child: const Text('重試'),
                        ),
                      ),
                    ],
                  )
                : _groups.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Text(
                              '目前還沒有群組\n請點右上角 + 建立一個',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _groups.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final g = _groups[i] as Map;
                          final name = (g['name'] ?? '未命名群組').toString();
                          final groupUUID =
                              (g['groupUUID'] ?? g['uuid'] ?? g['id'] ?? '')
                                  .toString();

                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _openGroup(g),
                              onLongPress: groupUUID.isEmpty
                                  ? null
                                  : () => _deleteGroup(groupUUID),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: theme.colorScheme
                                            .surfaceContainerHighest,
                                      ),
                                      child: const Icon(Icons.view_module),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (groupUUID.isNotEmpty)
                                      IconButton(
                                        tooltip: '刪除',
                                        onPressed: () => _deleteGroup(groupUUID),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
