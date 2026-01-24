import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:chcg_iot_app/pages/home_tabs/advanced/group_control_execute_page.dart';

class GroupControlItemsPage extends StatefulWidget {
  final String groupUUID;

  final bool asEmbedded;

  const GroupControlItemsPage({
    super.key,
    required this.groupUUID,
    this.asEmbedded = false,
  });

  @override
  State<GroupControlItemsPage> createState() => GroupControlItemsPageState();
}

class GroupControlItemsPageState  extends State<GroupControlItemsPage> {

  Future<void> openAddDialog() => _openAddDialog();
  static const Color _primaryColor = Color(0xFF7B4DBB);

  final apiService = ApiService();

  bool _loading = true;
  bool _saving = false;

  List<dynamic> _items = [];

  // 用於新增：System/Target/Device/ActuatorObservation 選擇
  List<dynamic> _systems = [];
  List<dynamic> _targets = [];
  List<dynamic> _devices = [];

  String? _selectedSystemUUID;
  String? _selectedTargetUUID;

  @override
  void initState() {
    super.initState();
    _loadAll();
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
      builder:
          (_) => AlertDialog(
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

  Future<void> _loadAll() async {
    setState(() => _loading = true);

    await _requireLoginIfNeeded();
    final token = await _getToken();
    if (token == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      // 1) 拉群組 items
      final items = await apiService.fetchActuatorObservationGroupItems(
        token: token,
        groupUUID: widget.groupUUID,
      );

      // 2) 拉 systems/targets（給新增用）
      final systems = await apiService.fetchSystems(token);
      final targets = await apiService.fetchTargets(token);

      if (!mounted) return;
      setState(() {
        _items = items ?? [];
        _systems = systems ?? [];
        _targets = targets ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('載入失敗: $e')));
    }
  }

  List<dynamic> _targetsUnderSelectedSystem() {
    if (_selectedSystemUUID == null) return [];
    return _targets
        .where((t) => t['systemUUID'] == _selectedSystemUUID)
        .toList();
  }

  Future<void> _loadDevicesByTarget(String targetUUID) async {
    final token = await _getToken();
    if (token == null) return;

    setState(() => _saving = true);

    try {
      final devices = await apiService.fetchDevices(token, targetUUID);
      if (!mounted) return;
      setState(() {
        _devices = devices ?? [];
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('取得 Devices 失敗: $e')));
    }
  }

  /// 從 devices 中抓出所有 style=Actuator 的 observationlatest
  List<Map<String, dynamic>> _buildSelectableActuatorsFromDevices() {
    final List<Map<String, dynamic>> result = [];

    for (final d in _devices) {
      final deviceUUID = (d['deviceUUID'] ?? '').toString();
      final deviceName = (d['name'] ?? '未命名裝置').toString();
      final obs = (d['observationlatest'] as List?) ?? [];

      for (final o in obs) {
        final style = (o['style'] ?? '').toString().toLowerCase();
        if (style != 'actuator') continue;

        final featureEnglishName = (o['featureEnglishName'] ?? '').toString();
        final serialId = (o['serialId'] ?? '').toString();
        final alias = (o['alias'] ?? '').toString();
        final deviceFeatureName = (o['deviceFeatureName'] ?? '').toString();

        if (deviceUUID.isEmpty ||
            featureEnglishName.isEmpty ||
            serialId.isEmpty)
          continue;

        result.add({
          'deviceUUID': deviceUUID,
          'deviceName': deviceName,
          'featureEnglishName': featureEnglishName,
          'serialId': serialId,
          'alias': alias,
          'deviceFeatureName': deviceFeatureName,
        });
      }
    }

    // 排序：先 deviceName，再 serialId
    result.sort((a, b) {
      final an = (a['deviceName'] ?? '').toString().toLowerCase();
      final bn = (b['deviceName'] ?? '').toString().toLowerCase();
      final c = an.compareTo(bn);
      if (c != 0) return c;
      final aser = int.tryParse((a['serialId'] ?? '0').toString()) ?? 0;
      final bser = int.tryParse((b['serialId'] ?? '0').toString()) ?? 0;
      return aser.compareTo(bser);
    });

    return result;
  }

  bool _isAlreadyInGroup(Map<String, dynamic> candidate) {
    final duuid = candidate['deviceUUID'];
    final fen = candidate['featureEnglishName'];
    final sid = candidate['serialId'];

    return _items.any((it) {
      return (it['deviceUUID'] ?? '').toString() == duuid &&
          (it['featureEnglishName'] ?? '').toString() == fen &&
          (it['serialId'] ?? '').toString() == sid;
    });
  }

  Future<void> _openAddDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String? sheetSystemUUID;
        String? sheetTargetUUID;
        List<dynamic> sheetDevices = [];
        bool sheetLoadingDevices = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> loadDevices(String targetUUID) async {
              final token = await _getToken();
              if (token == null) return;

              setSheetState(() => sheetLoadingDevices = true);
              try {
                final devices = await apiService.fetchDevices(
                  token,
                  targetUUID,
                );
                sheetDevices = devices ?? [];
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('取得 Devices 失敗: $e')));
                }
              } finally {
                setSheetState(() => sheetLoadingDevices = false);
              }
            }

            List<dynamic> targetsUnderSystem() {
              if (sheetSystemUUID == null) return [];
              return _targets
                  .where((t) => t['systemUUID'] == sheetSystemUUID)
                  .toList();
            }

            List<Map<String, dynamic>> buildCandidates() {
              final List<Map<String, dynamic>> result = [];

              for (final d in sheetDevices) {
                final deviceUUID = (d['deviceUUID'] ?? '').toString();
                final deviceName = (d['name'] ?? '未命名裝置').toString();
                final obs = (d['observationlatest'] as List?) ?? [];

                for (final o in obs) {
                  final style = (o['style'] ?? '').toString().toLowerCase();
                  if (style != 'actuator') continue;

                  final featureEnglishName =
                      (o['featureEnglishName'] ?? '').toString();
                  final serialId = (o['serialId'] ?? '').toString();
                  final alias = (o['alias'] ?? '').toString();
                  final deviceFeatureName =
                      (o['deviceFeatureName'] ?? '').toString();

                  if (deviceUUID.isEmpty ||
                      featureEnglishName.isEmpty ||
                      serialId.isEmpty)
                    continue;

                  result.add({
                    'deviceUUID': deviceUUID,
                    'deviceName': deviceName,
                    'featureEnglishName': featureEnglishName,
                    'serialId': serialId,
                    'alias': alias,
                    'deviceFeatureName': deviceFeatureName,
                  });
                }
              }

              result.sort((a, b) {
                final an = (a['deviceName'] ?? '').toString().toLowerCase();
                final bn = (b['deviceName'] ?? '').toString().toLowerCase();
                final c = an.compareTo(bn);
                if (c != 0) return c;
                final aser =
                    int.tryParse((a['serialId'] ?? '0').toString()) ?? 0;
                final bser =
                    int.tryParse((b['serialId'] ?? '0').toString()) ?? 0;
                return aser.compareTo(bser);
              });

              return result;
            }

            bool alreadyInGroup(Map<String, dynamic> c) {
              return _isAlreadyInGroup(c);
            }

            return _AddItemSheet(
              primaryColor: _primaryColor,
              systems: _systems,
              targets: _targets,
              selectedSystemUUID: sheetSystemUUID,
              selectedTargetUUID: sheetTargetUUID,
              onSystemChanged: (v) {
                setSheetState(() {
                  sheetSystemUUID = v;
                  sheetTargetUUID = null;
                  sheetDevices = [];
                });
              },
              onTargetChanged: (v) async {
                if (v == null) return;
                setSheetState(() => sheetTargetUUID = v);
                await loadDevices(v);
              },
              loadingDevices: sheetLoadingDevices,
              buildCandidates: buildCandidates,
              isAlreadyInGroup: alreadyInGroup,
              onAdd: (candidate) async {
                final token = await _getToken();
                if (token == null) return;

                try {
                  await apiService.addActuatorObservationGroupItem(
                    token: token,
                    groupUUID: widget.groupUUID,
                    deviceUUID: candidate['deviceUUID'],
                    featureEnglishName: candidate['featureEnglishName'],
                    serialId: candidate['serialId'],
                  );

                  if (!mounted) return;
                  Navigator.pop(context);

                  ScaffoldMessenger.of(
                    this.context,
                  ).showSnackBar(const SnackBar(content: Text('已加入群組')));

                  await _loadAll();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    this.context,
                  ).showSnackBar(SnackBar(content: Text('新增失敗: $e')));
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _deleteItem(dynamic item) async {
    final token = await _getToken();
    if (token == null) return;

    final itemUUID =
        (item['itemUUID'] ?? item['uuid'] ?? item['id'] ?? '').toString();
    if (itemUUID.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('缺少 itemUUID，無法刪除')));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('刪除項目？'),
            content: const Text('確定要從群組移除這個致動器項目嗎？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('刪除'),
              ),
            ],
          ),
    );

    if (ok != true) return;

    try {
      await apiService.deleteActuatorObservationGroupItem(
        token: token,
        groupUUID: widget.groupUUID,
        itemUUID: itemUUID,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除')));
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final content =
        _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
              child:
                  _items.isEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final it = _items[i] as Map;

                          final deviceName =
                              (it['deviceName'] ??
                                      it['device_name'] ??
                                      it['deviceID'] ??
                                      '未命名裝置')
                                  .toString();
                          final alias = (it['alias'] ?? '').toString();
                          final featureName =
                              (it['deviceFeatureName'] ??
                                      it['feature_name'] ??
                                      it['featureEnglishName'] ??
                                      it['featureName'] ??
                                      '')
                                  .toString();
                          final serialId = (it['serialId'] ?? '').toString();

                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.toggle_on_rounded,
                                color: _primaryColor,
                              ),
                              title: Text(
                                alias.isNotEmpty ? alias : featureName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                '$deviceName · serialId=$serialId',
                              ),
                              trailing: IconButton(
                                tooltip: '刪除',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteItem(it),
                              ),
                            ),
                          );
                        },
                      ),
            );

    if (widget.asEmbedded) {
      return content; // ✅ 給 Tab 用
    }

    // ✅ 如果你未來還想單獨 push ItemsPage，也可以保留原本 Scaffold（但不要 refresh）
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '群組 Items',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        centerTitle: true,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('新增項目'),
      ),
      body: content,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '目前群組內沒有任何致動器項目。\n\n點右下角「新增項目」開始加入。',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700, height: 1.4),
        ),
      ),
    );
  }
}

