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
    final isLoggedIn =
        token != null && token.isNotEmpty && token != 'GUEST_MODE';

    final Map<String, Map<String, List<ChartData>>> nextGroupSeries = {};
    final Map<String, List<ChartData>> nextMyData = {};

    await Future.wait(
      features.map((feature) async {
        nextGroupSeries[feature] = {};

        // 1) 群組多地點並行抓
        final groupTasks =
            groups.map((g) async {
              final uuid = g['uuid']!;
              final label = g['label']!;

              final data = await apiService.fetchGroupObservation(
                groupUUID: uuid,
                featureEnglishName: feature,
                startTime: startTime,
                endTime: endTime,
                aggregate: "hours",
              );

              final points =
                  (data ?? [])
                      .map<ChartData>(
                        (item) => ChartData(
                          DateTime.parse(item['time']),
                          double.tryParse(item['value'].toString()) ?? 0,
                        ),
                      )
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

          nextMyData[feature] =
              (mydata ?? [])
                  .map<ChartData>(
                    (item) => ChartData(
                      DateTime.parse(item['time']),
                      double.tryParse(item['value'].toString()) ?? 0,
                    ),
                  )
                  .toList()
                ..sort((a, b) => a.time.compareTo(b.time));
        } else {
          nextMyData[feature] = const [];
        }
      }),
    );

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
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final bigText =
                            MediaQuery.textScaleFactorOf(context) >= 1.25;
                        final narrow = c.maxWidth < 360;
                        final stackVertical = bigText || narrow;

                        final startLabel =
                            '開始：${DateFormat('yyyy-MM-dd').format(startTime)}';
                        final endLabel =
                            '結束：${DateFormat('yyyy-MM-dd').format(endTime)}';

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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              minimumSize: const Size(0, 44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
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

class _FeatureChartState extends State<FeatureChart>
    with AutomaticKeepAliveClientMixin {
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

    final hasAnyData =
        seriesList.whereType<LineSeries<ChartData, DateTime>>().isNotEmpty;

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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '這個數值對番石榴有什麼意義？',
                    onPressed:
                        () => _showInfoSheet(
                          context,
                          widget.feature,
                          widget.title,
                        ),
                    icon: const Icon(Icons.info_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),

            
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
                  Text(
                    info.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
        watch:
            '<15℃ 時要注意寒害，可能出現新梢生長停滯、葉片紫紅、果實表皮受損出現紅點、花粉發芽率下降。>37℃ 時要注意熱障礙，花粉萌芽率降低，進而影響授粉。',
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
