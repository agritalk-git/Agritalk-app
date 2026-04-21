import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GuavaObservationPage extends StatefulWidget {
  const GuavaObservationPage({super.key});

  @override
  State<GuavaObservationPage> createState() => _GuavaObservationPageState();
}

class _GuavaObservationPageState extends State<GuavaObservationPage> {
  final apiService = ApiService();

  /// ✅ 多個地點（UUID＋顯示名稱）
  final List<Map<String, String>> groups = const [
    {'uuid': '9d9c7009-0661-4618-9d13-592f589d49b1', 'label': '彰化縣溪州鄉芭樂'},
    {'uuid': '3f72eb66-32e2-4241-8a72-58c235ac6164', 'label': '彰化縣社頭鄉芭樂'},
  ];

  DateTime startTime = DateTime.now().subtract(const Duration(days: 1));
  DateTime endTime = DateTime.now().add(const Duration(days: 1));
  bool loading = false;

  final Map<String, String> featureNameMap = {
    
    'Atmospheric Pressure': '大氣壓力(hPa)',
    'Soil Temperature': '土壤溫度(°C)',
    'Soil Moisture': '土壤濕度(%)',
    'Soil Electrical Conductivity': '土壤電導度(μS/cm)',
    'Potential of Hydrogen': '酸鹼度(pH)',
    'Temperature': '環境溫度(°C)',
    'Humidity': '環境相對濕度(%)',
    'Precipitation': '時降雨量(mm/h)',
    'Luminance': '照度(lux)',
    'Photosynthetically Active Radiation': 'PAR(光合作用有效輻射)',
    'Solar Radiation': '紫外線(UVI)',
    'Carbon Dioxide': '二氧化碳(ppm)',
    'Wind Direction': '風向(°)',
    'Wind Speed': '風速(m/s)',
  };

