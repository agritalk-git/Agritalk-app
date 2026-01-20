import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GrapeObservationPage extends StatefulWidget {
  const GrapeObservationPage({super.key});

  @override
  State<GrapeObservationPage> createState() => _GrapeObservationPageState();
}

class _GrapeObservationPageState extends State<GrapeObservationPage> {
  final apiService = ApiService();

  /// ✅ 多個地點（UUID＋顯示名稱）
  final List<Map<String, String>> groups = const [
    {'uuid': 'f42a1553-591f-4ad7-8167-ae1ed4e6b6cd', 'label': '彰化縣溪湖鎮葡萄'},
    {'uuid': '7e98412d-117e-4fff-86a3-d0bd506173fe', 'label': '彰化縣大村鄉葡萄'},
  ];

  DateTime startTime = DateTime.now().subtract(const Duration(days: 1));
  DateTime endTime = DateTime.now().add(const Duration(days: 1));
  bool loading = false;

  final Map<String, String> featureNameMap = {
    'Precipitation': '時降雨量(mm/h)',
    'Atmospheric Pressure': '大氣壓力(hPa)',
    'Soil Temperature': '土壤溫度(°C)',
    'Soil Moisture': '土壤濕度(%)',
    'Soil Electrical Conductivity': '土壤電導度(mS/cm)',
    'Potential of Hydrogen': '酸鹼度(pH)',
    'Temperature': '環境溫度(°C)',
    'Humidity': '環境相對濕度(%)',
    'Luminance': '照度(lux)',
    'Photosynthetically Active Radiation': 'PAR(光合作用有效輻射)',
    'Solar Radiation': '紫外線(UVI)',
    'Carbon Dioxide': '二氧化碳(ppm)',
    'Wind Direction': '風向(°)',
    'Wind Speed': '風速(m/s)',
  };

  /// ✅ 加入降雨量
  final List<String> features = const [
    'Precipitation',
    'Temperature',
    'Humidity',
    'Luminance',
    'Photosynthetically Active Radiation',
    'Solar Radiation',
    'Carbon Dioxide',
    'Atmospheric Pressure',
    'Soil Temperature',
    'Soil Moisture',
    'Soil Electrical Conductivity',
    'Potential of Hydrogen',
  ];

  /// feature → (seriesName → data points)
  Map<String, Map<String, List<ChartData>>> groupSeriesByFeature = {};

  /// 我的資料（feature → data points）
  Map<String, List<ChartData>> myChartDataMap = {};

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() => loading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isLoggedIn = token != null && token.isNotEmpty && token != 'GUEST_MODE';

    final Map<String, Map<String, List<ChartData>>> nextGroupSeries = {};
    final Map<String, List<ChartData>> nextMyData = {};

    // ✅ feature 層級並行
    await Future.wait(features.map((feature) async {
      nextGroupSeries[feature] = {};

      // ✅ group 層級並行
      final groupTasks = groups.map((g) async {
        final uuid = g['uuid']!;
        final label = g['label']!;

        final data = await apiService.fetchGroupObservation(
          groupUUID: uuid,
          featureEnglishName: feature,
          startTime: startTime,
          endTime: endTime,
          aggregate: "hours",
        );

        final points = (data ?? [])
            .map<ChartData>((item) => ChartData(
                  DateTime.parse(item['time']),
                  double.tryParse(item['value'].toString()) ?? 0,
                ))
            .toList()
          ..sort((a, b) => a.time.compareTo(b.time));

        return MapEntry(label, points);
      }).toList();

      final groupResults = await Future.wait(groupTasks);
      for (final e in groupResults) {
        nextGroupSeries[feature]![e.key] = e.value;
      }

      // ✅ 我的資料（同一個 feature 也照抓）
      if (isLoggedIn) {
        final mydata = await apiService.fetchMineRawData(
          featureEnglishName: feature,
          startTime: startTime,
          endTime: endTime,
          aggregate: "hours",
        );

        nextMyData[feature] = (mydata ?? [])
            .map<ChartData>((item) => ChartData(
                  DateTime.parse(item['time']),
                  double.tryParse(item['value'].toString()) ?? 0,
                ))
            .toList()
          ..sort((a, b) => a.time.compareTo(b.time));
      } else {
        nextMyData[feature] = const [];
      }
    }));

