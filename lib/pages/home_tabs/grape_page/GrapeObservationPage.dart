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
    'Soil Electrical Conductivity': '土壤電導度(μS/cm)',
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

    'Temperature',
    'Humidity',
    'Luminance',
    'Photosynthetically Active Radiation',
    'Solar Radiation',
    'Carbon Dioxide',
    'Atmospheric Pressure',
    'Precipitation',
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
                  if (info.reference.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _InfoSection(
                      icon: Icons.menu_book_outlined,
                      title: '參考資料',
                      body: info.reference,
                    ),
                  ],
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
              // _kv('完整度', '$pct%'),
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
  final String reference;

  const _FeatureInfo({
    required this.title,
    required this.why,
    required this.watch,
    required this.action,
    this.reference = '',
  });
}

_FeatureInfo _featureInfoGrape(String feature, String title) {

  const references = '''
1. 謝慶芳。1988。葡萄園土壤之管理。葡萄生產技術14:71-84。台灣省台中區農業改良場。
2. 林嘉興 張林仁。1988。設施葡萄溫度管理與生育之探討。葡萄生產技術 14:157-172。
3. 葉文彬。2020。葡萄因應氣候變遷之栽培管理調適措施。中部地區重要果樹因應氣候變遷栽培管理調適措施。行政院農業委員會臺中區農業改良場技術專刊2 0 2 :3-9。
4. 葡萄防災栽培曆。農作物災害預警平台。農業部農業試驗所。
''';

  switch (feature) {
    case 'Precipitation':
      return _FeatureInfo(
        title: title,
        why: '降雨會提高病害風險並影響土壤含氧量。',
        watch: '連續降雨或雨後高濕，易發生霜霉病、灰黴病。',
        action: '加強排水、通風，並視情況進行病害管理。',
        reference: references,
      );
    case 'Humidity':
      return _FeatureInfo(
        title: title,
        why: '高溫（28–32°C）搭配低濕（40–60%）容易導致葡萄著果不良。',
        watch: '當環境高溫且濕度低於 60% 時，需注意花粉活性下降與著果率降低。',
        action: '建議使用噴霧系統提高空氣濕度，改善授粉環境。',
        reference: references,
      );
    case 'Temperature':
      return _FeatureInfo(
        title: title,
        why: '葡萄生長最低氣溫約 12–15°C，低於 10°C 易發生寒害；高於 30°C 則可能出現熱害與著果不良。',
        watch: '''
<10°C：寒害風險（新梢受損、發芽不良）
20°C：開花最適溫
20–30°C：果實肥大最佳
>30°C：高溫障礙、著果率下降
催芽期：日溫30°C / 夜溫10°C 最佳
''',
        action: '''
寒流前：疏芽、夜間燈照、多施磷肥與有機肥（少氮）
寒流後：施葉肥、開根素恢復樹勢
高溫時：保持土壤濕度、溫室通風、適度疏果、噴霧降溫
''',
reference: references,
      );
    case 'Soil Moisture':
      return _FeatureInfo(
        title: title,
        why: '土壤水分影響根系吸收與果實膨大；忽乾忽濕容易造成生理壓力，也可能提高裂果風險（視品種/時期）。',
        watch: '是否長時間偏濕或偏乾；波動是否很大。',
        action: '偏乾：分次灌溉避免一次灌太多；偏濕：改善排水、避免根系缺氧與病害。',
        reference: references,
      );
    case 'Soil Electrical Conductivity':
      return _FeatureInfo(
        title: title,
        why: 'EC 代表土壤鹽分濃度，過高會影響根系吸水。',
        watch: '當 EC > 2700 μS/cm 時，可能發生鹽害。',
        action: '減少施肥濃度、增加灌水沖洗鹽分，改善排水。',
        reference: references,
      );
    case 'Potential of Hydrogen':
      return _FeatureInfo(
        title: title,
        why: '土壤 pH 會影響養分吸收與果實品質，不同品種需求略有不同。',
        watch: '''
一般品種：pH 6.0–8.0
巨峰葡萄：pH 6.5–8.0 最佳
>7.5：有助提升糖度與產量
<5.5：枝條徒長、果粒不肥大、著色慢
''',
        action: '建議定期土壤檢測，依結果調整石灰或有機質施用。',
        reference: references,
      );

    case 'Luminance':
    case 'Photosynthetically Active Radiation':
      return _FeatureInfo(
        title: title,
        why: '光照影響葡萄光合作用與糖度累積。',
        watch: '''
光補償點：約 500–1100 lux
光飽和點：約 80,000 lux
光不足：影響生長與成熟
光過強：可能造成日灼
''',
        action: '透過修枝改善通風透光，或在高溫強光時進行遮陰。',
        reference: references,
      );
   
    default:
      return _FeatureInfo(
        title: title,
        why: '此數值可用來觀察園區環境變化，搭配其他指標更能判讀病害與生理壓力風險。',
        watch: '注意是否出現「長時間偏高/偏低」或「突然急劇變化」。',
        action: '搭配其他環境數據與巡園判斷。',
        reference: references,
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

  int consecAbove(double thr) {
    int best = 0, cur = 0;
    for (final p in points) {
      if (p.value >= thr) {
        cur++;
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
        cur++;
        if (cur > best) best = cur;
      } else {
        cur = 0;
      }
    }
    return best;
  }

  switch (feature) {

    /// 🌡️ 溫度（完全依照你給的葡萄條件）
    case 'Temperature':
      if (stats.latest < 10) {
        chips.add(_InsightChip('寒害警報（<10°C）', Icons.ac_unit, const Color(0xFFE3F2FD)));
      } else if (stats.latest < 15) {
        chips.add(_InsightChip('低溫注意（10–15°C）', Icons.warning_amber, const Color(0xFFFFF8E1)));
      } else if (stats.latest >= 20 && stats.latest <= 30) {
        chips.add(_InsightChip('生長適溫（20–30°C）', Icons.check_circle, const Color(0xFFE8F5E9)));
      } else if (stats.latest > 30) {
        chips.add(_InsightChip('高溫警戒（>30°C）', Icons.local_fire_department, const Color(0xFFFFEBEE)));
      }

      // 連續高溫
      final hotHours = consecAbove(30);
      if (hotHours >= 6) {
        chips.add(_InsightChip('連續高溫 $hotHours 小時（著果不良風險）', Icons.local_fire_department, const Color(0xFFFFCDD2)));
      }

      // 連續低溫
      final coldHours = consecBelow(12);
      if (coldHours >= 6) {
        chips.add(_InsightChip('連續低溫 $coldHours 小時（生長停滯）', Icons.ac_unit, const Color(0xFFE1F5FE)));
      }
      break;

    /// 💧 濕度（結合你給的條件）
    case 'Humidity':
      if (stats.latest < 40) {
        chips.add(_InsightChip('濕度過低（<40%）', Icons.air, const Color(0xFFFFF3E0)));
      } else if (stats.latest >= 40 && stats.latest <= 60) {
        chips.add(_InsightChip('低濕區（40–60%，著果不良風險）', Icons.air, const Color(0xFFFFF8E1)));
      } else if (stats.latest > 85) {
        chips.add(_InsightChip('高濕（病害風險↑）', Icons.water_drop, const Color(0xFFE3F2FD)));
      }

      final lowHumHours = consecBelow(60);
      if (lowHumHours >= 6) {
        chips.add(_InsightChip('連續低濕 $lowHumHours 小時（授粉不良）', Icons.air, const Color(0xFFFFE0B2)));
      }
      break;

    /// 🌱 土壤濕度
    case 'Soil Moisture':
      if (stats.latest < 20) {
        chips.add(_InsightChip('土壤過乾（<20%）', Icons.grass, const Color(0xFFFFF3E0)));
      } else if (stats.latest > 40) {
        chips.add(_InsightChip('土壤過濕（>40%）', Icons.water, const Color(0xFFE8F5E9)));
      } else {
        chips.add(_InsightChip('土壤適中（20–40%）', Icons.check_circle, const Color(0xFFE8F5E9)));
      }
      break;

    /// ⚡ EC（你給的是 2700）
    case 'Soil Electrical Conductivity':
      if (stats.latest > 2700) {
        chips.add(_InsightChip('鹽害風險（>2700 μS/cm）', Icons.science, const Color(0xFFFFCDD2)));
      } else if (stats.latest > 1500) {
        chips.add(_InsightChip('EC偏高（注意施肥）', Icons.warning, const Color(0xFFFFF8E1)));
      }
      break;

    /// ⚗️ pH
    case 'Potential of Hydrogen':
      if (stats.latest < 5.5) {
        chips.add(_InsightChip('pH過低（<5.5）', Icons.warning, const Color(0xFFFFF8E1)));
      } else if (stats.latest > 7.5) {
        chips.add(_InsightChip('pH偏高（有助糖度）', Icons.trending_up, const Color(0xFFE8F5E9)));
      } else {
        chips.add(_InsightChip('pH適中（6–8）', Icons.check_circle, const Color(0xFFE8F5E9)));
      }
      break;

    /// 光照
    case 'Luminance':
      if (stats.latest < 1000) {
        chips.add(_InsightChip('光照不足', Icons.dark_mode, const Color(0xFFE3F2FD)));
      } else if (stats.latest > 80000) {
        chips.add(_InsightChip('光照過強（可能日灼）', Icons.wb_sunny, const Color(0xFFFFEBEE)));
      } else {
        chips.add(_InsightChip('光照適中', Icons.wb_sunny_outlined, const Color(0xFFE8F5E9)));
      }
      break;

    /// 雨量
    case 'Precipitation':
      double sum24h = 0;
      final now = points.isNotEmpty ? points.last.time : DateTime.now();

      for (final p in points) {
        if (p.time.isAfter(now.subtract(const Duration(hours: 24)))) {
          sum24h += p.value;
        }
      }

      if (sum24h > 50) {
        chips.add(_InsightChip('近24小時降雨 ${sum24h.toStringAsFixed(1)} mm（病害風險↑）',
            Icons.umbrella, const Color(0xFFE3F2FD)));
      } else if (stats.latest > 0) {
        chips.add(_InsightChip('目前降雨中', Icons.umbrella, const Color(0xFFE3F2FD)));
      }
      break;

    default:
      if (stats.latest > stats.avg) {
        chips.add(_InsightChip('目前偏高（相對）', Icons.trending_up, const Color(0xFFE8F5E9)));
      } else if (stats.latest < stats.avg) {
        chips.add(_InsightChip('目前偏低（相對）', Icons.trending_down, const Color(0xFFFFEBEE)));
      }
      break;
  }

  return chips;
}