/// BottomSheet：選 system → 選 target → 列出 actuator candidates
class _AddItemSheet extends StatelessWidget {
  final Color primaryColor;

  final List<dynamic> systems;
  final List<dynamic> targets;

  final String? selectedSystemUUID;
  final String? selectedTargetUUID;

  final void Function(String?) onSystemChanged;
  final void Function(String?) onTargetChanged;

  final bool loadingDevices;

  final List<Map<String, dynamic>> Function() buildCandidates;
  final bool Function(Map<String, dynamic>) isAlreadyInGroup;
  final Future<void> Function(Map<String, dynamic>) onAdd;

  const _AddItemSheet({
    required this.primaryColor,
    required this.systems,
    required this.targets,
    required this.selectedSystemUUID,
    required this.selectedTargetUUID,
    required this.onSystemChanged,
    required this.onTargetChanged,
    required this.loadingDevices,
    required this.buildCandidates,
    required this.isAlreadyInGroup,
    required this.onAdd,
  });

  List<dynamic> _targetsUnderSystem() {
    if (selectedSystemUUID == null) return [];
    return targets.where((t) => t['systemUUID'] == selectedSystemUUID).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidates = buildCandidates();
    final tList = _targetsUnderSystem();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          color: Colors.white.withOpacity(0.94),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),

