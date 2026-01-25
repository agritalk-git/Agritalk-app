import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chcg_iot_app/core/api_service.dart';

class GroupPulseControlTab extends StatefulWidget {
  final String groupUUID;
  const GroupPulseControlTab({super.key, required this.groupUUID});

  @override
  State<GroupPulseControlTab> createState() => _GroupPulseControlTabState();
}

class _GroupPulseControlTabState extends State<GroupPulseControlTab> {
  final apiService = ApiService();

  final _secondsCtrl = TextEditingController(text: "10");
  bool _turnOnFirst = true;
  bool _loading = false;

  List<dynamic> _items = [];
  bool _loadingItems = true;
  String? _error;

  // 倒數 dialog 控制
  bool _suppressFinishToast = false;
  bool _reverseSent = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _secondsCtrl.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty || token == 'GUEST_MODE') return null;
    return token;
  }

  Future<void> _loadItems() async {
    setState(() {
      _loadingItems = true;
      _error = null;
    });

    try {
      final token = await _getToken();
      if (token == null) {
        setState(() {
          _error = '未登入或找不到 token';
          _loadingItems = false;
        });
        return;
      }

      final items = await apiService.fetchActuatorObservationGroupItems(
        token: token,
        groupUUID: widget.groupUUID,
      );

      setState(() {
        _items = items ?? [];
        _loadingItems = false;
      });
    } catch (e) {
      setState(() {
        _error = '載入群組 items 失敗：$e';
        _loadingItems = false;
      });
    }
  }

  int? _parseSeconds() {
    final s = _secondsCtrl.text.trim();
    final v = int.tryParse(s);
    if (v == null || v <= 0) return null;
    return v;
  }

  /// 取出 item 裡的必要欄位（你後端回傳 key 可能有大小寫差異，這裡做兼容）
  String _pickStr(Map it, List<String> keys) {
    for (final k in keys) {
      final v = it[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '';
  }

  Future<void> _sendReverseOnceToAll({required bool firstOn}) async {
    if (_reverseSent) return;
    _reverseSent = true;

    // 反向一次：!firstOn
    final reverseValue = !firstOn;

    // 逐筆補送，避免 API 同時爆量（你也可以改 Future.wait 但我建議先保守）
    for (final raw in _items) {
      final it = (raw as Map);
      final deviceUUID = _pickStr(it, ['deviceUUID', 'device_uuid']);
      final featureEnglishName = _pickStr(it, ['featureEnglishName', 'feature_english_name']);
      final serialId = _pickStr(it, ['serialId', 'serial_id']);

      if (deviceUUID.isEmpty || featureEnglishName.isEmpty || serialId.isEmpty) continue;

      await apiService.switchSetting(
        deviceUUID: deviceUUID,
        featureEnglishName: featureEnglishName,
        serialId: serialId,
        newValue: reverseValue,
      );
    }
  }

  Future<bool> _showCountdownDialogAndWait({
    required int seconds,
    required bool firstOn,
    required int totalCount,
    required int successCount,
  }) async {
    int remain = seconds;
    Timer? timer;

    _suppressFinishToast = false;
    _reverseSent = false;
    bool shouldShowFinishToast = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (t) async {
              if (!mounted) return;

              if (remain <= 1) {
                t.cancel();
                await _sendReverseOnceToAll(firstOn: firstOn);

                shouldShowFinishToast = !_suppressFinishToast;
                if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                return;
              }
              setLocalState(() => remain -= 1);
            });

            return AlertDialog(
              title: const Text('群組脈衝倒數中'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '已送出：先${firstOn ? "開啟" : "關閉"}\n'
                    '成功 $successCount / $totalCount\n'
                    '倒數結束後會補送一次「反向控制」到全部項目',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$remain',
                    style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text('秒'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _suppressFinishToast = true;
                    shouldShowFinishToast = false;
                    if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                  },
                  child: const Text('隱藏'),
                ),
                FilledButton(
                  onPressed: () async {
                    timer?.cancel();
                    await _sendReverseOnceToAll(firstOn: firstOn);
                    shouldShowFinishToast = true;

                    if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                  },
                  child: const Text('結束'),
                ),
              ],
            );
          },
        );
      },
    );

    timer?.cancel();
    return shouldShowFinishToast;
  }

  Future<void> _submit() async {
    if (_loading) return;

    final seconds = _parseSeconds();
    if (seconds == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('秒數必須是大於 0 的整數')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('群組內沒有 items，請先到 Items 加入致動器')),
      );
      return;
    }

    setState(() => _loading = true);

    final firstOn = _turnOnFirst;

    int success = 0;
    int fail = 0;

    try {
      // 1) 批次送出 pulse（逐筆送，較穩）
      for (final raw in _items) {
        final it = (raw as Map);
        final deviceUUID = _pickStr(it, ['deviceUUID', 'device_uuid']);
        final featureEnglishName = _pickStr(it, ['featureEnglishName', 'feature_english_name']);
        final serialId = _pickStr(it, ['serialId', 'serial_id']);

        if (deviceUUID.isEmpty || featureEnglishName.isEmpty || serialId.isEmpty) {
          fail += 1;
          continue;
        }

        try {
          await apiService.pulseSetting(
            deviceUUID: deviceUUID,
            featureEnglishName: featureEnglishName,
            serialId: serialId,
            turnOnFirst: firstOn,
            durationSeconds: seconds,
          );
          success += 1;
        } catch (_) {
          fail += 1;
        }
      }

      if (!mounted) return;

      // 2) 倒數視窗（顯示成功/總數）
      final showToast = await _showCountdownDialogAndWait(
        seconds: seconds,
        firstOn: firstOn,
        totalCount: _items.length,
        successCount: success,
      );

      if (!mounted) return;

      if (showToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('群組脈衝完成（成功 $success / ${_items.length}，失敗 $fail）')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('送出失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingItems) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '群組秒數控制（脈衝）',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: '重新載入 Items',
              onPressed: _loading ? null : _loadItems,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '群組內共 ${_items.length} 個項目。\n'
          '送出後會先${_turnOnFirst ? "開啟" : "關閉"}，到時間會反向一次；倒數結束也會再補送一次反向控制，避免伺服器排程異常。',
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),

        // 第一動作
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.flash_on),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('第一步動作', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('先開')),
                    ButtonSegment(value: false, label: Text('先關')),
                  ],
                  selected: {_turnOnFirst},
                  onSelectionChanged: (s) => setState(() => _turnOnFirst = s.first),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 秒數
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.timer),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('持續秒數', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _secondsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '例如 10',
                      suffixText: '秒',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 送出
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(_loading ? '送出中...' : '送出群組脈衝控制'),
          ),
        ),

        const SizedBox(height: 16),

        // 小提示：顯示 items 名稱
        Card(
          elevation: 0,
          color: Colors.grey.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('本次會控制這些項目：', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ..._items.take(8).map((raw) {
                  final it = raw as Map;
                  final alias = _pickStr(it, ['alias']);
                  final name = _pickStr(it, ['deviceFeatureName', 'featureName', 'featureEnglishName']);
                  final deviceName = _pickStr(it, ['deviceName', 'device_name', 'name']);
                  final serialId = _pickStr(it, ['serialId', 'serial_id']);
                  final title = alias.isNotEmpty ? alias : name;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $title（$deviceName / serialId=$serialId）'),
                  );
                }),
                if (_items.length > 8)
                  Text('… 以及其他 ${_items.length - 8} 個', style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
