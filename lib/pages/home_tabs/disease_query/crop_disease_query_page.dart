import 'package:flutter/material.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:chcg_iot_app/pages/home_tabs/disease_query/bug_list_page.dart';

class CropDiseaseQueryPage extends StatefulWidget {
  const CropDiseaseQueryPage({super.key});

  @override
  State<CropDiseaseQueryPage> createState() => _CropDiseaseQueryPageState();
}

class _CropDiseaseQueryPageState extends State<CropDiseaseQueryPage> {
  final _cropController = TextEditingController(text: '芭樂');
  final _bugController = TextEditingController(text: '炭疽病');

  final _diseaseApi = DiseaseApiService();

  bool _loadingFarms = false;
  bool _loadingBugs = false;

  List<dynamic> _farmList = [];
  Set<String> _selectedFarmIds = {};

  // ✅ 病蟲查詢回來的 items（用來給單選選單）
  List<dynamic> _bugList = [];
  bool _enableBugSearch = false;

  // ✅ 單選結果（顯示用 & 帶去下一頁）
  String? _selectedBugName; // 例如 "炭疽病"
  String? _selectedBugInstId; // 例如 "B30"（如果你想保留也可以）

  static const Color _primaryColor = Color(0xFF7B4DBB);

  @override
  void dispose() {
    _cropController.dispose();
    _bugController.dispose();
    super.dispose();
  }

