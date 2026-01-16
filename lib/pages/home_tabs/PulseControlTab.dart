import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chcg_iot_app/core/api_service.dart';

class PulseControlTab extends StatefulWidget {
  final String deviceUUID;
  final String featureEnglishName;
  final String serialId;

  const PulseControlTab({
    super.key,
    required this.deviceUUID,
    required this.featureEnglishName,
    required this.serialId,
  });

  @override
  State<PulseControlTab> createState() => _PulseControlTabState();
}

class _PulseControlTabState extends State<PulseControlTab> {
  final apiService = ApiService();

  final _secondsCtrl = TextEditingController(text: "10");
  bool _turnOnFirst = true;
  bool _loading = false;

  bool _suppressFinishToast = false; // 隱藏後 = true（不顯示完成提示）
bool _reverseSent = false;         // 防止補送重複


  @override
  void dispose() {
    _secondsCtrl.dispose();
    super.dispose();
  }

  int? _parseSeconds() {
    final s = _secondsCtrl.text.trim();
    final v = int.tryParse(s);
    if (v == null || v <= 0) return null;
    return v;
  }

  bool _reverseBool(bool v) => !v;

  Future<void> _sendFinalReverse(bool reverseOn) async {
    await apiService.switchSetting(
      deviceUUID: widget.deviceUUID,
      featureEnglishName: widget.featureEnglishName,
      serialId: widget.serialId,
      newValue: reverseOn,
    );
  }

  Future<bool> _showCountdownDialogAndWait({
  required int seconds,
  required bool firstOn,
}) async {
  int remain = seconds;
  Timer? timer;

  _suppressFinishToast = false;
  _reverseSent = false;

  Future<void> sendReverseOnce() async {
    if (_reverseSent) return;
    _reverseSent = true;

    await apiService.switchSetting(
      deviceUUID: widget.deviceUUID,
      featureEnglishName: widget.featureEnglishName,
      serialId: widget.serialId,
      newValue: !firstOn,
    );
  }

  bool shouldShowFinishToast = true; // 預設會顯示；按隱藏後改 false

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

              // 倒數自然結束：補送一次
              await sendReverseOnce();

              // 依是否隱藏決定要不要提示
              shouldShowFinishToast = !_suppressFinishToast;

              if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
              return;
            }
            setLocalState(() => remain -= 1);
          });

          return AlertDialog(
            title: const Text('脈衝倒數中'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '已送出：先${firstOn ? "開啟" : "關閉"}\n'
                  '倒數結束後會補送一次反向控制',
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
              // 隱藏：只關 dialog，且「之後完成不提示」
              TextButton(
                onPressed: () {
                  _suppressFinishToast = true;
                  shouldShowFinishToast = false;
                  if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                },
                child: const Text('隱藏'),
              ),

              // 結束：立刻補送 + 關 dialog，且「一定提示」
              FilledButton(
                onPressed: () async {
                  timer?.cancel();
                  await sendReverseOnce();
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
    final seconds = _parseSeconds();
    if (seconds == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('秒數必須是大於 0 的整數')),
      );
      return;
    }

    setState(() => _loading = true);

    final firstOn = _turnOnFirst;
    final reverseOn = _reverseBool(firstOn);

    try {
      // 1) 送出 pulse API（你的後端會排程反向）
      await apiService.pulseSetting(
        deviceUUID: widget.deviceUUID,
        featureEnglishName: widget.featureEnglishName,
        serialId: widget.serialId,
        turnOnFirst: firstOn,
        durationSeconds: seconds,
      );

      if (!mounted) return;

      // 2) 顯示倒數視窗
      await _showCountdownDialogAndWait(seconds: seconds, firstOn: firstOn);

      if (!mounted) return;

      // 3) 倒數完畢補送一次「一般控制」(反向)
      //    避免伺服器或排程有 bug 時，最終狀態仍能正確落地
      
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '秒數控制（脈衝）',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          '送出後會先${_turnOnFirst ? "開啟" : "關閉"}，到時間自動反向一次。\n倒數結束後會再補送一次一般控制，避免伺服器異常。',
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),

        // 動作選擇
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
                  child: Text(
                    '第一步動作',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('先開')),
                    ButtonSegment(value: false, label: Text('先關')),
                  ],
                  selected: {_turnOnFirst},
                  onSelectionChanged: (s) {
                    setState(() => _turnOnFirst = s.first);
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 秒數輸入
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
                  child: Text(
                    '持續秒數',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
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

        // 送出按鈕
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
            label: Text(_loading ? '送出中...' : '送出脈衝控制'),
          ),
        ),
      ],
    );
  }
}
