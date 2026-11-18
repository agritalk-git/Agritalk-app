import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:chcg_iot_app/core/api_service.dart';

class GrapeDiseasePage extends StatefulWidget {
  const GrapeDiseasePage({super.key});

  @override
  State<GrapeDiseasePage> createState() => _GrapeDiseasePageState();
}

class _GrapeDiseasePageState extends State<GrapeDiseasePage> {
  final apiService = ApiService();

  // 兩個場域
  static const _groupA = _GroupOption(
    uuid: 'f42a1553-591f-4ad7-8167-ae1ed4e6b6cd',
    label: '彰化縣溪湖鎮葡萄',
  );
  static const _groupB = _GroupOption(
    uuid: '7e98412d-117e-4fff-86a3-d0bd506173fe',
    label: '彰化縣大村鄉葡萄',
  );

  // 即時資料（顯示在卡片上方）
  Map<String, dynamic>? thripsA, rotA, powderyA;
  Map<String, dynamic>? thripsB, rotB, powderyB;

  // 歷史資料（畫圖）
  List<ChartData> thripsHistA = [];
  List<ChartData> thripsHistB = [];
  List<ChartData> rotHistA = [];
  List<ChartData> rotHistB = [];
  List<ChartData> powderyHistA = [];
  List<ChartData> powderyHistB = [];

  bool loading = true;
  String? loadError;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  /// 包一層：量測每支 API 的時間並回傳結果
  Future<T?> _timed<T>({
    required String label,
    required Future<T?> Function() run,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final result = await run();
      sw.stop();
      print('[TIMING] $label -> ${sw.elapsedMilliseconds} ms');
      return result;
    } catch (e) {
      sw.stop();
      print('[TIMING][ERROR] $label -> ${sw.elapsedMilliseconds} ms, error: $e');
      rethrow;
    }
  }

