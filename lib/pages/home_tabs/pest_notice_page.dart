import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:chcg_iot_app/core/api_service.dart';

class PestNoticePage extends StatefulWidget {
  const PestNoticePage({super.key});

  @override
  State<PestNoticePage> createState() => _PestNoticePageState();
}

class _PestNoticePageState extends State<PestNoticePage> {
  final apiService = ApiService();

  // 彰化縣 App 先前常用紫色
  final Color _primaryColor = const Color(0xFF7B4DBB);

  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = apiService.fetchpest_notice();
  }

  String _formatDate(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.length < 8) return s;
    try {
      final dt = DateTime.parse(
        '${s.substring(0, 4)}-${s.substring(4, 6)}-${s.substring(6, 8)}',
      );
      return DateFormat('yyyy/MM/dd').format(dt);
    } catch (_) {
      return s;
    }
  }

  String _s(dynamic v) => (v ?? '').toString();

  Widget _badge({
    required IconData icon,
    required String text,
    required Color color,
    required double textScale,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16 * textScale, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12 * textScale,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required String body,
    required double textScale,
  }) {
    if (body.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _primaryColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14 * textScale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body.trim(),
            style: TextStyle(
              fontSize: 14 * textScale,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScaleFactorOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F9),
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '農作物疫情公告',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
      ),
      
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded,
                        size: 42, color: Colors.black.withOpacity(0.45)),
                    const SizedBox(height: 10),
                    Text(
                      '資料載入失敗',
                      style: TextStyle(
                        fontSize: 16 * textScale,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13 * textScale,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryColor,
                      ),
                      onPressed: () => setState(() => _reload()),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('再試一次'),
                    ),
                  ],
                ),
              ),
            );
          }

          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Text(
                '目前沒有預警資料',
                style: TextStyle(fontSize: 15 * textScale),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            itemCount: list.length + 1, // + 來源字樣
            itemBuilder: (context, index) {
              if (index == list.length) {
                return const Padding(
                  padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '資料來源：農作物災害預警平台',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                );
              }

              final item = list[index];
              if (item is! Map) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('資料格式異常：$item'),
                  ),
                );
              }

              final subject = _s(item['主旨']).trim();
              final publishDate = _formatDate(item['發布日期']);
              final content = _s(item['預警內容']).trim();
              final suggestion = _s(item['防治建議']).trim();

              // 預設：第一則展開，其餘收合（更好掃）
              final initiallyExpanded = index == 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    initiallyExpanded: initiallyExpanded,
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _primaryColor.withOpacity(0.95),
                            _primaryColor.withOpacity(0.70),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.campaign_rounded,
                          color: Colors.white),
                    ),
                    title: Text(
                      subject.isEmpty ? '（無主旨）' : subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5 * textScale,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _badge(
                            icon: Icons.calendar_month_rounded,
                            text: publishDate,
                            color: _primaryColor,
                            textScale: textScale,
                          ),
                          _badge(
                            icon: Icons.location_on_rounded,
                            text: '彰化縣',
                            color: Colors.teal,
                            textScale: textScale,
                          ),
                        ],
                      ),
                    ),
                    children: [
                      _section(
                        icon: Icons.warning_amber_rounded,
                        title: '預警內容',
                        body: content,
                        textScale: textScale,
                      ),
                      const SizedBox(height: 12),
                      _section(
                        icon: Icons.volunteer_activism_rounded,
                        title: '防治建議',
                        body: suggestion,
                        textScale: textScale,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
