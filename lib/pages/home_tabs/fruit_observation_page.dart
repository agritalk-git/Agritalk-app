import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:chcg_iot_app/core/api_service.dart';

class FruitObservationPage extends StatefulWidget {
  final String fruitName;
  final String groupUUID;

  const FruitObservationPage({
    super.key,
    required this.fruitName,
    required this.groupUUID,
  });

  @override
  State<FruitObservationPage> createState() => _FruitObservationPageState();
}

class _FruitObservationPageState extends State<FruitObservationPage> {
  static const _groupColor = Color(0xFF7B4DBB);

  static const _featureNames = <String, String>{
    'Temperature': '環境溫度(°C)',
    'Humidity': '環境相對濕度(%)',
    'Luminance': '照度(lux)',
    'Photosynthetically Active Radiation': 'PAR(光合作用有效輻射)',
    'Solar Radiation': '紫外線(UVI)',
    'Carbon Dioxide': '二氧化碳(ppm)',
    'Atmospheric Pressure': '大氣壓力(hPa)',
    'Precipitation': '時降雨量(mm/h)',
    'Soil Temperature': '土壤溫度(°C)',
    'Soil Moisture': '土壤濕度(%)',
    'Soil Electrical Conductivity': '土壤電導度(μS/cm)',
    'Potential of Hydrogen': '酸鹼度(pH)',
  };

  final _apiService = ApiService();
  DateTime startTime = DateTime.now().subtract(const Duration(days: 1));
  DateTime endTime = DateTime.now().add(const Duration(days: 1));
  bool loading = false;
  String? _error;
  Map<String, List<_ObservationPoint>> _groupData = {};
  Map<String, List<_ObservationPoint>> _myData = {};

  List<String> get _features => _featureNames.keys.toList();

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final hasUserFarm =
          token != null && token.isNotEmpty && token != 'GUEST_MODE';

      final groupResults = <String, List<_ObservationPoint>>{};
      final myResults = <String, List<_ObservationPoint>>{};

      await Future.wait(
        _features.map((feature) async {
          final groupFuture = _apiService.fetchGroupObservation(
            groupUUID: widget.groupUUID,
            featureEnglishName: feature,
            startTime: startTime,
            endTime: endTime,
            aggregate: 'hours',
          );

          final myFuture =
              hasUserFarm
                  ? _apiService.fetchMineRawData(
                    featureEnglishName: feature,
                    startTime: startTime,
                    endTime: endTime,
                    aggregate: 'hours',
                  )
                  : Future<List<dynamic>?>.value(null);

          final responses = await Future.wait<List<dynamic>?>([
            groupFuture,
            myFuture,
          ]);
          groupResults[feature] = _parseObservations(responses[0]);
          myResults[feature] = _parseObservations(responses[1]);
        }),
      );

