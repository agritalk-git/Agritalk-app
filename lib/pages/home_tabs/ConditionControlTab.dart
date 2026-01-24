import 'package:flutter/material.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConditionControlTab extends StatefulWidget {
  final String deviceUUID;
  final String featureEnglishName;
  final String serialId;

  const ConditionControlTab({
    super.key,
    required this.deviceUUID,
    required this.featureEnglishName,
    required this.serialId,
  });

  @override
  State<ConditionControlTab> createState() => _ConditionControlTabState();
}

class _ConditionControlTabState extends State<ConditionControlTab> {
  final apiService = ApiService();
  List<dynamic>? conditionList;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchConditions();
  }

  Future<void> fetchConditions() async {
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

      final data = await apiService.fetchCondition(
        token,
        widget.deviceUUID,
        widget.serialId,
      );

      setState(() {
        conditionList = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = '載入條件排程失敗：$e';
        isLoading = false;
      });
    }
  }

  Future<void> addConditionDialog() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  if (token == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('找不到 token')),
    );
    return;
  }

  final targets = await apiService.fetchTargets(token) ?? [];

  // --- 整體欄位 ---
  String action = 'ON';
  final durationCtrl = TextEditingController();

  // --- 每一條 AND 條件的模型 ---
  final List<Map<String, dynamic>> rows = [];

  void addRow() {
    rows.add({
      'targetUUID': null, // String?
      'device': null, // Map?
      'devices': <dynamic>[],
      'features': <dynamic>[],
      'feature': null, // Map?
      'operator': '>',
      'valueCtrl': TextEditingController(),
    });
  }

  void removeRow(int i) {
    final c = rows[i]['valueCtrl'] as TextEditingController?;
    c?.dispose();
    rows.removeAt(i);
  }

  addRow();

  Future<void> loadDevicesForRow(
    void Function(void Function()) setState,
    int index,
    String targetUUID,
  ) async {
    final devices = await apiService.fetchDevices(token, targetUUID) ?? [];
    setState(() {
      rows[index]['devices'] = devices;
      rows[index]['device'] = null;
      rows[index]['features'] = <dynamic>[];
      rows[index]['feature'] = null;
    });
  }

  void loadFeaturesForRow(
    void Function(void Function()) setState,
    int index,
    Map<String, dynamic> device,
  ) {
    // 你原本用 device['deviceFeature']，但你其他頁面常用 observationlatest/deviceFeature
    // 這邊保留你的寫法；若你的 API 實際是 observationlatest，改成 device['observationlatest'] 即可。
    final obs = (device['deviceFeature'] as List?) ?? [];
    setState(() {
      rows[index]['features'] = obs;
      rows[index]['feature'] = null;
    });
  }

  String featureLabel(Map<String, dynamic> f) {
    final dn = (f['deviceFeatureName'] ?? '').toString();
    final alias = (f['alias'] ?? '').toString();
    final name = dn.isNotEmpty ? dn : (alias.isNotEmpty ? alias : '未知項目');
    final sid = (f['serialId'] ?? '無').toString();
    return '$name（編號: $sid）';
  }

  const operators = ['>', '<', '>=', '<=', '=='];

  await showDialog(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (context, setState) {
          Widget sectionTitle(String text) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              );

          Widget fieldGap() => const SizedBox(height: 12);

          return AlertDialog(
            title: const Text('新增條件規則'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9, // ✅ 尺寸統一
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // ====== 區塊：動作與回復時間 ======
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
                          children: [
                            sectionTitle('觸發後要做什麼'),
                            fieldGap(),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: action,
                                    decoration: const InputDecoration(
                                      labelText: '執行動作',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'ON', child: Text('ON')),
                                      DropdownMenuItem(value: 'OFF', child: Text('OFF')),
                                    ],
                                    onChanged: (v) => setState(() => action = v ?? 'ON'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: durationCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: '回復時間（秒）',
                                      hintText: '可留空',
                                      helperText: 'ON→N秒後OFF；OFF→N秒後ON',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ====== 區塊：條件列表 ======
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'AND 條件（全部成立才觸發）',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    ...rows.asMap().entries.map((entry) {
                      final index = entry.key;
                      final row = entry.value;

                      final selectedTargetUUID = row['targetUUID'] as String?;
                      final devices = row['devices'] as List<dynamic>;
                      final device = row['device'] as Map<String, dynamic>?;
                      final features = row['features'] as List<dynamic>;
                      final feature = row['feature'] as Map<String, dynamic>?;
                      final op = (row['operator'] ?? '>').toString();
                      final valueCtrl = row['valueCtrl'] as TextEditingController;

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '條件 ${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (rows.length > 1)
                                    IconButton(
                                      tooltip: '移除條件',
                                      onPressed: () => setState(() => removeRow(index)),
                                      icon: const Icon(Icons.close, color: Colors.red),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Target
                              DropdownButtonFormField<String>(
                                value: selectedTargetUUID,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: '目標（Target）',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: targets.map<DropdownMenuItem<String>>((t) {
                                  return DropdownMenuItem<String>(
                                    value: (t['targetUUID'] ?? '').toString(),
                                    child: Text((t['area'] ?? '未命名').toString()),
                                  );
                                }).toList(),
                                onChanged: (v) async {
                                  setState(() => row['targetUUID'] = v);
                                  if (v != null && v.isNotEmpty) {
                                    await loadDevicesForRow(setState, index, v);
                                  }
                                },
                              ),

                              const SizedBox(height: 10),

                              // Device
                              DropdownButtonFormField<Map<String, dynamic>>(
                                value: device,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: '裝置（Device）',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: devices.map<DropdownMenuItem<Map<String, dynamic>>>((d) {
                                  return DropdownMenuItem<Map<String, dynamic>>(
                                    value: d,
                                    child: Text((d['name'] ?? '未知裝置').toString()),
                                  );
                                }).toList(),
                                onChanged: (d) {
                                  setState(() => row['device'] = d);
                                  if (d != null) loadFeaturesForRow(setState, index, d);
                                },
                              ),

                              const SizedBox(height: 10),

                              // Feature
                              DropdownButtonFormField<Map<String, dynamic>>(
                                value: feature,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: '感測項目（Feature）',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: features.map<DropdownMenuItem<Map<String, dynamic>>>((f) {
                                  return DropdownMenuItem<Map<String, dynamic>>(
                                    value: f,
                                    child: Text(featureLabel(f)),
                                  );
                                }).toList(),
                                onChanged: (f) => setState(() => row['feature'] = f),
                              ),

                              const SizedBox(height: 12),

                              // Operator Chips
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '比較子',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: operators.map((o) {
                                  final selected = op == o;
                                  return ChoiceChip(
                                    label: Text(o),
                                    selected: selected,
                                    onSelected: (_) => setState(() => row['operator'] = o),
                                  );
                                }).toList(),
                              ),

                              const SizedBox(height: 12),

                              // Value
                              TextFormField(
                                controller: valueCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '數值',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('＋ AND 條件'),
                        onPressed: () => setState(() => addRow()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // dispose controllers
                  for (final r in rows) {
                    (r['valueCtrl'] as TextEditingController?)?.dispose();
                  }
                  durationCtrl.dispose();
                  Navigator.pop(dialogCtx);
                },
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    // 1) 準備條件
                    final prepared = <Map<String, dynamic>>[];

                    for (final r in rows) {
                      final dev = r['device'] as Map<String, dynamic>?;
                      final feat = r['feature'] as Map<String, dynamic>?;
                      final op = (r['operator'] ?? '>').toString();
                      final vtxt =
                          (r['valueCtrl'] as TextEditingController).text.trim();

                      if (dev == null || feat == null || vtxt.isEmpty) continue;

                      prepared.add({
                        "deviceUUID": dev['deviceUUID'],
                        "sensor": feat['name'] ?? '', // 你原本的欄位
                        "serialId": feat['serialId'],
                        "operator": op,
                        "value": num.tryParse(vtxt) ?? 0,
                      });
                    }

                    if (prepared.isEmpty) {
                      throw '請至少填寫一個完整的條件（目標/裝置/項目/比較子/數值）';
                    }

                    // 2) durationSeconds 驗證（可空，若填必須 >0）
                    final dTxt = durationCtrl.text.trim();
                    int? durationSeconds;
                    if (dTxt.isNotEmpty) {
                      durationSeconds = int.tryParse(dTxt);
                      if (durationSeconds == null || durationSeconds <= 0) {
                        throw '回復時間必須是正整數秒（或留空）';
                      }
                    }

                    final result = await apiService.conditionAdd(
                      token: token,
                      deviceUUID: widget.deviceUUID,
                      serialId: int.parse(widget.serialId),
                      action: action,
                      conditions: prepared,
                      durationSeconds: durationSeconds,
                    );

                    if (!mounted) return;

                    // dispose controllers
                    for (final r in rows) {
                      (r['valueCtrl'] as TextEditingController?)?.dispose();
                    }
                    durationCtrl.dispose();

                    Navigator.pop(dialogCtx);
                    await fetchConditions();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result["message"] ?? "新增成功")),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("新增失敗：$e")),
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

  Future<bool> _onConfirmDismissCondition(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('確認刪除'),
            content: const Text('你確定要刪除此條件規則嗎？'),
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

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw '找不到 token';

      final res = await apiService.conditionDel(token: token, id: id);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(res['message'] ?? '刪除成功')));
        await fetchConditions(); // 與後端同步
      }
      return true; // 允許滑掉
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刪除失敗：$e'), backgroundColor: Colors.red),
        );
      }
      return false; // 取消滑掉
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (error != null) {
      body = Center(
        child: Text(error!, style: const TextStyle(color: Colors.red)),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: fetchConditions,
        child:
            conditionList == null || conditionList!.isEmpty
                ? ListView(
                  children: [
                    SizedBox(
                      height: 400,
                      child: Center(child: Text('尚未設定任何條件排程')),
                    ),
                  ],
                )
                : ListView.builder(
                  itemCount: conditionList!.length,
                  itemBuilder: (context, index) {
                    final rule = conditionList![index];

                    // ⭐ 顯示 duration_seconds（後端請於 list API 回傳此欄位）
                    final ds = rule['duration_seconds'];

                    return Dismissible(
                      key: ValueKey('condition_${rule["id"]}'), // 確保唯一
                      direction: DismissDirection.endToStart, // 右→左（左滑刪除）
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss:
                          (_) => _onConfirmDismissCondition(rule['id'] as int),
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Text(
                            "執行動作: ${rule["action"] ?? "未指定"}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (rule['duration_seconds'] != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'duration: ${rule['duration_seconds']}s（觸發後自動切換相反狀態）',
                                  style: const TextStyle(
                                    color: Colors.blueGrey,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              ...(rule["conditions"] as List<dynamic>? ??
                                      const [])
                                  .map((cond) {
                                    final device = cond["deviceName"] ?? "未知裝置";
                                    final feature =
                                        cond["featureName"] ?? "未知項目";
                                    final operator = cond["operator"] ?? "?";
                                    final value =
                                        cond["value"]?.toString() ?? "?";
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2.0,
                                      ),
                                      child: Text(
                                        "‧ [$device] $feature $operator $value",
                                      ),
                                    );
                                  })
                                  .toList(),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.rule),
                          onTap: () {
                            // TODO: 點擊查看或編輯
                          },
                          // onLongPress: ...  // ← 不再需要長按刪除
                        ),
                      ),
                    );
                  },
                ),
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addConditionDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('新增規則', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF7B4DBB),
      ),
    );
  }
}