  Future<void> _fetchAll() async {
    setState(() {
      loading = true;
      loadError = null;
    });

    try {
      // 兩個場域 × (即時3 + 歷史3) = 12 支請求併發
      final futures = await Future.wait([
        // group A 即時
        _timed<Map<String, dynamic>?>(
          label: '${_groupA.label} - 即時 小黃薊馬',
          run: () => apiService.fetchGroupScore(
            groupUUID: _groupA.uuid, fruit: '葡萄', disease: '小黃薊馬',
          ),
        ),
        _timed<Map<String, dynamic>?>(
          label: '${_groupA.label} - 即時 晚腐病',
          run: () => apiService.fetchGroupScore(
            groupUUID: _groupA.uuid, fruit: '葡萄', disease: '晚腐病',
          ),
        ),
        _timed<Map<String, dynamic>?>(
          label: '${_groupA.label} - 即時 白粉病',
          run: () => apiService.fetchGroupScore(
            groupUUID: _groupA.uuid, fruit: '葡萄', disease: '白粉病',
          ),
        ),
        // group A 歷史
        _timed<List<dynamic>?>(
          label: '${_groupA.label} - 歷史 小黃薊馬',
          run: () => apiService.fetchGroupScoreHistory(
            groupUUID: _groupA.uuid, fruit: '葡萄', disease: '小黃薊馬',
          ),
        ),
        _timed<List<dynamic>?>(
          label: '${_groupA.label} - 歷史 晚腐病',
          run: () => apiService.fetchGroupScoreHistory(
            groupUUID: _groupA.uuid, fruit: '葡萄', disease: '晚腐病',
          ),
        ),
        _timed<List<dynamic>?>(
          label: '${_groupA.label} - 歷史 白粉病',
          run: () => apiService.fetchGroupScoreHistory(
            groupUUID: _groupA.uuid, fruit: '葡萄', disease: '白粉病',
          ),
        ),

        // group B 即時
        _timed<Map<String, dynamic>?>(
          label: '${_groupB.label} - 即時 小黃薊馬',
          run: () => apiService.fetchGroupScore(
            groupUUID: _groupB.uuid, fruit: '葡萄', disease: '小黃薊馬',
          ),
        ),
        _timed<Map<String, dynamic>?>(
          label: '${_groupB.label} - 即時 晚腐病',
          run: () => apiService.fetchGroupScore(
            groupUUID: _groupB.uuid, fruit: '葡萄', disease: '晚腐病',
          ),
        ),
        _timed<Map<String, dynamic>?>(
          label: '${_groupB.label} - 即時 白粉病',
          run: () => apiService.fetchGroupScore(
            groupUUID: _groupB.uuid, fruit: '葡萄', disease: '白粉病',
          ),
        ),
        // group B 歷史
        _timed<List<dynamic>?>(
          label: '${_groupB.label} - 歷史 小黃薊馬',
          run: () => apiService.fetchGroupScoreHistory(
            groupUUID: _groupB.uuid, fruit: '葡萄', disease: '小黃薊馬',
          ),
        ),
        _timed<List<dynamic>?>(
          label: '${_groupB.label} - 歷史 晚腐病',
          run: () => apiService.fetchGroupScoreHistory(
            groupUUID: _groupB.uuid, fruit: '葡萄', disease: '晚腐病',
          ),
        ),
        _timed<List<dynamic>?>(
          label: '${_groupB.label} - 歷史 白粉病',
          run: () => apiService.fetchGroupScoreHistory(
            groupUUID: _groupB.uuid, fruit: '葡萄', disease: '白粉病',
          ),
        ),
      ]);

      if (!mounted) return;

      // 依序取回
      thripsA = futures[0] as Map<String, dynamic>?;
      rotA = futures[1] as Map<String, dynamic>?;
      powderyA = futures[2] as Map<String, dynamic>?;

      final histThripsARaw = futures[3] as List<dynamic>?;
      final histRotARaw = futures[4] as List<dynamic>?;
      final histPowderyARaw = futures[5] as List<dynamic>?;

      thripsB = futures[6] as Map<String, dynamic>?;
      rotB = futures[7] as Map<String, dynamic>?;
      powderyB = futures[8] as Map<String, dynamic>?;

      final histThripsBRaw = futures[9] as List<dynamic>?;
      final histRotBRaw = futures[10] as List<dynamic>?;
      final histPowderyBRaw = futures[11] as List<dynamic>?;

      List<ChartData> toChart(List<dynamic>? raw) {
        if (raw == null) return [];
        return raw.map<ChartData>((e) {
          final t = DateTime.parse(e['time'].toString());
          final v = double.tryParse(e['score']?.toString() ?? '0') ?? 0.0;
          return ChartData(t, v);
        }).toList();
      }

      setState(() {
        thripsHistA = toChart(histThripsARaw);
        thripsHistB = toChart(histThripsBRaw);
        rotHistA = toChart(histRotARaw);
        rotHistB = toChart(histRotBRaw);
        powderyHistA = toChart(histPowderyARaw);
        powderyHistB = toChart(histPowderyBRaw);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = '資料載入失敗：$e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loadError!)),
      );
    }
  }

  Future<void> _onRefresh() async => _fetchAll();

  String getRiskLabel(double score) {
    if (score >= 60) return "高";
    if (score >= 30) return "中";
    return "低";
  }

  Color getRiskColor(double score) {
    if (score >= 60) return Colors.red;
    if (score >= 30) return Colors.yellow;
    return Colors.green;
  }

  Widget _buildCombinedCard({
    required String title,
    required Map<String, dynamic>? currentA,
    required Map<String, dynamic>? currentB,
    required List<ChartData> histA,
    required List<ChartData> histB,
    required String labelA,
    required String labelB,
  }) {

    // 分別抓兩邊分數
    final double scoreA = (currentA?['score'] ?? 0).toDouble();
    final double scoreB = (currentB?['score'] ?? 0).toDouble();
    final String scoreNameA = getRiskLabel(scoreA);
    final String scoreNameB = getRiskLabel(scoreB);


    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 標題
          Row(
            children: [
              const Icon(Icons.bug_report, color: Color(0xFF7B4DBB)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7B4DBB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 兩個鄉鎮即時分數對照
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.indigo),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$labelA：${scoreNameA}',
                  style: TextStyle(
                    fontSize: 14,
                    color: getRiskColor(scoreA),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.location_on, color: Colors.indigo),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$labelB：${scoreNameB}',
                  style: TextStyle(
                    fontSize: 14,
                    color: getRiskColor(scoreB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 圖表（兩條線疊在同一張）
          (histA.isEmpty && histB.isEmpty)
              ? const Text('無歷史資料', style: TextStyle(color: Colors.grey))
              : SizedBox(
                  height: 260,
                  child: SfCartesianChart(
                    legend: const Legend(isVisible: true, position: LegendPosition.bottom),
                    primaryXAxis: DateTimeAxis(
                      dateFormat: DateFormat('MM/dd'),
                      intervalType: DateTimeIntervalType.days,
                    ),
                    primaryYAxis: NumericAxis(
                      title: AxisTitle(text: '風險指數(%)'),
                      minimum: 0,
                      maximum: 100,
                    ),
                    tooltipBehavior: TooltipBehavior(
                      enable: true,
                      format: 'series.name\n{point.x} : {point.y}%',
                    ),
                    zoomPanBehavior: ZoomPanBehavior(
                      enablePinching: true,
                      enablePanning: true,
                      enableDoubleTapZooming: true,
                    ),
                    series: <CartesianSeries>[
                      LineSeries<ChartData, DateTime>(
                        name: labelA,
                        dataSource: histA,
                        xValueMapper: (ChartData d, _) => d.time,
                        yValueMapper: (ChartData d, _) => d.value,
                        // 不指定顏色：交由套件自動分色
                        markerSettings: const MarkerSettings(isVisible: true),
                      ),
                      LineSeries<ChartData, DateTime>(
                        name: labelB,
                        dataSource: histB,
                        xValueMapper: (ChartData d, _) => d.time,
                        yValueMapper: (ChartData d, _) => d.value,
                        markerSettings: const MarkerSettings(isVisible: true),
                      ),
                    ],
                  ),
                ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelA = _groupA.label;
    final labelB = _groupB.label;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B4DBB),
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '葡萄雲 - 病蟲害預測（雙鄉鎮同圖）',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (loadError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(loadError!, style: const TextStyle(color: Colors.red)),
                    ),

                  // 小黃薊馬：兩鄉鎮同一張圖
                  _buildCombinedCard(
                    title: '小黃薊馬',
                    currentA: thripsA,
                    currentB: thripsB,
                    histA: thripsHistA,
                    histB: thripsHistB,
                    labelA: labelA,
                    labelB: labelB,
                  ),

                  // 晚腐病：兩鄉鎮同一張圖
                  _buildCombinedCard(
                    title: '晚腐病',
                    currentA: rotA,
                    currentB: rotB,
                    histA: rotHistA,
                    histB: rotHistB,
                    labelA: labelA,
                    labelB: labelB,
                  ),

                  // 白粉病：兩鄉鎮同一張圖
                  _buildCombinedCard(
                    title: '白粉病',
                    currentA: powderyA,
                    currentB: powderyB,
                    histA: powderyHistA,
                    histB: powderyHistB,
                    labelA: labelA,
                    labelB: labelB,
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

// ===== Models & Helpers =====

class ChartData {
  final DateTime time;
  final double value;
  ChartData(this.time, this.value);
}

class _GroupOption {
  final String uuid;
  final String label;
  const _GroupOption({required this.uuid, required this.label});
}
