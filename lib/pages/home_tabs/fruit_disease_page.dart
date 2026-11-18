import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:chcg_iot_app/core/api_service.dart';

class FruitDiseasePage extends StatefulWidget {
  final String groupUUID;
  final String cropName;
  final String apiFruitName;
  final Map<String, String> apiFruitNameByDisease;
  final List<String> diseaseNames;
  final String groupLabel;

  const FruitDiseasePage({
    super.key,
    required this.groupUUID,
    required this.cropName,
    required this.apiFruitName,
    this.apiFruitNameByDisease = const {},
    required this.diseaseNames,
    required this.groupLabel,
  });

  @override
  State<FruitDiseasePage> createState() => _FruitDiseasePageState();
}

class _FruitDiseasePageState extends State<FruitDiseasePage> {
  static const _purple = Color(0xFF7B4DBB);

  final _apiService = ApiService();
  Map<String, Map<String, dynamic>?> _diseaseScores = {};
  Map<String, List<_FruitScorePoint>> _histories = {};
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<T?> _timed<T>({
    required String label,
    required Future<T?> Function() run,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await run();
      stopwatch.stop();
      debugPrint('[TIMING] $label -> ${stopwatch.elapsedMilliseconds} ms');
      return result;
    } catch (error) {
      stopwatch.stop();
      debugPrint(
        '[TIMING][ERROR] $label -> ${stopwatch.elapsedMilliseconds} ms, '
        'error: $error',
      );
      rethrow;
    }
  }

  Future<void> _fetchAll() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });

    if (widget.groupUUID.trim().isEmpty) {
      setState(() {
        _error = '尚未設定此作物的 groupUUID，暫時無法載入病蟲害預測。';
        _loading = false;
      });
      return;
    }

    try {
      final requests = <Future<Object?>>[];
      for (final diseaseName in widget.diseaseNames) {
        final apiFruitName =
            widget.apiFruitNameByDisease[diseaseName] ?? widget.apiFruitName;
        requests
          ..add(
            _timed<Map<String, dynamic>?>(
              label: '${widget.groupLabel} - 即時 $diseaseName',
              run:
                  () => _apiService.fetchGroupScore(
                    groupUUID: widget.groupUUID,
                    fruit: apiFruitName,
                    disease: diseaseName,
                  ),
            ),
          )
          ..add(
            _timed<List<dynamic>?>(
              label: '${widget.groupLabel} - 歷史 $diseaseName',
              run:
                  () => _apiService.fetchGroupScoreHistory(
                    groupUUID: widget.groupUUID,
                    fruit: apiFruitName,
                    disease: diseaseName,
                  ),
            ),
          );
      }

      final results = await Future.wait(requests);

      if (!mounted || requestId != _requestId) return;

      final diseaseScores = <String, Map<String, dynamic>?>{};
      final histories = <String, List<_FruitScorePoint>>{};
      for (var index = 0; index < widget.diseaseNames.length; index++) {
        final resultIndex = index * 2;
        final diseaseName = widget.diseaseNames[index];
        diseaseScores[diseaseName] =
            results[resultIndex] as Map<String, dynamic>?;
        histories[diseaseName] = _parseHistory(
          results[resultIndex + 1] as List<dynamic>?,
        );
      }

      setState(() {
        _diseaseScores = diseaseScores;
        _histories = histories;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = '病蟲害資料載入失敗：$error';
        _loading = false;
      });
    }
  }

  List<_FruitScorePoint> _parseHistory(List<dynamic>? raw) {
    return (raw ?? [])
        .whereType<Map>()
        .map((item) {
          final time = DateTime.tryParse(item['time']?.toString() ?? '');
          final score = _scoreAtMost100(item['score']);
          if (time == null || score == null) return null;
          return _FruitScorePoint(time, score);
        })
        .whereType<_FruitScorePoint>()
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  double? _scoreAtMost100(dynamic value) {
    final score = double.tryParse(value?.toString() ?? '');
    if (score == null) return null;
    return score > 100 ? 100 : score;
  }

  String _riskLabel(double score) {
    if (score >= 60) return '高';
    if (score >= 30) return '中';
    return '低';
  }

  Color _riskColor(double score) {
    if (score >= 60) return Colors.red;
    if (score >= 30) return Colors.yellow;
    return Colors.green;
  }

  Widget _buildDiseaseCard(
    String diseaseName,
    double? score,
    List<_FruitScorePoint> history,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bug_report, color: _purple),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    diseaseName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _purple,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.indigo),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    score == null
                        ? '${widget.groupLabel}：無即時分數'
                        : '${widget.groupLabel}：${_riskLabel(score)}'
                            '（${score.toStringAsFixed(1)}%）',
                    style: TextStyle(
                      fontSize: 14,
                      color: score == null ? Colors.grey : _riskColor(score),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (history.isEmpty)
              const Text('無歷史資料', style: TextStyle(color: Colors.grey))
            else
              SizedBox(
                height: 260,
                child: SfCartesianChart(
                  legend: const Legend(
                    isVisible: true,
                    position: LegendPosition.bottom,
                  ),
                  primaryXAxis: DateTimeAxis(
                    dateFormat: DateFormat('MM/dd'),
                    intervalType: DateTimeIntervalType.days,
                  ),
                  primaryYAxis: NumericAxis(
                    title: const AxisTitle(text: '風險指數(%)'),
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
                  series: <CartesianSeries<_FruitScorePoint, DateTime>>[
                    LineSeries<_FruitScorePoint, DateTime>(
                      name: widget.groupLabel,
                      dataSource: history,
                      xValueMapper: (point, _) => point.time,
                      yValueMapper: (point, _) => point.score,
                      markerSettings: const MarkerSettings(isVisible: true),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          '${widget.cropName}雲 - 病蟲害預測',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ],
            ...widget.diseaseNames.map(
              (diseaseName) => _buildDiseaseCard(
                diseaseName,
                _scoreAtMost100(_diseaseScores[diseaseName]?['score']),
                _histories[diseaseName] ?? const [],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _FruitScorePoint {
  final DateTime time;
  final double score;

  const _FruitScorePoint(this.time, this.score);
}
