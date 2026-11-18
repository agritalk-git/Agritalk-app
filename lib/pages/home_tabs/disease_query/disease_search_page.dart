import 'package:flutter/material.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:chcg_iot_app/pages/home_tabs/disease_query/disease_bug_detail_page.dart';

class DiseaseSearchPage extends StatefulWidget {
  const DiseaseSearchPage({super.key});

  @override
  State<DiseaseSearchPage> createState() => _DiseaseSearchPageState();
}

class _DiseaseSearchPageState extends State<DiseaseSearchPage> {
  final DiseaseAzaiApiService _api = DiseaseAzaiApiService();
  final TextEditingController _searchController =
      TextEditingController(text: '芭樂');

  bool _loading = false;
  List<Map<String, dynamic>> _results = [];

  static const Color _primaryColor = Color(0xFF7B4DBB);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _doSearch() async {
    final term = _searchController.text.trim();
    if (term.isEmpty || _loading) return;

    setState(() => _loading = true);

    try {
      final res = await _api.searchAzaiBugs(term: term);
      if (!mounted) return;

      final data = res?['data'];
      setState(() {
        _results =
            data is List ? data.whereType<Map<String, dynamic>>().toList() : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('搜尋失敗：$e')));
    }
  }

  /// 單一病害卡片樣式（左圖右文）
  Widget _buildDiseaseCard(Map<String, dynamic> item) {
    final cName = item['CName']?.toString() ?? '未命名病害';
    final sName = item['SName']?.toString() ?? '';

    // 類別標籤（粉類、真菌、細菌…）
    final typeLabel = item['Peculiarity']?.toString() ?? '';

    // 危害徵狀
    final host = item['Harm']?.toString() ?? '';

    // 危害作物 / 防治對象
    final harm = item['HarmDatail']?.toString() ?? '';

    // 圖片網址
    final picUrl = item['pic']?.toString() ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左側圖片
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: picUrl.isNotEmpty
                  ? Image.network(
                      picUrl,
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 110,
                          height: 110,
                          color: Colors.grey.shade300,
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 36,
                            color: Colors.grey,
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 110,
                      height: 110,
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.bug_report,
                        size: 36,
                        color: Colors.grey,
                      ),
                    ),
            ),

            const SizedBox(width: 12),

            // 右側文字
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 標題 + 類別標籤
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          cName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (typeLabel.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            typeLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),

                  if (sName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      sName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ],

                  const SizedBox(height: 6),

                  // 危害作物/防治對象
                  RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: '危害作物 / 防治對象：',
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: host,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // 危害徵狀
                  RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: '危害徵狀：',
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: harm,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.search, size: 20, color: _primaryColor),
                SizedBox(width: 6),
                Text(
                  '病害關鍵字查詢',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: '作物 / 關鍵字',
                      hintText: '例如：火龍果、葡萄、番石榴…',
                      prefixIcon: const Icon(Icons.local_florist),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      isDense: true,
                      filled: true,
                    ),
                    onSubmitted: (_) => _doSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _loading ? null : _doSearch,
                  child: _loading
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
                          '搜尋',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultHeader() {
    if (_loading) {
      return const SizedBox.shrink();
    }

    if (_results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text(
          '尚未搜尋或查無資料。',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '共 ${_results.length} 筆結果',
              style: const TextStyle(
                fontSize: 12,
                color: _primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '點擊卡片可查看詳細資訊與圖片。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(
        title: const Text(
          '病蟲害查詢',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        centerTitle: true,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchSection(),
          _buildResultHeader(),
          const SizedBox(height: 4),
          Expanded(
  child: _loading
      ? const Center(child: CircularProgressIndicator())
      : _results.isEmpty
          ? const SizedBox.shrink()
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: _results.length + 1, // 多一個 footer
              itemBuilder: (context, index) {
                // --- Footer：資料來源 ---
                if (index == _results.length) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '資料來源：農業病蟲害智能管理決策系統',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  );
                }

                // --- 正常卡片項目 ---
                final item = _results[index];
                final bugId = item['id']?.toString() ?? '';
                final cName = item['CName']?.toString() ?? '病害詳細';

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (bugId.isEmpty) return;

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AzaiBugDetailPage(
                          bugId: bugId,
                          title: cName,
                        ),
                      ),
                    );
                  },
                  child: _buildDiseaseCard(item),
                );
              },
            ),
)

        ],
      ),
    );
  }
}
