import 'package:flutter/material.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupCyclicControlTab extends StatefulWidget {
  final String groupUUID;

  const GroupCyclicControlTab({
    super.key,
    required this.groupUUID,
  });

  @override
  State<GroupCyclicControlTab> createState() => _GroupCyclicControlTabState();
}

class _GroupCyclicControlTabState extends State<GroupCyclicControlTab> {
  final apiService = ApiService();

  List<dynamic>? rules;
  bool isLoading = true;
  String? error;

  static const _primaryColor = Color(0xFF7B4DBB);

  @override
  void initState() {
    super.initState();
    _fetchRules();
  }

  Future<void> _fetchRules() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        setState(() {
          error = '未登入或找不到 token';
          isLoading = false;
        });
        return;
      }

      final data = await apiService.fetchGroupCyclic(
        token,
        widget.groupUUID,
      );

      setState(() {
        rules = data ?? [];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = '載入循環排程失敗：$e';
        isLoading = false;
      });
    }
  }

  // ===============================
  // 新增 / 編輯 Dialog
  // ===============================
  Future<void> _addOrEditDialog({Map<String, dynamic>? rule}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('找不到 token')));
      return;
    }

    TimeOfDay start =
        _parseHms(rule?['start_time']) ?? const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay end =
        _parseHms(rule?['end_time']) ?? const TimeOfDay(hour: 20, minute: 0);

    final onCtrl =
        TextEditingController(text: rule?['on_minutes']?.toString() ?? '5');
    final offCtrl =
        TextEditingController(text: rule?['off_minutes']?.toString() ?? '10');

    bool enabled = rule?['enabled'] ?? true;

    final Set<String> allDays = const {
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    };

    final Set<String> days = {
      ...(rule?['weekdays']?.cast<String>() ??
          <String>{'monday', 'tuesday', 'wednesday', 'thursday', 'friday'}),
    };

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            String fmt(TimeOfDay t) =>
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

            return AlertDialog(
              title: Text(rule == null ? '新增循環排程' : '編輯循環排程'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 時間窗
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.schedule),
                              label: Text('開始：${fmt(start)}'),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: start,
                                );
                                if (picked != null) {
                                  setState(() => start = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.schedule_outlined),
                              label: Text('結束：${fmt(end)}'),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: end,
                                );
                                if (picked != null) {
                                  setState(() => end = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ON / OFF
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: onCtrl,
                              decoration: const InputDecoration(
                                labelText: 'ON（分鐘）',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: offCtrl,
                              decoration: const InputDecoration(
                                labelText: 'OFF（分鐘）',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        '重複星期',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: allDays.map((d) {
                          return FilterChip(
                            label: Text(_weekdayLabel(d)),
                            selected: days.contains(d),
                            onSelected: (v) {
                              setState(() {
                                v ? days.add(d) : days.remove(d);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      SwitchListTile(
                        value: enabled,
                        title: const Text('啟用'),
                        onChanged: (v) => setState(() => enabled = v),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final onM = int.tryParse(onCtrl.text) ?? 0;
                      final offM = int.tryParse(offCtrl.text) ?? 0;

                      if (onM <= 0 || offM <= 0) {
                        throw 'ON / OFF 分鐘必須 > 0';
                      }
                      if (days.isEmpty) {
                        throw '至少選擇一個星期';
                      }

                      final stMin = start.hour * 60 + start.minute;
                      final etMin = end.hour * 60 + end.minute;
                      if (!(stMin < etMin)) {
                        throw '開始時間需早於結束時間';
                      }

                      final res = await apiService.groupCyclicAdd(
                        token: token,
                        groupUUID: widget.groupUUID,
                        onMinutes: onM,
                        offMinutes: offM,
                        startTime: fmt(start),
                        endTime: fmt(end),
                        weekdays: days.toList(),
                        enabled: enabled,
                        ruleId: rule?['id'],
                      );

                      if (!mounted) return;
                      Navigator.pop(ctx);
                      await _fetchRules();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(res['message'] ?? '儲存成功')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('儲存失敗：$e')),
                      );
                    }
                  },
                  child: const Text('送出'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===============================
  // 刪除
  // ===============================
  Future<bool> _confirmDelete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確認刪除'),
        content: const Text('確定要刪除此循環排程嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok != true) return false;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return false;

    await apiService.groupCyclicDel(token: token, id: id);
    await _fetchRules();
    return true;
  }

  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    Widget body;

    if (isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (error != null) {
      body = Center(child: Text(error!, style: const TextStyle(color: Colors.red)));
    } else if (rules == null || rules!.isEmpty) {
      body = const Center(child: Text('尚未設定任何循環排程'));
    } else {
      body = ListView.builder(
        itemCount: rules!.length,
        itemBuilder: (context, index) {
          final r = rules![index];
          return Dismissible(
            key: ValueKey('group_cyclic_${r['id']}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              color: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (_) => _confirmDelete(r['id']),
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('${r['start_time']} ~ ${r['end_time']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ON ${r['on_minutes']} / OFF ${r['off_minutes']} 分'),
                    Text('星期：${_weekdayLine(r['weekdays'])}'),
                    Text(
                      '狀態：${r['current_state']}',
                      style: const TextStyle(color: Colors.blueGrey),
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.repeat),
                onTap: () => _addOrEditDialog(rule: r),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchRules,
        child: body is ListView
            ? body
            : ListView(children: [SizedBox(height: 400, child: body)]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('新增循環', style: TextStyle(color: Colors.white)),
        onPressed: () => _addOrEditDialog(),
      ),
    );
  }

  // ===============================
  // Helpers
  // ===============================
  TimeOfDay? _parseHms(String? s) {
    if (s == null) return null;
    final p = s.split(':');
    if (p.length < 2) return null;
    return TimeOfDay(
      hour: int.tryParse(p[0]) ?? 0,
      minute: int.tryParse(p[1]) ?? 0,
    );
  }

  static String _weekdayLabel(String key) {
    const map = {
      'monday': '週一',
      'tuesday': '週二',
      'wednesday': '週三',
      'thursday': '週四',
      'friday': '週五',
      'saturday': '週六',
      'sunday': '週日',
    };
    return map[key] ?? key;
  }

  static String _weekdayLine(List<dynamic>? days) {
    if (days == null || days.isEmpty) return '—';
    return days.map((d) => _weekdayLabel(d)).join('、');
  }
}