                Row(
                  children: [
                    const Icon(Icons.add_circle_outline),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '新增致動器項目到群組',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: selectedSystemUUID,
                  decoration: const InputDecoration(
                    labelText: '選擇系統',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items:
                      systems.map<DropdownMenuItem<String>>((s) {
                        return DropdownMenuItem<String>(
                          value: (s['systemUUID'] ?? '').toString(),
                          child: Text((s['name'] ?? '未命名系統').toString()),
                        );
                      }).toList(),
                  onChanged: onSystemChanged,
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: selectedTargetUUID,
                  decoration: const InputDecoration(
                    labelText: '選擇目標',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items:
                      tList.map<DropdownMenuItem<String>>((t) {
                        return DropdownMenuItem<String>(
                          value: (t['targetUUID'] ?? '').toString(),
                          child: Text((t['area'] ?? '未命名目標').toString()),
                        );
                      }).toList(),
                  onChanged:
                      (selectedSystemUUID == null) ? null : onTargetChanged,
                ),

                const SizedBox(height: 12),

                if (loadingDevices)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  )
                else if (selectedTargetUUID == null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '請先選擇目標，系統會載入該目標底下的裝置，並列出可加入的致動器。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (candidates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('此目標底下沒有可加入的致動器（style=Actuator）'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: candidates.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = candidates[i];
                        final deviceName = (c['deviceName'] ?? '').toString();
                        final alias = (c['alias'] ?? '').toString();
                        final fname =
                            (c['deviceFeatureName'] ??
                                    c['featureEnglishName'] ??
                                    '')
                                .toString();
                        final serialId = (c['serialId'] ?? '').toString();

                        final already = isAlreadyInGroup(c);

                        return ListTile(
                          leading: Icon(
                            Icons.toggle_on_rounded,
                            color: already ? Colors.black26 : primaryColor,
                          ),
                          title: Text(
                            alias.isNotEmpty ? alias : fname,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text('$deviceName · serialId=$serialId'),
                          trailing:
                              already
                                  ? const Text(
                                    '已在群組',
                                    style: TextStyle(color: Colors.black45),
                                  )
                                  : FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: primaryColor,
                                    ),
                                    onPressed: () => onAdd(c),
                                    child: const Text('加入'),
                                  ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
