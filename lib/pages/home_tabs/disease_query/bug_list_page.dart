import 'package:flutter/material.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:chcg_iot_app/pages/home_tabs/disease_query/bug_usage_detail_page.dart';

class BugListPage extends StatefulWidget {
  const BugListPage({
    super.key,
    required this.farmParam,
    required this.bug,
  });

  /// 例： "101,102,103"
  final String farmParam;
  final String bug;

  @override
  State<BugListPage> createState() => _BugListPageState();
}

class _BugListPageState extends State<BugListPage> {
  final DiseaseApiService _api = DiseaseApiService();

  bool _loading = false;
  String? _error;
  List<dynamic> _items = [];

  static const Color _primaryColor = Color(0xFF7B4DBB);

  @override
  void initState() {
    super.initState();
    _loadBugList();
  }

  Future<void> _loadBugList() async {
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
    });

    try {
      final res = await _api.fetchBugFarmList(farm: widget.farmParam, bug:widget.bug);
      final items = (res?['items'] ?? []) as List<dynamic>;

      if (!mounted) return;

      setState(() {
        _items = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '查詢病蟲清單失敗：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _openBugUsageDetail(Map<String, dynamic> item) {
    final farmCode = item['farm_code']?.toString();
    final bugCode = item['bug_code']?.toString();
    final cropName = item['crop_name']?.toString() ?? '';
    final bugName = item['bug_name']?.toString() ?? '';

    if (farmCode == null || bugCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此筆資料缺少 farm_code 或 bug_code')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BugUsageDetailPage(
          farmCode: farmCode,
          bugCode: bugCode,
          cropName: cropName,
          bugName: bugName,
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
          '病蟲清單',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        centerTitle: true,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: Colors.red.shade400),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: _loadBugList,
                icon: const Icon(Icons.refresh),
                label: const Text('重新整理'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Text(
          '查無病蟲清單資料。',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
  onRefresh: _loadBugList,
  child: ListView.builder(
    padding: const EdgeInsets.all(16),
    // 原本是 _items.length + 1，改成多一個 footer，所以 +2
    itemCount: _items.length + 2,
    itemBuilder: (context, index) {
      // 0：頂部資訊區塊
      if (index == 0) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '共找到 ${_items.length} 筆病蟲資料',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '點擊某一筆可查看該病蟲的用藥建議。',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
        );
      }

      // 最後一筆：資料來源備註 footer
      if (index == _items.length + 1) {
        return const Padding(
          padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '資料來源：農業部動植物防疫檢疫署',
              style: TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
          ),
        );
      }

      // 其他：病蟲卡片
      final item = _items[index - 1] as Map<String, dynamic>? ?? {};
      final String cropName = (item['crop_name'] ?? '').toString();
      final String bugName = (item['bug_name'] ?? '').toString();

      return Card(
        elevation: 2,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openBugUsageDetail(item),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _primaryColor.withOpacity(0.08),
                  child: const Icon(
                    Icons.bug_report,
                    color: _primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bugName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '作物：$cropName',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.black38,
                ),
              ],
            ),
          ),
        ),
      );
    },
  ),
);
}
}
