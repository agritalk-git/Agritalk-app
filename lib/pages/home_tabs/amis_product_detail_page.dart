import 'package:flutter/material.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

const Color _primaryColor = Color(0xFF7B4DBB);

class HistoryPoint {
  final DateTime date;
  final double avgPrice;
  final String market;

  HistoryPoint(this.date, this.avgPrice, this.market);
}

class AmisProductDetailPage extends StatefulWidget {
  final String plantType; // Veg / Fruit / Flower
  final String plantCode; // 例如 "11"
  final String productName; // 顯示用，例如 "11 椰子"

  const AmisProductDetailPage({
    super.key,
    required this.plantType,
    required this.plantCode,
    required this.productName,
  });

  @override
  State<AmisProductDetailPage> createState() => _AmisProductDetailPageState();
}

class _AmisProductDetailPageState extends State<AmisProductDetailPage> {
  final api = ApiService();

  bool _loading = false;
  String? _error;

  // 歷史資料（列表 + 圖表共用）
  List<Map<String, dynamic>> _historyItems = [];

  // 圖表：目前被勾選要顯示的市場（空集合代表還沒初始化）
  Set<String> _selectedMarkets = {};

  // Syncfusion 圖表互動
  late ZoomPanBehavior _zoomPanBehavior;
  late TooltipBehavior _tooltipBehavior;