  // 1) 查詢作物
  Future<void> _searchFarms() async {
    final keyword = _cropController.text.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入作物名稱關鍵字')),
      );
      return;
    }

    setState(() {
      _loadingFarms = true;
      _farmList = [];
      _selectedFarmIds.clear();
    });

    try {
      final res = await _diseaseApi.fetchFarms(farm: keyword);
      if (!mounted) return;

      setState(() {
        _farmList = res?['items'] ?? [];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('查詢作物代碼失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _loadingFarms = false);
    }
  }

  // 2) 查詢病蟲（彈出單選選單）
  Future<void> _searchBugsAndPickOne() async {
    if (!_enableBugSearch) return; // ✅ 沒開啟就不做事
    final keyword = _bugController.text.trim().isEmpty ? '' : _bugController.text.trim();

    setState(() {
      _loadingBugs = true;
      _bugList = [];
      // 不一定要清掉既有選擇，你想「重新查詢就清掉」也可以打開這兩行
      // _selectedBugName = null;
      // _selectedBugInstId = null;
    });

    try {
      final res = await _diseaseApi.fetchBugs(bug: keyword);
      if (!mounted) return;

      final items = (res?['items'] ?? []) as List<dynamic>;
      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('查無病蟲資料，請換個關鍵字')),
        );
        setState(() => _loadingBugs = false);
        return;
      }

      setState(() {
        _bugList = items;
      });

      // ✅ 跳出單選選單
      final picked = await _showBugSinglePickDialog(items);

      if (!mounted) return;
      if (picked == null) {
        // 使用者取消
        return;
      }

      final instn1 = (picked['instn1'] ?? '').toString();
      final instid = (picked['instid'] ?? '').toString();

      setState(() {
        _selectedBugName = instn1.isEmpty ? keyword : instn1;
        _selectedBugInstId = instid.isEmpty ? null : instid;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('查詢病蟲失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _loadingBugs = false);
    }
  }

  Future<Map<String, dynamic>?> _showBugSinglePickDialog(List<dynamic> items) async {
    // 把資料轉成 Map<String,dynamic>
    final list = items
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    // 預設選中：如果已經選過，就沿用；否則 null
    String? selectedInstId = _selectedBugInstId;

    return showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('請選擇病蟲（單選）'),
          content: SizedBox(
            width: double.maxFinite,
            child: StatefulBuilder(
              builder: (ctx2, setState2) {
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final m = list[index];
                    final instid = (m['instid'] ?? '').toString();
                    final instn1 = (m['instn1'] ?? '').toString();
                    final subtitle = [
                      if (instid.isNotEmpty) '代碼：$instid',
                    ].join('  ');

                    return RadioListTile<String>(
                      value: instid,
                      groupValue: selectedInstId,
                      onChanged: (v) => setState2(() => selectedInstId = v),
                      title: Text(instn1.isEmpty ? '(無名稱)' : instn1),
                      subtitle: subtitle.isEmpty ? null : Text(subtitle),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _primaryColor),
              onPressed: () {
                // 找到選中的那筆
                if (selectedInstId == null || selectedInstId!.isEmpty) {
                  // 沒選就不給過（你也可以允許不選）
                  Navigator.pop(ctx, null);
                  return;
                }
                final picked = list.firstWhere(
                  (x) => (x['instid'] ?? '').toString() == selectedInstId,
                  orElse: () => list.first,
                );
                Navigator.pop(ctx, picked);
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }

  // 3) 查詢病蟲清單（進下一頁）
  Future<void> _searchBugList() async {
  if (_selectedFarmIds.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('請先選擇至少一個作物代碼')),
    );
    return;
  }

  final farmParam = _selectedFarmIds.join(',');

  // ✅ Switch 關掉：bug 一律帶空字串 ''
  String bug = '';
  if (_enableBugSearch) {
    // ✅ Switch 開啟：優先用「選到的 instid」，沒選就用輸入框文字（允許空字串）
    if (_selectedBugInstId != null && _selectedBugInstId!.trim().isNotEmpty) {
      bug = _selectedBugInstId!.trim();
    } else {
      bug = _bugController.text.trim(); // 可能是 ''，OK
    }
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BugListPage(
        farmParam: farmParam,
        bug: bug,
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(
        title: const Text(
          '用藥查詢',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        centerTitle: true,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCropSearchSection(),
          const SizedBox(height: 16),
          _buildBugInputSection(),
          const SizedBox(height: 16),
          _buildFarmListSection(),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '資料來源：農業部動植物防疫檢疫署',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCropSearchSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.search, size: 20, color: _primaryColor),
                SizedBox(width: 6),
                Text(
                  '1. 查詢作物',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cropController,
                    decoration: InputDecoration(
                      labelText: '作物名稱關鍵字，例如：葡萄',
                      prefixIcon: const Icon(Icons.agriculture),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _loadingFarms ? null : _searchFarms,
                  child: _loadingFarms
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '查詢',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 2. 病蟲查詢（按查詢->跳出單選）
  Widget _buildBugInputSection() {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report, size: 20, color: _primaryColor),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '2. 查詢病蟲害關鍵字',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Switch(
                value: _enableBugSearch,
                onChanged: (v) {
                  setState(() {
                    _enableBugSearch = v;
                    if (!v) {
                      _selectedBugName = null;
                      _selectedBugInstId = null;
                      _bugList = [];
                      _loadingBugs = false;
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _enableBugSearch ? '已開啟：可查詢並單選病蟲' : '未開啟：將直接使用輸入的病蟲文字（可不查）',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),

          // ✅ 這裡改成 if/else 兩段，不要 return
          if (!_enableBugSearch) ...[
            TextField(
              controller: _bugController,
              decoration: InputDecoration(
                labelText: '病蟲文字（不查也可用），例如：炭疽病',
                prefixIcon: const Icon(Icons.medical_information_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '提示：若不查詢，下一步會直接用上面文字進入病蟲清單。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bugController,
                    decoration: InputDecoration(
                      labelText: '病蟲關鍵字，例如：炭疽病',
                      prefixIcon: const Icon(Icons.medical_information_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _loadingBugs ? null : _searchBugsAndPickOne,
                  child: _loadingBugs
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '查詢',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 18, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _selectedBugName == null
                        ? '尚未選擇病蟲（可直接按下一步，不一定要選）'
                        : '已選擇：$_selectedBugName'
                            '${_selectedBugInstId == null ? '' : '（${_selectedBugInstId}）'}',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
                // if (_selectedBugName != null)
                //   TextButton(
                //     onPressed: () {
                //       setState(() {
                //         _selectedBugName = null;
                //         _selectedBugInstId = null;
                //       });
                //     },
                //     child: const Text('清除'),
                //   ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

  Widget _buildFarmListSection() {
    if (_loadingFarms) return const SizedBox.shrink();
    if (_farmList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 4.0),
        child: Text(
          '尚未查詢或查無作物代碼。',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final selectedCount = _selectedFarmIds.length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.list_alt, size: 20, color: _primaryColor),
                SizedBox(width: 6),
                Text(
                  '3. 選擇作物（可複選）',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (selectedCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '已選擇 $selectedCount 筆作物',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ..._farmList.map((f) {
              final String farmid = (f['farmid'] ?? '').toString().trim();
              final String farmna = (f['farmna'] ?? '').toString();
              final String farmga = (f['farmga'] ?? '').toString();

              final bool selected = _selectedFarmIds.contains(farmid);

              return CheckboxListTile(
                value: selected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedFarmIds.add(farmid);
                    } else {
                      _selectedFarmIds.remove(farmid);
                    }
                  });
                },
                title: Text(farmna, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(farmid, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }).toList(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: _searchBugList,
                icon: const Icon(Icons.medication_outlined, size: 18),
                label: const Text('查詢病蟲清單', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
