import 'package:flutter/material.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// 單一病害詳細頁：
/// - fetchAzaiBugDetail (文字說明)
/// - fetchAzaiBugPics (圖片列表)
class AzaiBugDetailPage extends StatefulWidget {
  const AzaiBugDetailPage({
    super.key,
    required this.bugId,
    required this.title, // 中文名稱，從列表帶進來
  });

  final String bugId;
  final String title;

  @override
  State<AzaiBugDetailPage> createState() => _AzaiBugDetailPageState();
}

class _AzaiBugDetailPageState extends State<AzaiBugDetailPage> {
  final DiseaseApiService _api = DiseaseApiService();
  static const Color _primaryColor = Color(0xFF7B4DBB);

  late Future<_BugDetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BugDetailData> _load() async {
    const int maxRetry = 10;
    int attempt = 0;

    Map<String, dynamic>? detailRes;
    Map<String, dynamic>? picsRes;

    while (true) {
      attempt++;
      try {
        // 兩個 API 可以同時打
        final results = await Future.wait([
          _api.fetchAzaiBugDetail(bugId: widget.bugId),
          _api.fetchAzaiBugPics(bugId: widget.bugId),
        ]);

        detailRes = results[0] as Map<String, dynamic>?;
        picsRes = results[1] as Map<String, dynamic>?;

        // 成功就跳出迴圈
        break;
      } catch (e) {
        if (attempt >= maxRetry) {
          // 超過最大重試次數，丟錯給 FutureBuilder 顯示
          throw Exception('載入失敗（已重試 $attempt 次）：$e');
        }

        // 等一下再試，避免連續狂打
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    final detailList = (detailRes?['data'] as List?) ?? const [];
    final picsList = (picsRes?['data'] as List?) ?? const [];

    return _BugDetailData(details: detailList, pics: picsList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        centerTitle: true,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<_BugDetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '載入失敗：${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('沒有資料'));
          }

          final details = data.details;
          final pics = data.pics;

          // detail 只取第一筆（大部分情況就是 1 筆）
          final detail = details.isNotEmpty
              ? (details.first as Map<String, dynamic>? ?? {})
              : <String, dynamic>{};

          return SingleChildScrollView(
  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // 1. 圖片卡片
      _buildPicsCard(pics),

      const SizedBox(height: 12),

      // 2. 文字詳細卡片
      _buildDetailCard(detail),

      const SizedBox(height: 8),

      // 3. 資料來源 footer
      const Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            '資料來源：農業病蟲害智能管理決策系統',
            style: TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
        ),
      ),
    ],
  ),
);

        },
      ),
    );
  }

  /// 外層圖片卡片（包住輪播）
  Widget _buildPicsCard(List<dynamic> pics) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: 260,
        child: _buildPicsCarousel(pics),
      ),
    );
  }

  /// 圖片輪播 (利用 fetchAzaiBugPics 回來的 data)
  Widget _buildPicsCarousel(List<dynamic> pics) {
    if (pics.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('尚無圖片')),
      );
    }

    return PageView.builder(
      itemCount: pics.length,
      itemBuilder: (context, index) {
        final item = pics[index] as Map<String, dynamic>? ?? {};
        // 後端回來的 key 你可以依實際調整，例如 'pic', 'image_url'...
        final url =
            item['pic']?.toString() ?? item['image_url']?.toString() ?? '';

        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: url.isEmpty
                ? Container(
                    color: Colors.grey.shade300,
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 48,
                      ),
                    ),
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            size: 48,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  /// 文字詳細資訊卡片（使用 fetchAzaiBugDetail 的第一筆資料）
  Widget _buildDetailCard(Map<String, dynamic> detail) {
    // 依你 .NET 資料實際欄位來排順序
    const fieldOrder = <String>[
      'CName',
      'SName',
      'EClass5',
      'EName',
      'Harm',
      'HarmPart',
      'Property',
      'Life',
      'HarmDatail',
      'Control',
      'Med',
      'editor',
      'refer',
      'url',
    ];

    const fieldLabel = <String, String>{
      'CName': '中文名稱',
      'SName': '學名',
      'EClass5': '病害學名',
      'EName': '病害英名',
      'Harm': '病原寄主',
      'HarmPart': '病徵',
      'Property': '病原特徵',
      'Life': '發病生態',
      'HarmDatail': '病害環境',
      'Control': '防治方法',
      'Med': '藥劑防治',
      'editor': '作者',
      'refer': '參考來源',
      'url': '來源網址',
    };

    final widgets = <Widget>[];

    // 先處理抬頭：中文名稱 / 學名
    final cName = (detail['CName'] ?? '').toString().trim();
    final sName = (detail['SName'] ?? '').toString().trim();
    final type = (detail['Type'] ?? '').toString().trim();

    if (cName.isNotEmpty || sName.isNotEmpty || type.isNotEmpty) {
      widgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cName.isNotEmpty)
              Text(
                cName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (sName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                sName,
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.black87,
                ),
              ),
            ],
            if (type.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text(type),
                    backgroundColor: Colors.green.shade50,
                    labelStyle: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );

      widgets.add(const SizedBox(height: 16));
      widgets.add(const Divider(height: 1));
      widgets.add(const SizedBox(height: 8));
    }

    // 依序顯示其他欄位（CName / SName 已在上面處理，可以略過）
    for (final key in fieldOrder) {
      if (key == 'CName' || key == 'SName') continue;

      final raw = detail[key];
      if (raw == null) continue;
      final text = raw.toString().trim();
      if (text.isEmpty) continue;

      // 特例：如果是 URL → 改為可點擊的連結
      if (key == 'url') {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fieldLabel[key] ?? key,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () async {
                    final link = text;
                    try {
                      await launchUrl(
                        Uri.parse(link),
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('無法開啟網址')),
                      );
                    }
                  },
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // 一般欄位
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0, top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fieldLabel[key] ?? key,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widgets.isEmpty) {
      widgets.add(const Text('尚無詳細文字說明'));
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widgets,
        ),
      ),
    );
  }
}

/// 用來同時存放 detail / pics 兩個 API 的資料
class _BugDetailData {
  final List<dynamic> details;
  final List<dynamic> pics;

  _BugDetailData({
    required this.details,
    required this.pics,
  });
}


