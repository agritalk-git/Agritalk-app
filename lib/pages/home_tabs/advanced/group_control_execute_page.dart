import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chcg_iot_app/core/api_service.dart';

class GroupControlExecutePage extends StatefulWidget {
  final String groupUUID;
  const GroupControlExecutePage({super.key, required this.groupUUID});

  @override
  State<GroupControlExecutePage> createState() =>
      _GroupControlExecutePageState();
}

class _GroupControlExecutePageState extends State<GroupControlExecutePage> {
  static const Color _primaryColor = Color(0xFF7B4DBB);

  final apiService = ApiService();

  bool _loading = true;
  String? _error;

  List<dynamic> _items = [];

  // per-item UI state
  final Map<String, bool> _uiValueByItemUUID = {}; // itemUUID -> bool(on/off)
  final Map<String, bool> _loadingByItemUUID = {}; // itemUUID -> loading
  final Map<String, String?> _errorByItemUUID = {}; // itemUUID -> error

  // bulk state
  bool _bulkRunning = false;
  int _bulkDone = 0;
  int _bulkTotal = 0;
  int _bulkSuccess = 0;
  int _bulkFail = 0;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty || token == 'GUEST_MODE') return null;
    return token;
  }

  Future<void> _loadItems() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = await _getToken();
    if (token == null) {
      setState(() {
        _loading = false;
        _error = '請先登入';
      });
      return;
    }

    try {
      final items = await apiService.fetchActuatorObservationGroupItems(
        token: token,
        groupUUID: widget.groupUUID,
      );

      if (!mounted) return;
      _items = (items ?? []).toList();

      // 初始化 UI 值：這裡先用 false 當預設（因為目前還沒接「查狀態」API）
      // 之後你如果有「目前開關狀態」欄位，就在這裡改成從 item 填入
      _uiValueByItemUUID.clear();
      _loadingByItemUUID.clear();
      _errorByItemUUID.clear();

      for (final it in _items) {
        final m = (it as Map);
        final itemUUID =
            (m['itemUUID'] ?? m['uuid'] ?? m['id'] ?? '').toString();
        if (itemUUID.isEmpty) continue;

        // TODO: 如果後端回傳目前狀態，例如 it['current'] / it['value']，可改這行
        _uiValueByItemUUID[itemUUID] = false;
        _loadingByItemUUID[itemUUID] = false;
        _errorByItemUUID[itemUUID] = null;
      }

      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '載入失敗: $e';
      });
    }
  }

  // ============
  // Control send (stub)
  // ============
  Future<void> _sendControl({
    required Map item,
    required bool nextValue,
  }) async {
    final deviceUUID = (item['deviceUUID'] ?? '').toString();
    final featureEnglishName = (item['featureEnglishName'] ?? '').toString();
    final serialId = (item['serialId'] ?? '').toString();

    if (deviceUUID.isEmpty || featureEnglishName.isEmpty || serialId.isEmpty) {
      throw Exception('item 缺少 deviceUUID / featureEnglishName / serialId');
    }

    final ok = await apiService.switchSetting(
      deviceUUID: deviceUUID,
      featureEnglishName: featureEnglishName,
      serialId: serialId,
      newValue: nextValue,
    );

    if (!ok) {
      throw Exception('switchSetting 回傳失敗');
    }

    // ✅ 若你希望 item 的 value 也同步（方便之後做狀態顯示），可以順便寫回去
    item['value'] = nextValue.toString();
  }

  String _itemUUIDOf(Map it) =>
      (it['itemUUID'] ?? it['uuid'] ?? it['id'] ?? '').toString();

  Future<bool> _toggleOne(Map item, bool next) async {
    final itemUUID = _itemUUIDOf(item);
    if (itemUUID.isEmpty) return false;

    if (_loadingByItemUUID[itemUUID] == true) return false;

    final prev = _uiValueByItemUUID[itemUUID] ?? false;

    setState(() {
      _uiValueByItemUUID[itemUUID] = next; // 樂觀更新
      _loadingByItemUUID[itemUUID] = true;
      _errorByItemUUID[itemUUID] = null;
    });

    try {
      await _sendControl(item: item, nextValue: next);

      if (!mounted) return true;
      setState(() {
        _loadingByItemUUID[itemUUID] = false;
        _errorByItemUUID[itemUUID] = null;
      });

      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _uiValueByItemUUID[itemUUID] = prev; // 回復
        _loadingByItemUUID[itemUUID] = false;
        _errorByItemUUID[itemUUID] = e.toString();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('控制失敗：$e')));

      return false;
    }
  }

  Future<void> _confirmAndBulk(bool nextValue) async {
    if (_items.isEmpty) return;
    if (_bulkRunning) return;

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(nextValue ? '全部開啟？' : '全部關閉？'),
            content: Text('將對群組內 ${_items.length} 個致動器送出控制指令。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('確定'),
              ),
            ],
          ),
    );

    if (ok != true) return;

    setState(() {
      _bulkRunning = true;
      _bulkDone = 0;
      _bulkTotal = _items.length;
      _bulkSuccess = 0;
      _bulkFail = 0;
    });

    // 逐筆送出（避免一次打爆）
    for (final raw in _items) {
      if (!mounted) return;
      final item = (raw as Map);
      final itemUUID = _itemUUIDOf(item);
      if (itemUUID.isEmpty) {
        setState(() {
          _bulkDone += 1;
          _bulkFail += 1;
        });
        continue;
      }

      try {
        await _toggleOne(item, nextValue);
        if (!mounted) return;
        setState(() {
          _bulkDone += 1;
          _bulkSuccess += 1;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _bulkDone += 1;
          _bulkFail += 1;
        });
      }

      // 小延遲讓後端喘口氣（可依你系統調整）
      await Future.delayed(const Duration(milliseconds: 80));
    }

    if (!mounted) return;
    setState(() => _bulkRunning = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('批次完成：成功 $_bulkSuccess / 失敗 $_bulkFail')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),

      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _ErrorState(message: _error!, onRetry: _loadItems)
              : _items.isEmpty
              ? const _EmptyState()
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: _SummaryCard(
                      primaryColor: _primaryColor,
                      itemCount: _items.length,
                      bulkRunning: _bulkRunning,
                      bulkDone: _bulkDone,
                      bulkTotal: _bulkTotal,
                      bulkSuccess: _bulkSuccess,
                      bulkFail: _bulkFail,
                      onAllOn: () => _confirmAndBulk(true),
                      onAllOff: () => _confirmAndBulk(false),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final it = (_items[i] as Map);

                        final itemUUID = _itemUUIDOf(it);
                        final deviceName =
                            (it['deviceName'] ??
                                    it['device_name'] ??
                                    it['deviceID'] ??
                                    '未命名裝置')
                                .toString();
                        final alias = (it['alias'] ?? '').toString();
                        final featureName =
                            (it['featureName'] ??
                                    it['deviceFeatureName'] ??
                                    it['featureEnglishName'] ??
                                    '')
                                .toString();
                        final serialId = (it['serialId'] ?? '').toString();

                        final val = _uiValueByItemUUID[itemUUID] ?? false;
                        final loading = _loadingByItemUUID[itemUUID] ?? false;
                        final err = _errorByItemUUID[itemUUID];

                        return _ItemControlCard(
                          primaryColor: _primaryColor,
                          title: alias.isNotEmpty ? alias : featureName,
                          subtitle: '$deviceName · serialId=$serialId',
                          value: val,
                          loading: loading || _bulkRunning,
                          errorText: err,
                          onChanged: (next) async {
                            await _toggleOne(it, next);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Color primaryColor;
  final int itemCount;

  final bool bulkRunning;
  final int bulkDone;
  final int bulkTotal;
  final int bulkSuccess;
  final int bulkFail;

  final VoidCallback onAllOn;
  final VoidCallback onAllOff;

  const _SummaryCard({
    required this.primaryColor,
    required this.itemCount,
    required this.bulkRunning,
    required this.bulkDone,
    required this.bulkTotal,
    required this.bulkSuccess,
    required this.bulkFail,
    required this.onAllOn,
    required this.onAllOff,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        (bulkTotal == 0) ? 0.0 : (bulkDone / bulkTotal).clamp(0.0, 1.0);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hub, color: primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '群組致動器（$itemCount）',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (bulkRunning)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '送出中 $bulkDone/$bulkTotal',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                    ),
                    onPressed: bulkRunning ? null : onAllOn,
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('全部開'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                    ),
                    onPressed: bulkRunning ? null : onAllOff,
                    icon: const Icon(Icons.power_off),
                    label: const Text('全部關'),
                  ),
                ),
              ],
            ),
            if (bulkRunning) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 6),
              Text(
                '成功 $bulkSuccess / 失敗 $bulkFail',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemControlCard extends StatelessWidget {
  final Color primaryColor;
  final String title;
  final String subtitle;
  final bool value;
  final bool loading;
  final String? errorText;
  final ValueChanged<bool> onChanged;

  const _ItemControlCard({
    required this.primaryColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.loading,
    required this.errorText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = (errorText != null && errorText!.trim().isNotEmpty);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.toggle_on_rounded, color: primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (loading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(
                    value: value,
                    activeColor: primaryColor,
                    onChanged: loading ? null : onChanged,
                  ),
              ],
            ),
            if (hasError) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  errorText!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '群組內目前沒有致動器項目。\n\n請先回到上一頁加入 items。',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 140),
        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: FilledButton(
            onPressed: () => onRetry(),
            child: const Text('重試'),
          ),
        ),
      ],
    );
  }
}
