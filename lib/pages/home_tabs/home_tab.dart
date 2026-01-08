import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chcg_iot_app/pages/home_tabs/guava_page/guava_page.dart';
import 'package:chcg_iot_app/pages/home_tabs/grape_page/grape_page.dart';
import 'package:chcg_iot_app/pages/home_tabs/disease_ai/main.dart';
import 'package:chcg_iot_app/pages/home_tabs/NewsDetailPage.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:chcg_iot_app/pages/home_tabs/disease_query/crop_disease_query_page.dart';
import 'package:chcg_iot_app/pages/home_tabs/disease_query/disease_search_page.dart';
import 'package:chcg_iot_app/pages/home_tabs/amis_price_page.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _EntryTile extends StatelessWidget {
  final String title;
  final String image;
  final VoidCallback onTap;

  const _EntryTile({
    required this.title,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            // ✅ 圖片自適應，不寫死高度
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(image, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            // maxLines: 2,
            // overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _HomeTabState extends State<HomeTab> {
  final apiService = ApiService();

  final Color _primaryColor = const Color(0xFF7B4DBB);

  List<dynamic> newsCarouselList = [];
  List<dynamic> newsCenterList = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchNewsData();
  }

  Future<void> fetchNewsData() async {
    try {
      final data = await apiService.fetchNews();

      if (mounted && data != null) {
        setState(() {
          newsCarouselList = data['latest_news_carousel'] ?? [];
          newsCenterList = data['latest_news_center'] ?? [];
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          newsCarouselList = [];
          newsCenterList = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '智慧農業資源平台',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          _buildSectionTitle("熱門資源入口"),
          const SizedBox(height: 8),
          _buildEntrySliderAdaptive(),

          const SizedBox(height: 24),
          _buildSectionTitle("近期焦點消息"),
          const SizedBox(height: 8),
          _buildNewsSliderAdaptive(),

          const SizedBox(height: 24),
          _buildSectionTitle("訊息中心"),
          const SizedBox(height: 8),
          _buildRankListAdaptive(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEntrySliderAdaptive() {
    final entries = [
      {
        'title': '彰化縣政府',
        'subtitle': '地方政府平台',
        'image': 'assets/homepage/changhua.png',
        'url': 'https://www.chcg.gov.tw/ch2/index.aspx',
      },
      {
        'title': '芭樂雲',
        'subtitle': '進入芭樂雲平台',
        'image': 'assets/homepage/guava.jpg',
        'url': null,
      },
      {
        'title': '葡萄雲',
        'subtitle': '進入葡萄雲平台',
        'image': 'assets/homepage/grape.jpg',
        'url': null,
      },
      {
        'title': '用藥查詢',
        'subtitle': '用藥查詢',
        'image': 'assets/homepage/258507_0.jpg', // 你可以換成自己有的圖片
        'url': null,
      },
      {
        'title': '病蟲害查詢',
        'subtitle': '病蟲害查詢',
        'image': 'assets/homepage/258470_0.jpg', // 你可以換成自己有的圖片
        'url': null,
      },
      {
        'title': '農產品行情',
        'subtitle': '即時批發市場價格',
        'image': 'assets/homepage/258508_0.jpg', // 你可以換成任意已有圖片
        'url': null,
      },
      // {
      //   'title': '白粉病檢測',
      //   'subtitle': '進入白粉病檢測平台',
      //   'image': 'assets/homepage/detection.png',
      //   'url': null,
      // },
      // {
      //   'title': '防檢署藥劑',
      //   'subtitle': '查看藥劑資料',
      //   'image': 'assets/homepage/drug.png',
      //   'url': 'https://www.aphia.gov.tw/',
      // },
      // {
      //   'title': '農糧署',
      //   'subtitle': '農糧署服務',
      //   'image': 'assets/homepage/agriculture.jpg',
      //   'url': 'https://www.afa.gov.tw/cht/index.php?code=list&ids=556',
      // },

      // {
      //   'title': '農譯科技',
      //   'subtitle': '進入農譯科技',
      //   'image': 'assets/homepage/agritalk.png',
      //   'url': 'https://www.agritalk.com.tw/',
      // },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        // ✅ 自適應：根據寬度決定一行放幾個
        int crossAxisCount = 3;
        if (w >= 420) crossAxisCount = 4;
        if (w >= 600) crossAxisCount = 5;

        final itemWidth = (w - (12 * (crossAxisCount - 1))) / crossAxisCount;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children:
              entries.map((e) {
                return SizedBox(
                  width: itemWidth,
                  child: _EntryTile(
                    title: e['title'].toString(),
                    image: e['image'].toString(),
                    onTap: () async {
              if (e['url'] != null) {
                await launchUrl(
                  Uri.parse(e['url'].toString()),
                  mode: LaunchMode.externalApplication,
                );
              } else {
                if (e['title'] == '芭樂雲') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GuavaPage()),
                  );
                } else if (e['title'] == '葡萄雲') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GrapePage()),
                  );
                } else if (e['title'] == '白粉病檢測') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DiseaseAIMainPage()),
                  );
                }else if (e['title'] == '用藥查詢') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CropDiseaseQueryPage(),
                    ),
                  );
                }else if (e['title'] == '病蟲害查詢') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DiseaseSearchPage(),
                    ),
                  );
                }else if (e['title'] == '農產品行情') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AgriMarketPage(),
                    ),
                  );
                }
              }
            },
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  Widget _buildNewsSliderAdaptive() {
    if (newsCarouselList.isEmpty) {
      return const Text('目前沒有新聞資料', style: TextStyle(color: Colors.grey));
    }

    return Column(
      children:
          newsCarouselList.take(5).map((item) {
            final imageUrl = item['image'] ?? '';
            final title = (item['title'] ?? '').toString().replaceFirst(
              '標題：',
              '',
            );
            final date = (item['date'] ?? '').toString().replaceFirst(
              '發佈日期：',
              '',
            );
            final link = item['link'] ?? '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  if (link.isNotEmpty && await canLaunchUrl(Uri.parse(link))) {
                    await launchUrl(
                      Uri.parse(link),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (imageUrl.isNotEmpty)
                        AspectRatio(
                          aspectRatio: 16 / 9, // ✅ 自適應圖片高度
                          child: Image.network(imageUrl, fit: BoxFit.cover),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              // maxLines: 3, // ✅ 大字體可換行
                              // overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.event,
                                      size: 16,
                                      color: Colors.black45,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      date,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '焦點',
                                    style: TextStyle(color: _primaryColor),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildNewsCard({
    required String image,
    required String title,
    required String subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.asset(
              image,
              height: 120, // ✅ 控制圖片不要過高
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  // maxLines: 1,
                  // overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  // maxLines: 2,
                  // overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankListAdaptive() {
    if (newsCenterList.isEmpty) {
      return Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: const Text('目前沒有訊息中心資料', style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children:
          newsCenterList.map((item) {
            final String title = (item['title'] ?? '').replaceFirst('標題：', '');
            final String date = (item['date'] ?? '').replaceFirst('發佈日期：', '');
            final String link = item['link'] ?? '';
            final String tag = (item['tag'] ?? '').replaceFirst('分顃：', '');

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  if (link.isNotEmpty && await canLaunchUrl(Uri.parse(link))) {
                    await launchUrl(
                      Uri.parse(link),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 左側 icon
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.article,
                          color: _primaryColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 中間文字
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              // maxLines: 2,
                              // overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
  spacing: 8,
  runSpacing: 6,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.event, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          date,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    ),
    if (tag.isNotEmpty)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          tag,
          style: TextStyle(color: _primaryColor),
        ),
      ),
  ],
),
],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.open_in_new,
                        color: Colors.grey,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}