  // 日期範圍（預設近 7 天）
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();

    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 7));

    _zoomPanBehavior = ZoomPanBehavior(
      enablePanning: true,
      enablePinching: true,
      enableDoubleTapZooming: true,
      zoomMode: ZoomMode.x, // 只在 X 軸方向縮放，比較符合時間序
    );

    _tooltipBehavior = TooltipBehavior(
      enable: true,
      shared: true, // 多條線同一日期一起顯示
    );

    _fetchHistory();
  }

  /// 西元日期 → ROC 114/12/09 格式
  String _formatToRoc(DateTime dt) {
    final y = dt.year - 1911;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      helpText: '選擇查詢日期區間',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchHistory();
    }
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final startStr = _formatToRoc(_startDate);
      final endStr = _formatToRoc(_endDate);
      print(widget.plantCode);

      final res = await api.fetchAmisHistory(
        widget.plantType,
        widget.plantCode,
        startStr,
        endStr,
      );

      final list = (res?['data'] ?? []) as List<dynamic>;

      final items =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // 依目前資料中的所有市場初始化 selectedMarkets
      final markets = items
          .map((e) => (e['市場'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toSet();

      setState(() {
        _historyItems = items;
        _selectedMarkets = markets; // 預設全部勾選
      });
    } catch (e) {
      setState(() {
        _error = '取得歷史行情失敗：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F3FA),
        appBar: AppBar(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          title: Text(
            widget.productName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: [
              Tab(text: '每日歷史行情'),
              Tab(text: '價格趨勢圖'),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildDateRangeBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : TabBarView(
                          children: [
                            _buildHistoryListTab(),
                            _buildChartTab(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// 上方日期區塊（兩個 tab 共用）
  Widget _buildDateRangeBar() {
    final style = const TextStyle(fontSize: 14);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 18, color: _primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '查詢區間：${_formatToRoc(_startDate)} ～ ${_formatToRoc(_endDate)}',
              style: style,
            ),
          ),
          TextButton(
            onPressed: _pickDateRange,
            child: const Text('變更日期'),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 44, color: Colors.red.shade400),
            const SizedBox(height: 10),
            Text(
              _error ?? '發生錯誤',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _primaryColor,
              ),
              onPressed: _fetchHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('重新整理'),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------ Tab1：每日歷史行情列表 ------------------

  Widget _buildHistoryListTab() {
    if (_historyItems.isEmpty) {
      return const Center(
        child: Text(
          '此區間內暫無行情資料。',
          style: TextStyle(color: Colors.grey, fontSize: 15),
        ),
      );
    }

    final reversed = _historyItems.reversed.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: _historyItems.length,
      itemBuilder: (_, i) => _buildHistoryCard(reversed[i]),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final date = (item['日期'] ?? '').toString();
    final market = (item['市場'] ?? '').toString();
    final product = (item['產品'] ?? '').toString();

    final high = (item['上價'] ?? '').toString();
    final mid = (item['中價'] ?? '').toString();
    final low = (item['下價'] ?? '').toString();
    final avg = (item['平均價_元每公斤'] ?? '').toString();

    final priceDelta = (item['價格較前一日_百分比'] ?? '').toString();
    final volume = (item['交易量_公斤'] ?? '').toString();
    final volumeDelta = (item['交易量較前一日_百分比'] ?? '').toString();

    Color deltaColor = Colors.grey;
    Color deltaBg = Colors.grey.withOpacity(0.1);
    IconData deltaIcon = Icons.horizontal_rule;

    if (priceDelta.contains('+')) {
      deltaColor = Colors.red.shade600;
      deltaBg = Colors.red.shade50;
      deltaIcon = Icons.trending_up;
    } else if (priceDelta.contains('-')) {
      deltaColor = Colors.green.shade700;
      deltaBg = Colors.green.shade50;
      deltaIcon = Icons.trending_down;
    }

    return Card(
      elevation: 2,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期 + 市場
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    market,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              product,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            // ✅ 中間：完全自適應（不省略、不 overflow）
LayoutBuilder(
  builder: (context, c) {
    final bool narrow = c.maxWidth < 320;

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '平均價（元/公斤）',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            avg,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ 上/中/下：用 Wrap 自動換行
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _kvText('上', high),
            _kvText('中', mid),
            _kvText('下', low),
          ],
        ),
        const SizedBox(height: 8),

        // ✅ 價較前一日：chip 也用 Wrap，避免擠爆
        Wrap(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: deltaBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(deltaIcon, size: 18, color: deltaColor),
                  const SizedBox(width: 6),
                  Text(
                    '價較前一日：$priceDelta%',
                    style: TextStyle(
                      fontSize: 13,
                      color: deltaColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );

    if (narrow) {
      // ✅ 窄螢幕：改上下排，100% 不會 overflow
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          left,
          const SizedBox(height: 10),
          right,
        ],
      );
    }

    // ✅ 寬度夠：左右排
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  },
),

            const SizedBox(height: 6),
            Wrap(
  spacing: 12,
  runSpacing: 6,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.scale_outlined,
          size: 18,
          color: Colors.grey.shade700,
        ),
        const SizedBox(width: 4),
        Text(
          '交易量：$volume 公斤',
          style: const TextStyle(fontSize: 13),
        ),
      ],
    ),

    Text(
      '量較前一日：$volumeDelta%',
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade700,
      ),
    ),
  ],
),

          ],
        ),
      ),
    );
  }

  // ------------------ Tab2：圖表（依市場分線） ------------------

  /// 解析 ROC 日期字串 → DateTime
  DateTime? _parseRocDate(String s) {
    final parts = s.split('/');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y + 1911, m, d);
  }

  Widget _buildChartTab() {
    if (_historyItems.isEmpty) {
      return const Center(
        child: Text(
          '此區間內暫無行情資料，無法繪製圖表。',
          style: TextStyle(color: Colors.grey, fontSize: 15),
        ),
      );
    }

    // 轉成 chart 用的資料
    final List<HistoryPoint> points = [];
    for (final item in _historyItems) {
      final dateStr = (item['日期'] ?? '').toString();
      final market = (item['市場'] ?? '').toString();
      final avgStr = (item['平均價_元每公斤'] ?? '').toString();

      final dt = _parseRocDate(dateStr);
      final avg = double.tryParse(avgStr.replaceAll(',', '').trim());
      if (dt == null || avg == null) continue;

      points.add(HistoryPoint(dt, avg, market));
    }

    if (points.isEmpty) {
      return const Center(
        child: Text(
          '目前無有效數值可繪製圖表。',
          style: TextStyle(color: Colors.grey, fontSize: 15),
        ),
      );
    }

    // 依市場分組
    final allMarkets = points.map((p) => p.market).toSet().toList()..sort();

    // 若 _selectedMarkets 是空的（理論上只會在第一次初始化前），就先全選
    final activeMarkets =
        _selectedMarkets.isEmpty ? allMarkets.toSet() : _selectedMarkets;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '價格趨勢（平均價，依市場區分線條）',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '顯示市場：',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 4),

              // 多選市場 checkbox（實作成 FilterChip，比較省空間）
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: allMarkets.map((m) {
                    final selected = activeMarkets.contains(m);
                    return FilterChip(
                      label: Text(
                        m,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: selected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedMarkets.add(m);
                          } else {
                            _selectedMarkets.remove(m);
                          }
                        });
                      },
                      selectedColor: _primaryColor.withOpacity(0.16),
                      checkmarkColor: _primaryColor,
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 12),

              // 圖表本體
              Expanded(
                child: SfCartesianChart(
                  zoomPanBehavior: _zoomPanBehavior,
                  tooltipBehavior: _tooltipBehavior,
                  legend: const Legend(
                    isVisible: true,
                    position: LegendPosition.bottom,
                    overflowMode: LegendItemOverflowMode.wrap,
                  ),
                  primaryXAxis: DateTimeAxis(
                    intervalType: DateTimeIntervalType.days,
                    majorGridLines: const MajorGridLines(width: 0),
                  ),
                  primaryYAxis: NumericAxis(
                    title: AxisTitle(text: '平均價（元/公斤）'),
                  ),
                  series: allMarkets
                      .where((m) => activeMarkets.contains(m))
                      .map((m) {
                    final dataForMarket =
                        points.where((p) => p.market == m).toList()
                          ..sort((a, b) => a.date.compareTo(b.date));
                    return LineSeries<HistoryPoint, DateTime>(
                      name: m,
                      dataSource: dataForMarket,
                      xValueMapper: (p, _) => p.date,
                      yValueMapper: (p, _) => p.avgPrice,
                      dataLabelSettings:
                          const DataLabelSettings(isVisible: false),
                      markerSettings: const MarkerSettings(isVisible: true),
                      enableTooltip: true,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _kvText(String k, String v) {
  return RichText(
    text: TextSpan(
      style: const TextStyle(
        fontSize: 13,
        color: Colors.black87,
        height: 1.2,
      ),
      children: [
        TextSpan(
          text: '$k：',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        TextSpan(text: v),
      ],
    ),
  );
}

