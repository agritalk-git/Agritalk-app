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
  final _diseaseApi = DiseaseApiService();

  bool _loadingFarms = false;

  List<dynamic> _farmList = []; // GetFarm 回來的 items
  Set<String> _selectedFarmIds = {}; // 使用者勾選的 farmid

  static const Color _primaryColor = Color(0xFF7B4DBB);

  @override
  void dispose() {
    _cropController.dispose();
    super.dispose();
  }

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
      if (mounted) {
        setState(() {
          _loadingFarms = false;
        });
      }
    }
  }

  Future<void> _searchBugList() async {
    if (_selectedFarmIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先選擇至少一個作物代碼')),
      );
      return;
    }

    final farmParam = _selectedFarmIds.join(',');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BugListPage(
          farmParam: farmParam,
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
    _buildFarmListSection(),
    const SizedBox(height: 24),

    // ⭐ 新增：資料來源備註
    Align(
      alignment: Alignment.centerRight,
      child: Text(
        '資料來源：農業部動植物防疫檢疫署',
        style: TextStyle(
          fontSize: 11,
          color: Colors.black54,
        ),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '查詢',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white,),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmListSection() {
    if (_loadingFarms) {
      return const SizedBox.shrink();
    }
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
                  '2. 選擇作物（可複選）',
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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
                title: Text(
                  farmna,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  farmga,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: _searchBugList,
                icon: const Icon(Icons.medication_outlined, size: 18),
                label: const Text(
                  '查詢病蟲清單',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
