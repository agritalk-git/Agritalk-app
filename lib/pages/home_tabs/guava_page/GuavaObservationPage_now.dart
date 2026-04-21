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
    'Precipitation': '時降雨量(mm/h)',
    'Atmospheric Pressure': '大氣壓力(hPa)',
    'Soil Temperature': '土壤溫度(°C)',
    'Soil Moisture': '土壤濕度(%)',
    'Soil Electrical Conductivity': '土壤電導度(μS/cm)',
    'Potential of Hydrogen': '酸鹼度',
    'Temperature': '環境溫度(°C)',
    'Humidity': '環境相對濕度(%)',
    'Luminance': '照度(lux)',
    'Photosynthetically Active Radiation': '紅外線強度(lux)',
    'Solar Radiation': '紫外線(UVI)',
    'Carbon Dioxide': '二氧化碳(ppm)',
    'Wind Direction': '風向(°)',
    'Wind Speed': '風速(m/s)',
  };

  final List<String> features = const [
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
  final tooltipBehavior = TooltipBehavior(enable: true);

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

  // 先準備容器
  final Map<String, Map<String, List<ChartData>>> nextGroupSeries = {};
  final Map<String, List<ChartData>> nextMyData = {};

  // 每個 feature 都並行處理
  await Future.wait(features.map((feature) async {
    nextGroupSeries[feature] = {};

    // 1) 這個 feature 的 group 全部並行抓
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
          .toList();

      return MapEntry(label, points);
    }).toList();

    final groupResults = await Future.wait(groupTasks);
    for (final e in groupResults) {
      nextGroupSeries[feature]![e.key] = e.value;
    }

    // 2) 這個 feature 的 myData（可選）
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
          .toList();
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
      lastDate: DateTime.now(),
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
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  child: LayoutBuilder(
    builder: (context, c) {
      // ✅ 小寬度 / 大字體 → 直接改直向堆疊
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
            minimumSize: const Size(0, 44), // ✅ 觸控高度
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
        );
      }

      if (stackVertical) {
        // ✅ 直向：兩顆按鈕疊起來
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

      // ✅ 橫向：同一排各佔一半
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
                          groupSeries: seriesMap, // 多條群組線
                          myData: myData, // 我的數據
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

  /// 群組多地點的 series：key=地點名稱、value=資料點
  final Map<String, List<ChartData>> groupSeries;

  /// 我的資料（若有登入）
  final List<ChartData> myData;

  const FeatureChart({
    super.key,
    required this.feature,
    required this.title,
    required this.groupSeries,
    required this.myData,
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
    super.build(context); // for AutomaticKeepAliveClientMixin

    // 準備要畫的 series（群組多條 + 我的數據一條）
    final List<CartesianSeries<ChartData, DateTime>> seriesList = [];

    // 群組多條（不同地點）
    widget.groupSeries.forEach((label, points) {
      if (points.isEmpty) return;
      seriesList.add(
        LineSeries<ChartData, DateTime>(
          dataSource: points,
          xValueMapper: (d, _) => d.time,
          yValueMapper: (d, _) => d.value,
          width: 2,
          name: '$label',
          markerSettings: const MarkerSettings(isVisible: true),
        ),
      );
    });

    // 我的數據
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
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (!hasAnyData)
                const Text('查無資料', style: TextStyle(color: Colors.grey))
              else
                SizedBox(
                  height: 240,
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
                    legend: Legend(
                      isVisible: true,
                      position: LegendPosition.bottom,
                      overflowMode: LegendItemOverflowMode.wrap, // ✅ 允許換行
                      toggleSeriesVisibility: true, // 點 Legend 可顯示/隱藏
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
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