  /// ✅ 番石榴各指標標籤
  final Map<String, List<String>> featureLabelMap = const {
    'Temperature': [
      '生育適溫：15–32℃',
      '著果適溫：23–28℃',
      '警戒：<15℃寒害、>37℃熱障礙',
    ],
    'Precipitation': [
      '警戒值：日雨量 > 200 mm',
    ],
    'Soil Moisture': [
      '正常值：20–40%',
    ],
    'Potential of Hydrogen': [
      '正常值：pH 5.5–7.5',
    ],
    'Soil Electrical Conductivity': [
      '警戒值：>1000（鹽害風險）',
    ],
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

    await Future.wait(features.map((feature) async {
      nextGroupSeries[feature] = {};

      // 1) 群組多地點並行抓
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

      // 2) 我的數據（可選）
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
          '芭樂雲 - 環境數據圖表',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
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
                        labels: featureLabelMap[feature] ?? const [],
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
  final List<String> labels;
  final Map<String, List<ChartData>> groupSeries;
  final List<ChartData> myData;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  const FeatureChart({
    super.key,
    required this.feature,
    required this.title,
    required this.labels,
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
        : _buildInsights(
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    tooltip: '這個數值對番石榴有什麼意義？',
                    onPressed: () => _showInfoSheet(context, widget.feature, widget.title),
                    icon: const Icon(Icons.info_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              if (widget.labels.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.labels.map((label) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFD6BCFA)),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B46C1),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ],

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
                  children: chips.map((c) {
                    return Chip(
                      avatar: Icon(c.icon, size: 18),
                      label: Text(c.text),
                      backgroundColor: c.bg,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                    );
                  }).toList(),
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
    final info = _featureInfo(feature, title);

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
                    '※ 提醒：本頁為環境監測參考；感測器位置、遮蔽物、日照與設備校正都可能影響讀值。',
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

    final trendText = trend6h == 0
        ? '持平'
        : (trend6h > 0 ? '+${_fmt(trend6h)}' : _fmt(trend6h));

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

_FeatureInfo _featureInfo(String feature, String title) {
  const references = '''
1. 陳鴻堂、郭雅紋、曾宥綋。番石榴土壤肥力檢測與肥培管理。臺中區農業專訊90:9-15
2. 農作物災害預警平台－番石榴作物防災栽培曆
3. 農作物災害預警平台－作物資訊
''';

  switch (feature) {
    case 'Temperature':
      return _FeatureInfo(
        title: title,
        why: '番石榴生育適溫為 15–32℃，著果適溫為 23–28℃。溫度過低會影響新梢與果實發育，過高則會造成授粉不良與熱障礙。',
        watch: '<15℃ 時要注意寒害，可能出現新梢生長停滯、葉片紫紅、果實表皮受損出現紅點、花粉發芽率下降。>37℃ 時要注意熱障礙，花粉萌芽率降低，進而影響授粉。',
        action: '預防：調整留果數，施用鈣、鉀肥。復原：輕度修剪，加強肥培，促進樹勢恢復。',
        reference: references,
      );

    case 'Precipitation':
      return _FeatureInfo(
        title: title,
        why: '雨量過多會導致授粉不良、落花、落果及果實生育停滯，並增加果實病害風險。若長期積水，根系受損，植株生育也會變差。',
        watch: '當日雨量 > 200 mm 時要提高警覺，並留意田區是否積水、排水不良、病果增加或果實生長停滯。',
        action: '預防：注意排水設施、調節產期。復原：排除積水、清除病果，加強病害防治與肥培，促進新根、枝梢生長。',
        reference: references,
      );

    case 'Soil Moisture':
      return _FeatureInfo(
        title: title,
        why: '番石榴土壤濕度正常值約 20–40%。過乾會影響根系吸水與果實發育，過濕則容易造成根系缺氧與病害增加。',
        watch: '注意是否長時間低於 20% 或高於 40%，也要留意是否有忽乾忽濕的劇烈變化。',
        action: '偏乾時分次灌溉，避免一次灌太多；偏濕時加強排水，降低根系受損與病害風險。',
        reference: references,
      );

    case 'Potential of Hydrogen':
      return _FeatureInfo(
        title: title,
        why: '番石榴較適合的土壤酸鹼值為 pH 5.5–7.5。pH 過高易引起微量元素缺乏，pH 過低易引起缺鈣、缺鎂。',
        watch: '當 pH 長期高於 7.5 或低於 5.5 時，要留意植株是否有缺素、生長不良或葉片異常。',
        action: '改善方式：施用苦土石灰（鎂鈣肥）或蚵殼粉，於施基肥前一個月拌入土中。',
        reference: references,
      );

    case 'Soil Electrical Conductivity':
      return _FeatureInfo(
        title: title,
        why: 'EC 可作為土壤鹽分與肥分濃度的參考。當 EC 過高時，表示鹽分濃度偏高，容易產生鹽害風險，影響根系吸水與生長。',
        watch: '當數值 > 1000 時應提高警覺，並觀察是否有根系受損、生長停滯或施肥後長期偏高情況。',
        action: '建議檢查施肥量與施肥頻率，必要時搭配灌水與排水管理，降低土壤鹽分累積風險。',
        reference: references,
      );

    default:
      return _FeatureInfo(
        title: title,
        why: '此數值可用來觀察番石榴田區環境變化，搭配其他指標更能判讀風險。',
        watch: '注意是否出現長時間偏高、偏低，或突然急劇變化。',
        action: '若發現異常，可搭配降雨、濕度、溫度與田間巡查綜合判斷。',
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

  return _Stats(latest: latest, avg: avg, min: minV, max: maxV, sd: sd, trend6h: trend6h);
}

int _expectedHourlyCount(DateTime start, DateTime end) {
  if (end.isBefore(start)) return 0;
  final diff = end.difference(start);
  return diff.inHours + 1;
}

class _InsightChip {
  final String text;
  final IconData icon;
  final Color bg;
  const _InsightChip(this.text, this.icon, this.bg);
}

List<_InsightChip> _buildInsights({
  required String feature,
  required _Stats stats,
  required List<ChartData> points,
}) {
  final chips = <_InsightChip>[];

  final double hi = (stats.avg + stats.sd).toDouble();
  final double lo = (stats.avg - stats.sd).toDouble();

  switch (feature) {
    case 'Temperature':
      if (stats.latest < 15) {
        chips.add(_InsightChip('低溫警戒（<15℃，注意寒害）', Icons.ac_unit_outlined, const Color(0xFFE8EAF6)));
      } else if (stats.latest > 37) {
        chips.add(_InsightChip('高溫警戒（>37℃，注意熱障礙）', Icons.local_fire_department_outlined, const Color(0xFFFFEBEE)));
      } else if (stats.latest >= 23 && stats.latest <= 28) {
        chips.add(_InsightChip('著果適溫區間（23–28℃）', Icons.check_circle_outline, const Color(0xFFE8F5E9)));
      } else if (stats.latest >= 15 && stats.latest <= 32) {
        chips.add(_InsightChip('生育適溫區間（15–32℃）', Icons.eco_outlined, const Color(0xFFE8F5E9)));
      }
      break;

    case 'Precipitation':
      double sum24h = 0;
      final now = points.isNotEmpty ? points.last.time : DateTime.now();
      for (final p in points) {
        if (p.time.isAfter(now.subtract(const Duration(hours: 24)))) {
          sum24h += p.value;
        }
      }

      if (sum24h > 200) {
        chips.add(_InsightChip('日雨量警戒（近24小時 > 200 mm）', Icons.umbrella_outlined, const Color(0xFFE3F2FD)));
      } else if (stats.latest >= 1.0) {
        chips.add(_InsightChip('目前有降雨', Icons.umbrella_outlined, const Color(0xFFE3F2FD)));
      }
      break;

    case 'Soil Moisture':
      if (stats.latest < 20) {
        chips.add(_InsightChip('土壤偏乾（<20%）', Icons.grass_outlined, const Color(0xFFFFF3E0)));
      } else if (stats.latest > 40) {
        chips.add(_InsightChip('土壤偏濕（>40%）', Icons.waves_outlined, const Color(0xFFE8F5E9)));
      } else {
        chips.add(_InsightChip('土壤濕度正常（20–40%）', Icons.check_circle_outline, const Color(0xFFE8F5E9)));
      }
      break;

    case 'Potential of Hydrogen':
      if (stats.latest < 5.5) {
        chips.add(_InsightChip('pH 偏低（<5.5）', Icons.warning_amber_rounded, const Color(0xFFFFF8E1)));
      } else if (stats.latest > 7.5) {
        chips.add(_InsightChip('pH 偏高（>7.5）', Icons.warning_amber_rounded, const Color(0xFFFFF8E1)));
      } else {
        chips.add(_InsightChip('pH 正常（5.5–7.5）', Icons.check_circle_outline, const Color(0xFFE8F5E9)));
      }
      break;

    case 'Soil Electrical Conductivity':
      if (stats.latest > 1000) {
        chips.add(_InsightChip('EC 過高（>1000，鹽害風險）', Icons.science_outlined, const Color(0xFFFFF8E1)));
      }
      break;

    default:
      if (stats.latest >= hi) {
        chips.add(_InsightChip('目前偏高（相對）', Icons.trending_up, const Color(0xFFE8F5E9)));
      } else if (stats.latest <= lo) {
        chips.add(_InsightChip('目前偏低（相對）', Icons.trending_down, const Color(0xFFFFEBEE)));
      }
      break;
  }

  return chips;
}