    if (!mounted) return;
    setState(() {
      groupSeriesByFeature = nextGroupSeries;
      myChartDataMap = nextMyData;
      loading = false;
    });
  }

  Future<void> _selectDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? startTime : endTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startTime = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
        } else {
          endTime = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        }
      });
      _fetchAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B4DBB),
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '葡萄雲 - 環境數據圖表',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ✅ 日期選擇：小螢幕/大字體自適應
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final bigText = MediaQuery.textScaleFactorOf(context) >= 1.25;
                      final narrow = c.maxWidth < 360;
                      final stackVertical = bigText || narrow;

                      final startLabel = '開始：${DateFormat('yyyy-MM-dd').format(startTime)}';
                      final endLabel = '結束：${DateFormat('yyyy-MM-dd').format(endTime)}';

                      Widget dateBtn({
                        required VoidCallback onPressed,
                        required IconData icon,
                        required String text,
                      }) {
                        return ElevatedButton.icon(
                          onPressed: onPressed,
                          icon: Icon(icon, size: 18),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(text),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          ),
                        );
                      }

                      if (stackVertical) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            dateBtn(
                              onPressed: () => _selectDate(isStart: true),
                              icon: Icons.calendar_month_rounded,
                              text: startLabel,
                            ),
                            const SizedBox(height: 10),
                            dateBtn(
                              onPressed: () => _selectDate(isStart: false),
                              icon: Icons.event_rounded,
                              text: endLabel,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: dateBtn(
                              onPressed: () => _selectDate(isStart: true),
                              icon: Icons.calendar_month_rounded,
                              text: startLabel,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: dateBtn(
                              onPressed: () => _selectDate(isStart: false),
                              icon: Icons.event_rounded,
                              text: endLabel,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: features.length,
                    itemBuilder: (context, index) {
                      final feature = features[index];
                      final seriesMap = groupSeriesByFeature[feature] ?? {};
                      final myData = myChartDataMap[feature] ?? const [];

                      return FeatureChart(
                        feature: feature,
                        title: featureNameMap[feature] ?? feature,
                        groupSeries: seriesMap,
                        myData: myData,
                        rangeStart: startTime,
                        rangeEnd: endTime,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class FeatureChart extends StatefulWidget {
  final String feature;
  final String title;

  final Map<String, List<ChartData>> groupSeries;
  final List<ChartData> myData;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  const FeatureChart({
    super.key,
    required this.feature,
    required this.title,
    required this.groupSeries,
    required this.myData,
    required this.rangeStart,
    required this.rangeEnd,
  });

  @override
  State<FeatureChart> createState() => _FeatureChartState();
}

class _FeatureChartState extends State<FeatureChart> with AutomaticKeepAliveClientMixin {
  late TooltipBehavior tooltipBehavior;

  @override
  void initState() {
    super.initState();
    tooltipBehavior = TooltipBehavior(enable: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final List<CartesianSeries<ChartData, DateTime>> seriesList = [];

    widget.groupSeries.forEach((label, points) {
      if (points.isEmpty) return;
      seriesList.add(
        LineSeries<ChartData, DateTime>(
          dataSource: points,
          xValueMapper: (d, _) => d.time,
          yValueMapper: (d, _) => d.value,
          width: 2,
          name: label,
          markerSettings: const MarkerSettings(isVisible: true),
        ),
      );
    });

    if (widget.myData.isNotEmpty) {
      seriesList.add(
        LineSeries<ChartData, DateTime>(
          dataSource: widget.myData,
          xValueMapper: (d, _) => d.time,
          yValueMapper: (d, _) => d.value,
          width: 2,
          name: '我的數據',
          markerSettings: const MarkerSettings(isVisible: true),
        ),
      );
    }

    final hasAnyData = seriesList.whereType<LineSeries<ChartData, DateTime>>().isNotEmpty;

    final _PrimaryLine primary = _pickPrimaryLine(
      myData: widget.myData,
      groupSeries: widget.groupSeries,
    );

    final _Stats? stats = primary.points.isEmpty ? null : _calcStats(primary.points);

    final int expectedHours = _expectedHourlyCount(widget.rangeStart, widget.rangeEnd);
    final int actualCount = primary.points.length;
    final double completeness = expectedHours <= 0 ? 0 : (actualCount / expectedHours).clamp(0.0, 1.0);

    final List<_InsightChip> chips = stats == null
        ? const []
        : _buildInsightsGrape(
            feature: widget.feature,
            stats: stats,
            points: primary.points,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + Info
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    tooltip: '這個數值對葡萄有什麼意義？',
                    onPressed: () => _showInfoSheet(context, widget.feature, widget.title),
                    icon: const Icon(Icons.info_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              if (stats != null)
                _SummaryRow(
                  sourceLabel: primary.label,
                  latest: stats.latest,
                  avg: stats.avg,
                  min: stats.min,
                  max: stats.max,
                  trend6h: stats.trend6h,
                  completeness: completeness,
                ),

              if (stats != null && chips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chips
                      .map((c) => Chip(
                            avatar: Icon(c.icon, size: 18),
                            label: Text(c.text),
                            backgroundColor: c.bg,
                            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                          ))
                      .toList(),
                ),
              ],

              const SizedBox(height: 12),

              if (!hasAnyData)
                const Text('查無資料', style: TextStyle(color: Colors.grey))
              else
                SizedBox(
                  height: 260,
                  child: SfCartesianChart(
                    tooltipBehavior: tooltipBehavior,
                    primaryXAxis: DateTimeAxis(
                      dateFormat: DateFormat('MM/dd HH:mm'),
                      intervalType: DateTimeIntervalType.auto,
                    ),
                    primaryYAxis: NumericAxis(
                      majorGridLines: const MajorGridLines(width: 0.3),
                    ),
                    zoomPanBehavior: ZoomPanBehavior(
                      enablePinching: true,
                      enablePanning: true,
                      enableDoubleTapZooming: true,
                    ),
                    series: seriesList,
                    legend: const Legend(
                      isVisible: true,
                      position: LegendPosition.bottom,
                      overflowMode: LegendItemOverflowMode.wrap,
                      toggleSeriesVisibility: true,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoSheet(BuildContext context, String feature, String title) {
    final info = _featureInfoGrape(feature, title);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final scale = MediaQuery.textScaleFactorOf(ctx);
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: DefaultTextStyle(
              style: TextStyle(fontSize: 15 * scale, color: Colors.black87),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  _InfoSection(
                    icon: Icons.lightbulb_outline_rounded,
                    title: '它影響什麼',
                    body: info.why,
                  ),
                  const SizedBox(height: 12),
                  _InfoSection(
                    icon: Icons.remove_red_eye_outlined,
                    title: '看什麼',
                    body: info.watch,
                  ),
                  const SizedBox(height: 12),
                  _InfoSection(
                    icon: Icons.handyman_outlined,
                    title: '可以怎麼做',
                    body: info.action,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '※ 提醒：本頁為環境監測參考；葡萄病害與生長狀態仍需巡園確認，感測器位置/遮蔽也會影響讀值。',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class ChartData {
  final DateTime time;
  final double value;
  ChartData(this.time, this.value);
}

/// =======================
/// Summary UI
/// =======================
class _SummaryRow extends StatelessWidget {
  final String sourceLabel;
  final double latest;
  final double avg;
  final double min;
  final double max;
  final double trend6h;
  final double completeness;

  const _SummaryRow({
    required this.sourceLabel,
    required this.latest,
    required this.avg,
    required this.min,
    required this.max,
    required this.trend6h,
    required this.completeness,
  });

  String _fmt(double v) {
    if (v.abs() >= 100) return v.toStringAsFixed(0);
    if (v.abs() >= 10) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScaleFactorOf(context);
    final pct = (completeness * 100).round();
    final trendText = trend6h == 0 ? '持平' : (trend6h > 0 ? '+${_fmt(trend6h)}' : _fmt(trend6h));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withOpacity(0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '摘要（來源：$sourceLabel）',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13 * scale),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _kv('最新', _fmt(latest)),
              _kv('平均', _fmt(avg)),
              _kv('最大', _fmt(max)),
              _kv('最小', _fmt(min)),
              _kv('近6小時', trendText),
              _kv('完整度', '$pct%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$k：', style: const TextStyle(color: Colors.black54)),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

/// =======================
/// Info content (葡萄版)
/// =======================
class _FeatureInfo {
  final String title;
  final String why;
  final String watch;
  final String action;

  const _FeatureInfo({
    required this.title,
    required this.why,
    required this.watch,
    required this.action,
  });
}

_FeatureInfo _featureInfoGrape(String feature, String title) {
  switch (feature) {
    case 'Precipitation':
      return _FeatureInfo(
        title: title,
        why: '雨後葉面潮濕時間拉長，葡萄常見病害（霜霉、灰黴等）壓力上升；也可能導致土壤過濕、根系缺氧。',
        watch: '雨後 24–48 小時是否仍高濕、園內是否積水；若連續降雨要特別留意病斑、裂果與落果。',
        action: '雨後先巡園：排水、清溝、避免園內過度郁蔽；依管理策略評估防治時機，並加強通風。',
      );
    case 'Humidity':
      return _FeatureInfo(
        title: title,
        why: '高濕 + 葉面不易乾，是葡萄霜霉/灰黴等病害的常見條件；過低濕度搭配高溫會增加蒸散壓力。',
        watch: '夜間/清晨是否長時間高濕（連續多小時）；搭配降雨與風速一起看更準。',
        action: '高濕：加強通風、修剪降低郁蔽、避免夜間灌水；低濕：注意水分管理、避免乾熱傷害。',
      );
    case 'Temperature':
      return _FeatureInfo(
        title: title,
        why: '溫度影響新梢生長、開花坐果、糖度累積與病害活性；極端高溫/低溫都會讓植株壓力上升。',
        watch: '是否連續高溫或夜間偏冷；日夜溫差突然變大也要留意。',
        action: '高溫：遮陰/降溫與補水分次；低溫：避免過度灌水、視園區條件做防風保溫。',
      );
    case 'Soil Moisture':
      return _FeatureInfo(
        title: title,
        why: '土壤水分影響根系吸收與果實膨大；忽乾忽濕容易造成生理壓力，也可能提高裂果風險（視品種/時期）。',
        watch: '是否長時間偏濕或偏乾；波動是否很大。',
        action: '偏乾：分次灌溉避免一次灌太多；偏濕：改善排水、避免根系缺氧與病害。',
      );
    case 'Soil Electrical Conductivity':
      return _FeatureInfo(
        title: title,
        why: 'EC 可反映土壤溶液鹽分/肥分濃度趨勢；過高可能造成根系吸水困難與鹽害。',
        watch: '施肥後是否突然升高、是否長期偏高。',
        action: '偏高：評估施肥量與時機、必要時配合灌水沖洗；偏低：可能肥分不足但仍需搭配樹勢判斷。',
      );
    case 'Potential of Hydrogen':
      return _FeatureInfo(
        title: title,
        why: 'pH 影響養分有效性（太酸或太鹼都會讓某些元素難吸收），長期偏離會影響生長與品質。',
        watch: 'pH 是否長期偏酸/偏鹼，並觀察缺素症狀。',
        action: '建議搭配土壤檢測；依改良策略調整（石灰/有機質等）。',
      );
    case 'Luminance':
      return _FeatureInfo(
        title: title,
        why: '光照影響光合作用與果實糖度；曝曬過強可能造成日灼，太弱可能影響成熟與品質。',
        watch: '中午是否長時間極高光照；雨季是否長期偏低光照。',
        action: '曝曬強：遮陰/防曬與水分管理；光照不足：修枝改善透光、調整郁蔽。',
      );
    case 'Photosynthetically Active Radiation':
      return _FeatureInfo(
        title: title,
        why: 'PAR 更接近「葡萄能用的光」，比照度更能反映光合作用條件。',
        watch: '白天是否長期偏低或波動很大（雲雨/遮蔽）。',
        action: '偏低：修枝改善透光；偏高且高溫：搭配遮陰與水分管理。',
      );
    case 'Solar Radiation':
      return _FeatureInfo(
        title: title,
        why: '紫外線偏強可能提高日灼與葉面壓力，尤其夏季與高溫並發時更明顯。',
        watch: 'UVI 是否在中午長時間偏高，並留意是否合併高溫低濕。',
        action: '遮陰/防曬，並在高溫時段避免強烈修剪造成曝曬。',
      );
    case 'Carbon Dioxide':
      return _FeatureInfo(
        title: title,
        why: 'CO₂ 反映空氣交換狀況（棚架/溫室更明顯）；通風不足時可能影響光合作用效率。',
        watch: '白天是否常偏低、或日內波動是否異常。',
        action: '改善通風；溫室可搭配通風策略調整。',
      );
    case 'Atmospheric Pressure':
      return _FeatureInfo(
        title: title,
        why: '氣壓變化常伴隨天氣系統移動，可作為鋒面/降雨前的輔助參考。',
        watch: '氣壓快速下降常見於低壓接近（可能轉雨）。',
        action: '搭配降雨與濕度：提前做排水與病害風險管理。',
      );
    case 'Soil Temperature':
      return _FeatureInfo(
        title: title,
        why: '土溫影響根系活性與養分吸收；過低根系活性下降，過高也會增加壓力。',
        watch: '土溫是否長期偏低或突然劇烈升高。',
        action: '調整覆蓋與灌溉時間，避免根圈長時間極端溫度。',
      );
    default:
      return _FeatureInfo(
        title: title,
        why: '此數值可用來觀察園區環境變化，搭配其他指標更能判讀病害與生理壓力風險。',
        watch: '注意是否出現「長時間偏高/偏低」或「突然急劇變化」。',
        action: '若發現異常，先比對濕度/降雨/風速等，並巡園確認。',
      );
  }
}

class _InfoSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(body),
            ],
          ),
        ),
      ],
    );
  }
}

/// =======================
/// Primary line + Stats
/// =======================
class _PrimaryLine {
  final String label;
  final List<ChartData> points;
  const _PrimaryLine(this.label, this.points);
}

_PrimaryLine _pickPrimaryLine({
  required List<ChartData> myData,
  required Map<String, List<ChartData>> groupSeries,
}) {
  if (myData.isNotEmpty) return _PrimaryLine('我的數據', myData);
  for (final e in groupSeries.entries) {
    if (e.value.isNotEmpty) return _PrimaryLine(e.key, e.value);
  }
  return const _PrimaryLine('無資料', []);
}

class _Stats {
  final double latest;
  final double avg;
  final double min;
  final double max;
  final double sd;
  final double trend6h;

  const _Stats({
    required this.latest,
    required this.avg,
    required this.min,
    required this.max,
    required this.sd,
    required this.trend6h,
  });
}

_Stats _calcStats(List<ChartData> points) {
  final values = points.map((e) => e.value).toList();
  final latest = points.last.value;

  double sum = 0;
  double minV = values.first;
  double maxV = values.first;
  for (final v in values) {
    sum += v;
    if (v < minV) minV = v;
    if (v > maxV) maxV = v;
  }
  final avg = sum / values.length;

  double varSum = 0;
  for (final v in values) {
    final d = v - avg;
    varSum += d * d;
  }
  final sd = math.sqrt(varSum / math.max(1, values.length));

  final targetTime = points.last.time.subtract(const Duration(hours: 6));
  ChartData nearest = points.first;
  for (final p in points) {
    if ((p.time.difference(targetTime)).abs() < (nearest.time.difference(targetTime)).abs()) {
      nearest = p;
    }
  }
  final trend6h = latest - nearest.value;

  return _Stats(
    latest: latest,
    avg: avg,
    min: minV,
    max: maxV,
    sd: sd,
    trend6h: trend6h,
  );
}

int _expectedHourlyCount(DateTime start, DateTime end) {
  if (end.isBefore(start)) return 0;
  return end.difference(start).inHours + 1;
}

/// =======================
/// Insight chips (葡萄版)
/// =======================
class _InsightChip {
  final String text;
  final IconData icon;
  final Color bg;
  const _InsightChip(this.text, this.icon, this.bg);
}

List<_InsightChip> _buildInsightsGrape({
  required String feature,
  required _Stats stats,
  required List<ChartData> points,
}) {
  final chips = <_InsightChip>[];

  final double hi = (stats.avg + stats.sd).toDouble();
  final double lo = (stats.avg - stats.sd).toDouble();

  int consecAbove(double thr) {
    int best = 0, cur = 0;
    for (final p in points) {
      if (p.value >= thr) {
        cur += 1;
        if (cur > best) best = cur;
      } else {
        cur = 0;
      }
    }
    return best;
  }

  int consecBelow(double thr) {
    int best = 0, cur = 0;
    for (final p in points) {
      if (p.value <= thr) {
        cur += 1;
        if (cur > best) best = cur;
      } else {
        cur = 0;
      }
    }
    return best;
  }

  switch (feature) {
    case 'Humidity': {
      // 葡萄：高濕更敏感，給稍保守的提示（相對 + 絕對）
      final double thr = math.max<double>(hi, 85.0);
      final int hours = consecAbove(thr);
      if (hours >= 6) {
        chips.add(_InsightChip('高濕連續 $hours 小時（霜霉/灰黴風險↑）', Icons.water_drop_outlined, const Color(0xFFE3F2FD)));
      } else if (stats.latest >= thr) {
        chips.add(_InsightChip('目前偏高濕（注意葉面不易乾）', Icons.water_drop_outlined, const Color(0xFFE3F2FD)));
      }

      final double lowThr = math.min<double>(lo, 45.0);
      final int lowHours = consecBelow(lowThr);
      if (lowHours >= 6) {
        chips.add(_InsightChip('偏低濕連續 $lowHours 小時（乾熱/蒸散↑）', Icons.air, const Color(0xFFFFF3E0)));
      }
      break;
    }

    case 'Precipitation': {
      double sum6h = 0;
      final now = points.isNotEmpty ? points.last.time : DateTime.now();
      for (final p in points) {
        if (p.time.isAfter(now.subtract(const Duration(hours: 6)))) {
          sum6h += p.value;
        }
      }
      if (stats.latest >= 1.0) {
        chips.add(_InsightChip('目前有降雨（雨後病害風險↑）', Icons.umbrella_outlined, const Color(0xFFE3F2FD)));
      } else if (sum6h >= 5.0) {
        chips.add(_InsightChip('近6小時累積降雨 ${sum6h.toStringAsFixed(1)} mm', Icons.umbrella_outlined, const Color(0xFFE3F2FD)));
      }
      break;
    }

    case 'Temperature': {
      final double highThr = math.max<double>(hi, 32.0);
      final double lowThr = math.min<double>(lo, 12.0);

      final int highHours = consecAbove(highThr);
      if (highHours >= 6) {
        chips.add(_InsightChip('偏高溫連續 $highHours 小時（熱壓力↑）', Icons.local_fire_department_outlined, const Color(0xFFFFEBEE)));
      } else if (stats.latest >= highThr) {
        chips.add(_InsightChip('目前偏高溫（注意遮陰/補水）', Icons.local_fire_department_outlined, const Color(0xFFFFEBEE)));
      }

      final int lowHours = consecBelow(lowThr);
      if (lowHours >= 6) {
        chips.add(_InsightChip('偏低溫連續 $lowHours 小時（生長放緩）', Icons.ac_unit_outlined, const Color(0xFFE8EAF6)));
      }
      break;
    }

    case 'Soil Moisture': {
      final double dryThr = lo;
      final double wetThr = hi;

      final int dryHours = consecBelow(dryThr);
      if (dryHours >= 6) {
        chips.add(_InsightChip('土壤偏乾連續 $dryHours 小時（灌溉評估）', Icons.grass_outlined, const Color(0xFFFFF3E0)));
      } else if (stats.latest <= dryThr) {
        chips.add(_InsightChip('目前偏乾（注意水分波動）', Icons.grass_outlined, const Color(0xFFFFF3E0)));
      }

      final int wetHours = consecAbove(wetThr);
      if (wetHours >= 6) {
        chips.add(_InsightChip('土壤偏濕連續 $wetHours 小時（排水注意）', Icons.waves_outlined, const Color(0xFFE8F5E9)));
      }
      break;
    }

    case 'Soil Electrical Conductivity': {
      final double highThr = math.max<double>(hi, 2.5);
      if (stats.latest >= highThr) {
        chips.add(_InsightChip('EC 偏高（肥/鹽濃度可能偏高）', Icons.science_outlined, const Color(0xFFFFF8E1)));
      }
      break;
    }

    case 'Potential of Hydrogen': {
      if (stats.latest < 5.5) {
        chips.add(_InsightChip('pH 偏酸（養分有效性可能受影響）', Icons.warning_amber_rounded, const Color(0xFFFFF8E1)));
      } else if (stats.latest > 7.5) {
        chips.add(_InsightChip('pH 偏鹼（養分有效性可能受影響）', Icons.warning_amber_rounded, const Color(0xFFFFF8E1)));
      }
      break;
    }

    case 'Solar Radiation': {
      final double thr = math.max<double>(hi, 8.0);
      if (stats.latest >= thr) {
        chips.add(_InsightChip('紫外線偏強（日灼風險↑）', Icons.wb_sunny_outlined, const Color(0xFFFFF3E0)));
      }
      break;
    }

    default: {
      if (stats.latest >= hi) {
        chips.add(_InsightChip('目前偏高（相對）', Icons.trending_up, const Color(0xFFE8F5E9)));
      } else if (stats.latest <= lo) {
        chips.add(_InsightChip('目前偏低（相對）', Icons.trending_down, const Color(0xFFFFEBEE)));
      }
      break;
    }
  }

  return chips;
}
