import 'package:flutter/material.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimeControlTab extends StatefulWidget {
  final String deviceUUID;
  final String featureEnglishName;
  final String serialId;

  const TimeControlTab({
    required this.deviceUUID,
    required this.featureEnglishName,
    required this.serialId,
  });

  @override
  State<TimeControlTab> createState() => TimeControlTabState();
}

class TimeControlTabState extends State<TimeControlTab> {
  final apiService = ApiService();
  List<dynamic>? scheduleList;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchSchedules();
  }

  String _formatWeekdays(List<dynamic>? weekdays) {
    if (weekdays == null || weekdays.isEmpty) return '無';
    final map = {
      "monday": "一",
      "tuesday": "二",
      "wednesday": "三",
      "thursday": "四",
      "friday": "五",
      "saturday": "六",
      "sunday": "日",
    };
    return weekdays.map((w) => '週${map[w.toLowerCase()] ?? w}').join('、');
  }

  Future<void> fetchSchedules() async {
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
        });
        return;
      }

      final data = await apiService.fetchschedule(
        token,
        widget.deviceUUID,
        widget.serialId,
      );

      setState(() {
        scheduleList = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = '載入排程失敗：$e';
        isLoading = false;
      });
    }
  }

  Future<void> _confirmDeleteSchedule(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("確認刪除"),
            content: const Text("確定要刪除這筆排程嗎？"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("取消"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("刪除", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw '無 token';

      final result = await apiService.scheduleDel(token: token, id: id);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result['message'] ?? '刪除成功')));

      fetchSchedules(); // 重新載入
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刪除失敗：$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> addScheduleDialog({Map<String, dynamic>? schedule}) async {
  final formKey = GlobalKey<FormState>();

  // 若未來要支援編輯：可把 schedule 的值帶入
  TimeOfDay selectedTime = const TimeOfDay(hour: 12, minute: 0);
  String action = 'ON';

  // 星期固定順序
  const weekdayOrder = <String>[
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
    "sunday",
  ];

  // 預設全 false
  final Map<String, bool> weekdays = {
    for (final d in weekdayOrder) d: false,
  };

  // 若要支援編輯（可先留著）
  if (schedule != null) {
    final t = (schedule["time"] ?? "").toString(); // "HH:mm"
    final parts = t.split(":");
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? selectedTime.hour;
      final m = int.tryParse(parts[1]) ?? selectedTime.minute;
      selectedTime = TimeOfDay(hour: h, minute: m);
    }

    action = (schedule["action"] ?? "ON").toString();
    final selectedDays = (schedule["weekdays"] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toSet();
    for (final d in selectedDays) {
      if (weekdays.containsKey(d)) weekdays[d] = true;
    }
  }

  String weekdayLabel(String key) {
    switch (key) {
      case "monday":
        return "週一";
      case "tuesday":
        return "週二";
      case "wednesday":
        return "週三";
      case "thursday":
        return "週四";
      case "friday":
        return "週五";
      case "saturday":
        return "週六";
      case "sunday":
        return "週日";
      default:
        return key;
    }
  }

  await showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(schedule == null ? '新增排程' : '編輯排程'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9, // ✅ 跟 CycleControlTab 一樣
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 時間
                      OutlinedButton.icon(
                        icon: const Icon(Icons.access_time),
                        label: Text('時間：${selectedTime.format(context)}'),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setState(() => selectedTime = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // 動作
                      DropdownButtonFormField<String>(
                        value: action,
                        items: const [
                          DropdownMenuItem(value: "ON", child: Text("開啟")),
                          DropdownMenuItem(value: "OFF", child: Text("關閉")),
                        ],
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => action = val);
                        },
                        decoration: const InputDecoration(
                          labelText: '控制動作',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 星期（中文顯示）
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '選擇星期',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ✅ 改成 Chip，畫面更像你 Cycle 的風格、也比較不佔高度
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: weekdayOrder.map((dayKey) {
                          final selected = weekdays[dayKey] == true;
                          return FilterChip(
                            label: Text(weekdayLabel(dayKey)),
                            selected: selected,
                            onSelected: (v) {
                              setState(() => weekdays[dayKey] = v);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final selectedDays = weekdayOrder
                      .where((d) => weekdays[d] == true)
                      .toList();

                  if (selectedDays.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('請至少選擇一個星期')),
                    );
                    return;
                  }

                  try {
                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString('token');
                    if (token == null) throw '無 token';

                    final formattedTime =
                        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

                    // ✅ 如果你未來要支援「編輯」，可把 schedule["id"] 帶進去你的 API
                    final result = await apiService.scheduleAdd(
                      token: token,
                      deviceUUID: widget.deviceUUID,
                      featureEnglishName: widget.featureEnglishName,
                      serialId: int.parse(widget.serialId),
                      action: action,
                      time: formattedTime,
                      weekdays: selectedDays, // ✅ 送英文 key
                    );

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result['message'] ?? '新增成功')),
                    );

                    Navigator.of(ctx).pop();
                    fetchSchedules();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('新增排程失敗：$e')),
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

  // 👉 新增：用於 Dismissible 的確認 + 刪除
  Future<bool> _onConfirmDismiss(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("確認刪除"),
            content: const Text("確定要刪除這筆排程嗎？"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("取消"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("刪除", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm != true) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw '無 token';

      final result = await apiService.scheduleDel(token: token, id: id);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result['message'] ?? '刪除成功')));
        // 重新載入列表，保持與伺服器一致
        await fetchSchedules();
      }
      return true; // ✅ 允許 Dismissible 真正移除
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刪除失敗：$e'), backgroundColor: Colors.red),
        );
      }
      return false; // ❌ 取消滑動刪除
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Text(error!, style: const TextStyle(color: Colors.red)),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: fetchSchedules,
        child:
            scheduleList == null || scheduleList!.isEmpty
                ? const Center(child: Text('尚未設定任何排程'))
                : ListView.builder(
                  itemCount: scheduleList!.length,
                  itemBuilder: (context, index) {
                    final schedule = scheduleList![index];
                    return Dismissible(
                      key: ValueKey('schedule_${schedule["id"]}'),
                      direction: DismissDirection.endToStart, // 右→左（左滑刪除）
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) => _onConfirmDismiss(schedule["id"]),
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Text(
                            '週期: ${_formatWeekdays(schedule["weekdays"])}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '時間: ${schedule["time"]} / 動作: ${schedule["action"]}',
                          ),
                          trailing: const Icon(Icons.rule),
                          // 🔻 不再需要長按刪除
                          // onLongPress: () => _confirmDeleteSchedule(schedule["id"]),
                        ),
                      ),
                    );
                  },
                ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addScheduleDialog,
        icon: const Icon(Icons.add,color: Colors.white),
        label: const Text('新增排程',style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF7B4DBB),
      ),
    );
  }
}
