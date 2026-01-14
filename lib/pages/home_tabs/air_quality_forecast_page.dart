import 'package:flutter/material.dart';
import 'package:chcg_iot_app/core/api_service.dart';

class AirQualityForecastPage extends StatefulWidget {
  const AirQualityForecastPage({super.key});

  @override
  State<AirQualityForecastPage> createState() => _AirQualityForecastPageState();
}

class _AirQualityForecastPageState extends State<AirQualityForecastPage> {
  final apiService = ApiService();

  // 跟 HomeTab 一致
  final Color _primaryColor = const Color(0xFF7B4DBB);

  bool loading = true;
  Map<String, dynamic>? data;
  bool _contentExpanded = false;

  // ===== 新增：彰化站小時值（aqx_p_221） =====
  bool _loadingAqx = true;
  List<dynamic> _aqxRows = const [];
  String? _aqxError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      _loadingAqx = true;
      _aqxError = null;
    });

    try {
      // 你原本預報
      final res = await apiService.fetchAqfCentral();

      // 新增：彰化站小時值（不影響主資料顯示，並行失敗也不讓整頁掛掉）
      List<dynamic> rows = const [];
      String? aqxErr;
      try {
        rows = await apiService.fetchAqxP221Changhua();
      } catch (e) {
        aqxErr = e.toString();
      }

      if (!mounted) return;
      setState(() {
        data = res;
        loading = false;

        _aqxRows = rows;
        _aqxError = aqxErr;
        _loadingAqx = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        data = null;
        loading = false;

        _aqxRows = const [];
        _aqxError = e.toString();
        _loadingAqx = false;
      });
    }
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s) ?? int.tryParse(double.tryParse(s)?.toInt().toString() ?? '');
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  _AqiInfo _aqiInfo(int? aqi) {
    // 常見 AQI 分級
    if (aqi == null) {
      return const _AqiInfo(
        level: '—',
        meaning: '無資料',
        advice: '目前無法取得 AQI，請稍後再試。',
        color: Color(0xFF9E9E9E),
      );
    }
    if (aqi <= 50) {
      return const _AqiInfo(
        level: '良好',
        meaning: '空氣品質良好',
        advice: '適合戶外活動。',
        color: Color(0xFF2E7D32), // 綠
      );
    }
    if (aqi <= 100) {
      return const _AqiInfo(
        level: '普通',
        meaning: '可接受',
        advice: '一般人可正常活動；敏感族群若不適可減少戶外時間。',
        color: Color(0xFFF9A825), // 黃
      );
    }
    if (aqi <= 150) {
      return const _AqiInfo(
        level: '橘色提醒',
        meaning: '對敏感族群不健康',
        advice: '孩童、長者、心肺疾病者建議減少戶外活動並配戴口罩。',
        color: Color(0xFFEF6C00), // 橘
      );
    }
    if (aqi <= 200) {
      return const _AqiInfo(
        level: '紅色警示',
        meaning: '對所有族群不健康',
        advice: '建議減少戶外活動，外出配戴口罩；敏感族群盡量留在室內。',
        color: Color(0xFFC62828), // 紅
      );
    }
    if (aqi <= 300) {
      return const _AqiInfo(
        level: '紫色警報',
        meaning: '非常不健康',
        advice: '避免戶外活動；必要外出務必配戴口罩，並縮短外出時間。',
        color: Color(0xFF6A1B9A), // 紫
      );
    }
    return const _AqiInfo(
      level: '褐紅危害',
      meaning: '危害等級',
      advice: '請盡量留在室內，避免戶外活動，必要外出請加強防護。',
      color: Color(0xFF5D4037), // 褐
    );
  }

  // ===== 新增：以 PM2.5 做一個「即時提醒」色帶（給農民一眼看懂） =====
  _PmAdvice _pm25Advice(double? pm25) {
    if (pm25 == null) {
      return const _PmAdvice(
        title: '即時提醒',
        subtitle: '目前沒有 PM2.5 資料',
        color: Color(0xFF9E9E9E),
        icon: Icons.info_outline,
      );
    }
    if (pm25 <= 15) {
      return const _PmAdvice(
        title: '即時提醒：空氣偏好',
        subtitle: 'PM2.5 偏低，適合戶外工作',
        color: Color(0xFF2E7D32),
        icon: Icons.park,
      );
    }
    if (pm25 <= 35) {
      return const _PmAdvice(
        title: '即時提醒：注意',
        subtitle: 'PM2.5 稍高，敏感族群可減少久留戶外',
        color: Color(0xFFF9A825),
        icon: Icons.warning_amber_rounded,
      );
    }
    if (pm25 <= 54) {
      return const _PmAdvice(
        title: '即時提醒：不健康（敏感族群）',
        subtitle: '建議減少戶外時間，必要外出配戴口罩',
        color: Color(0xFFEF6C00),
        icon: Icons.masks,
      );
    }
    return const _PmAdvice(
      title: '即時提醒：不健康',
      subtitle: '建議減少戶外工作，必要外出務必配戴口罩',
      color: Color(0xFFC62828),
      icon: Icons.health_and_safety,
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = data;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '空氣品質預報',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            if (loading) const LinearProgressIndicator(),
            const SizedBox(height: 12),

            if (!loading && d == null) _emptyState('讀取失敗，請下拉重新整理'),
            if (!loading && d != null && d['error'] == true) _errorCard(d),
            if (!loading && d != null && d['error'] != true) ...[
              _mainCard(d),
              const SizedBox(height: 12),

              // ===== 新增：彰化站小時值卡片 =====
              _aqxChanghuaHourlyCard(),

              const SizedBox(height: 12),
              _legendCard(),
            ],

            const Padding(
              padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '資料來源：環境部資料開放平台',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.black54, height: 1.3)),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(Map<String, dynamic> d) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('讀取失敗', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            '原因：${d['message'] ?? d['status'] ?? ''}',
            style: const TextStyle(color: Colors.redAccent, height: 1.35),
          ),
          if ((d['body'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              (d['body'] ?? '').toString(),
              style: const TextStyle(color: Colors.black54, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mainCard(Map<String, dynamic> d) {
    final area = (d['area'] ?? '中部').toString();
    final aqi = _toInt(d['aqi']);
    final forecastDate = (d['forecastdate'] ?? '').toString();
    final pollutant = (d['majorpollutant'] ?? '').toString();
    final publishTime = (d['publishtime'] ?? '').toString();
    final content = (d['content'] ?? '').toString();

    final info = _aqiInfo(aqi);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ======= Header（AQI 顏色帶） =======
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: info.color.withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _aqiBadge(aqi, info),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$area 空氣品質預報',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (forecastDate.isNotEmpty) _chip('預報日 $forecastDate', _primaryColor),
                          if (pollutant.isNotEmpty) _chip('主要污染 $pollutant', _primaryColor),
                          if (publishTime.isNotEmpty) _chip('發布 $publishTime', _primaryColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ======= Advice =======
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.health_and_safety, color: info.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${info.level}｜${info.meaning}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: info.color,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        info.advice,
                        style: const TextStyle(height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 18),

          // ======= Content（可收合） =======
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('預報說明', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 8),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 180),
                  crossFadeState:
                      _contentExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: Text(
                    content,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(height: 1.45, color: Colors.black87),
                  ),
                  secondChild: Text(
                    content,
                    style: const TextStyle(height: 1.45, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _contentExpanded = !_contentExpanded),
                    icon: Icon(_contentExpanded ? Icons.expand_less : Icons.expand_more),
                    label: Text(_contentExpanded ? '收合內容' : '展開全部'),
                    style: TextButton.styleFrom(foregroundColor: _primaryColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aqiBadge(int? aqi, _AqiInfo info) {
    final aqiText = (aqi == null) ? '—' : aqi.toString();

    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: info.color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'AQI',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              aqiText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 28,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              info.level,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // =========================
  // 新增：彰化站小時值卡片（aqx_p_221）
  // =========================
  Widget _aqxChanghuaHourlyCard() {
    final theme = Theme.of(context);
    final textScale = MediaQuery.textScaleFactorOf(context);

    // 最新時間
    String latestTime = '';
    for (final r in _aqxRows) {
      if (r is Map && (r['monitordate'] ?? '').toString().trim().isNotEmpty) {
        latestTime = (r['monitordate'] ?? '').toString();
        break;
      }
    }

    // 取 PM2.5 做即時提醒
    final pm25 = _pickValueAsDouble(_aqxRows, 'PM2.5');
    final pmAdvice = _pm25Advice(pm25);

    

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題列
            Row(
              children: [
                Expanded(
                  child: Text(
                    '彰化站｜空氣品質小時值',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                IconButton(
                  tooltip: '重新整理',
                  onPressed: (_loadingAqx || loading) ? null : _load,
                  icon: (_loadingAqx || loading)
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            if (latestTime.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '最新時間：$latestTime',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 10),

            // 即時提醒條（用 PM2.5）
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pmAdvice.color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: pmAdvice.color.withOpacity(0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(pmAdvice.icon, color: pmAdvice.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pmAdvice.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: pmAdvice.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pmAdvice.subtitle +
                              (pm25 == null ? '' : '（PM2.5：${pm25.toStringAsFixed(0)} μg/m³）'),
                          style: const TextStyle(height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            if (_aqxError != null && _aqxError!.trim().isNotEmpty) ...[
              _hintBox(icon: Icons.error_outline, text: '小時值讀取失敗：$_aqxError'),
            ] else if (_loadingAqx && _aqxRows.isEmpty) ...[
              _hintBox(icon: Icons.cloud_download_outlined, text: '小時值讀取中…'),
            ] else if (_aqxRows.isEmpty) ...[
              _hintBox(icon: Icons.info_outline, text: '目前沒有小時值資料'),
            ] else ...[
              // Grid：字體越大 → 欄位越少
              LayoutBuilder(
                builder: (context, c) {
                  int crossAxisCount = 3;
if (textScale >= 1.2) crossAxisCount = 2;
if (textScale >= 1.6) crossAxisCount = 1;
if (c.maxWidth < 520) crossAxisCount = crossAxisCount.clamp(1, 2);

// ✅ 字越大 → 卡片越高（避免 overflow）
final double mainAxisExtent = crossAxisCount == 1
    ? (textScale >= 1.6 ? 116 : 98)
    : (textScale >= 1.3 ? 150 : 132);
                  final items = _normalizeAqxItems(_aqxRows);

                  return GridView.builder(
  itemCount: items.length,
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: crossAxisCount,
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    mainAxisExtent: mainAxisExtent, // ✅ 核心：固定高度避免溢位
  ),
  itemBuilder: (context, i) {
    final it = items[i];
    return _AqxMetricCard(
      title: it.title,
      code: it.code,
      valueText: it.valueText,
      unit: it.unit,
    );
  },
);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hintBox({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black.withOpacity(0.04),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.black87, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  double? _pickValueAsDouble(List<dynamic> rows, String itemEngName) {
    for (final r in rows) {
      if (r is! Map) continue;
      final code = (r['itemengname'] ?? '').toString().trim();
      if (code != itemEngName) continue;
      return _toDouble(r['concentration']);
    }
    return null;
  }

  List<_AqxItem> _normalizeAqxItems(List<dynamic> rows) {
    // 固定順序：PM2.5, PM10, O3, NO2, CO, SO2
    final Map<String, Map<String, dynamic>> map = {};

    for (final r in rows) {
      if (r is! Map) continue;
      final code = (r['itemengname'] ?? '').toString().trim(); // PM2.5...
      if (code.isEmpty) continue;
      map[code] = Map<String, dynamic>.from(r.cast<String, dynamic>());
    }

    _AqxItem build(String code, String titleFallback) {
      final r = map[code];
      final title = (r?['itemname'] ?? titleFallback).toString();
      final unit = (r?['itemunit'] ?? '').toString();
      final conc = (r?['concentration'] ?? '--').toString();

      return _AqxItem(
        code: code,
        title: title,
        unit: unit,
        valueText: conc,
      );
    }

    return [
      build('PM2.5', '細懸浮微粒'),
      build('PM10', '懸浮微粒'),
      build('O3', '臭氧'),
      build('NO2', '二氧化氮'),
      build('CO', '一氧化碳'),
      build('SO2', '二氧化硫'),
    ];
  }

  Widget _legendCard() {
    // 用跟 AQI mapping 同一套顏色
    final items = <_LegendItem>[
      _LegendItem('良好', '0–50', _aqiInfo(30).color),
      _LegendItem('普通', '51–100', _aqiInfo(80).color),
      _LegendItem('橘色提醒', '101–150', _aqiInfo(120).color),
      _LegendItem('紅色警示', '151–200', _aqiInfo(170).color),
      _LegendItem('紫色警報', '201–300', _aqiInfo(250).color),
      _LegendItem('褐紅危害', '301+', _aqiInfo(350).color),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AQI 等級說明', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items.map((it) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: it.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: it.color.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: it.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${it.name} ${it.range}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: it.color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _AqiInfo {
  final String level;
  final String meaning;
  final String advice;
  final Color color;

  const _AqiInfo({
    required this.level,
    required this.meaning,
    required this.advice,
    required this.color,
  });
}

class _LegendItem {
  final String name;
  final String range;
  final Color color;

  _LegendItem(this.name, this.range, this.color);
}

// ===== 新增：小時值卡片內部用的 model + widget =====

class _AqxItem {
  final String code;
  final String title;
  final String unit;
  final String valueText;

  _AqxItem({
    required this.code,
    required this.title,
    required this.unit,
    required this.valueText,
  });
}

class _AqxMetricCard extends StatelessWidget {
  final String title;
  final String code;
  final String valueText;
  final String unit;

  const _AqxMetricCard({
    required this.title,
    required this.code,
    required this.valueText,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withOpacity(0.035),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 上方：名稱（最多 2 行）
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),

          // 中間：代碼
          Text(
            code,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),

          const SizedBox(height: 10),

          // 下方：數值（用 Expanded + Align，避免 Spacer 撐爆）
          Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      valueText,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      unit,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PmAdvice {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _PmAdvice({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });
}