      if (!mounted) return;
      setState(() {
        _groupData = groupResults;
        _myData = myResults;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '觀測資料載入失敗：$error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<_ObservationPoint> _parseObservations(List<dynamic>? data) {
    return (data ?? [])
        .whereType<Map>()
        .map((item) {
          final time = DateTime.tryParse(item['time']?.toString() ?? '');
          final value = double.tryParse(item['value']?.toString() ?? '');
          if (time == null || value == null) return null;
          return _ObservationPoint(time, value);
        })
        .whereType<_ObservationPoint>()
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  Future<void> _selectDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? startTime : endTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3)),
    );
    if (picked == null || !mounted) return;

    setState(() {
      if (isStart) {
        startTime = DateTime(picked.year, picked.month, picked.day);
        if (endTime.isBefore(startTime)) {
          endTime = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        }
      } else {
        endTime = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        if (endTime.isBefore(startTime)) {
          startTime = DateTime(picked.year, picked.month, picked.day);
        }
      }
    });
    _fetchAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _groupColor,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          '${widget.fruitName}雲 - 環境數據圖表',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
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
                      builder: (context, constraints) {
                        final largeText =
                            MediaQuery.textScalerOf(context).scale(1) >= 1.25;
                        final stackVertically =
                            largeText || constraints.maxWidth < 360;

                        Widget dateButton({
                          required bool isStart,
                          required String label,
                        }) {
                          return ElevatedButton.icon(
                            onPressed: () => _selectDate(isStart: isStart),
                            icon: Icon(
                              isStart
                                  ? Icons.calendar_month_rounded
                                  : Icons.event_rounded,
                              size: 18,
                            ),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(label),
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

                        final startButton = dateButton(
                          isStart: true,
                          label:
                              '開始：${DateFormat('yyyy-MM-dd').format(startTime)}',
                        );
                        final endButton = dateButton(
                          isStart: false,
                          label:
                              '結束：${DateFormat('yyyy-MM-dd').format(endTime)}',
                        );

                        if (stackVertically) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              startButton,
                              const SizedBox(height: 10),
                              endButton,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: startButton),
                            const SizedBox(width: 12),
                            Expanded(child: endButton),
                          ],
                        );
                      },
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _features.length,
                      itemBuilder: (context, index) {
                        final feature = _features[index];
                        return _FruitFeatureChart(
                          key: ValueKey(feature),
                          feature: feature,
                          title: _featureNames[feature]!,
                          groupPoints: _groupData[feature] ?? const [],
                          myPoints: _myData[feature] ?? const [],
                          rangeStart: startTime,
                          rangeEnd: endTime,
                          fruitName: widget.fruitName,
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}

class _ObservationPoint {
  final DateTime time;
  final double value;

  const _ObservationPoint(this.time, this.value);
}

class _FruitFeatureChart extends StatefulWidget {
  final String feature;
  final String title;
  final List<_ObservationPoint> groupPoints;
  final List<_ObservationPoint> myPoints;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String fruitName;

  const _FruitFeatureChart({
    super.key,
    required this.feature,
    required this.title,
    required this.groupPoints,
    required this.myPoints,
    required this.rangeStart,
    required this.rangeEnd,
    required this.fruitName,
  });

  @override
  State<_FruitFeatureChart> createState() => _FruitFeatureChartState();
}

class _FruitFeatureChartState extends State<_FruitFeatureChart>
    with AutomaticKeepAliveClientMixin {
  late final TooltipBehavior _tooltip = TooltipBehavior(enable: true);

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final series = <CartesianSeries<_ObservationPoint, DateTime>>[];
    if (widget.groupPoints.isNotEmpty) {
      series.add(
        LineSeries<_ObservationPoint, DateTime>(
          dataSource: widget.groupPoints,
          xValueMapper: (point, _) => point.time,
          yValueMapper: (point, _) => point.value,
          name: widget.fruitName,
          color: const Color(0xFF7B4DBB),
          width: 2,
          markerSettings: const MarkerSettings(isVisible: true),
        ),
      );
    }
    if (widget.myPoints.isNotEmpty) {
      series.add(
        LineSeries<_ObservationPoint, DateTime>(
          dataSource: widget.myPoints,
          xValueMapper: (point, _) => point.time,
          yValueMapper: (point, _) => point.value,
          name: '我的數據',
          color: Colors.black,
          width: 2,
          markerSettings: const MarkerSettings(isVisible: true),
        ),
      );
    }

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
                    tooltip: '指標說明',
                    onPressed: () => _showInfo(context),
                    icon: const Icon(Icons.info_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (series.isEmpty)
                const Text('查無資料', style: TextStyle(color: Colors.grey))
              else
                SizedBox(
                  height: 260,
                  child: SfCartesianChart(
                    tooltipBehavior: _tooltip,
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
                    series: series,
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

  void _showInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const Text(
                  '此圖表顯示所選期間內的觀測資料。紫色代表群組來源；黑色代表帳號所屬農場的「我的數據」。可使用圖表縮放及平移查看資料。',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
