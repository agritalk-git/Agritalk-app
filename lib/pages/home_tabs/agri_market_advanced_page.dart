// lib/pages/home_tabs/agri_market_advanced_page.dart
import 'package:flutter/material.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

const Color _primaryColor = Color(0xFF7B4DBB);

class AgriMarketAdvancedPage extends StatefulWidget {
  const AgriMarketAdvancedPage({super.key});

  @override
  State<AgriMarketAdvancedPage> createState() => _AgriMarketAdvancedPageState();
}

class _AgriMarketAdvancedPageState extends State<AgriMarketAdvancedPage> {
  final moaApi = MoaApiService();

  // 查詢條件
  String _type = 'Veg'; // Veg / Fruit / Flower
  String? _marketName; // MarketName
  String? _cropCode; // CropCode

  // 可輸入搜尋
  final _marketCtrl = TextEditingController();
  final _cropCtrl = TextEditingController();

  // 日期區間（預設近 30 天）
  late DateTime _endDate;
  late DateTime _startDate;

  // UI state
  bool _loading = false;
  String? _error;

  // options
  List<Map<String, dynamic>> markets = [];
  List<Map<String, dynamic>> crops = [];

  // 結果
  List<PricePoint> points = [];
  PricePoint? latestPoint; // 最新一筆（日期最大）
  PricePoint? prevPoint; // 最新前一筆（用來算漲跌）

  // 圖表 Tooltip
  late TooltipBehavior _tooltip;

  @override
  void initState() {
    super.initState();
    _tooltip = TooltipBehavior(enable: true);

    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 30));

    _loadInit();
  }

  @override
  void dispose() {
    _marketCtrl.dispose();
    _cropCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      crops = await moaApi.fetchCropTypes();
      await _loadMarkets();
    } catch (e) {
      _error = '初始化失敗：$e';
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMarkets() async {
    markets = await moaApi.fetchMarkets(cropMarketType: _type);

    // 切換類型後，清空市場選擇
    _marketName = null;
    _marketCtrl.text = '';

    setState(() {});
  }

  // ----------------------------
  // 日期：轉成民國格式 115/01/07
  // ----------------------------
  String _toRoc(DateTime d) {
    final rocYear = d.year - 1911;
    String mm = d.month.toString().padLeft(2, '0');
    String dd = d.day.toString().padLeft(2, '0');
    return '$rocYear/$mm/$dd';
  }

  // API 回傳 TransDate 可能長這樣：115.01.07 或 115/01/07
  DateTime _parseTransDate(dynamic v) {
    final s0 = (v ?? '').toString().trim();
    if (s0.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);

    final s = s0.replaceAll('.', '/'); // 115.01.07 -> 115/01/07
    final parts = s.split('/');
    if (parts.length != 3) return DateTime.fromMillisecondsSinceEpoch(0);

    final rocY = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 1;
    final d = int.tryParse(parts[2]) ?? 1;

    return DateTime(rocY + 1911, m, d);
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      helpText: '選擇查詢區間',
      cancelText: '取消',
      confirmText: '確定',
    );

    if (picked == null) return;

    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
    });
  }

  bool get _canQuery => !_loading && _marketName != null && _cropCode != null;

Future<void> _query() async {
  if (!_canQuery) return;

  setState(() {
    _loading = true;
    _error = null;
    points = [];
    latestPoint = null;
    prevPoint = null;
  });

  try {
    final data = await moaApi.fetchTransactions(
      cropCode: _cropCode!,
      marketName: _marketName!, // 你目前用 marketName 塞 MarketCode（照你的 API）
      startDate: _toRoc(_startDate),
      endDate: _toRoc(_endDate),
      tcType: _type,
    );

    final tmp = <PricePoint>[];

    for (final e in data) {
      final dt = _parseTransDate(e['TransDate']);

      final avg = (e['Avg_Price'] as num?)?.toDouble() ?? 0.0;
      final upper = (e['Upper_Price'] as num?)?.toDouble() ?? 0.0;
      final middle = (e['Middle_Price'] as num?)?.toDouble() ?? 0.0;
      final lower = (e['Lower_Price'] as num?)?.toDouble() ?? 0.0;

      // ✅ 你問的 qty 這行就放在這裡
      final qty = (e['Trans_Quantity'] as num?)?.toDouble() ?? 0.0;

      tmp.add(
        PricePoint(
          date: dt,
          avg: avg,
          upper: upper,
          middle: middle,
          lower: lower,
          qty: qty,
          up: null, // 先放 null，下面再依前一點算紅綠
        ),
      );
    }

    // 依日期排序（舊 -> 新）
    tmp.sort((a, b) => a.date.compareTo(b.date));

    // 設定漲跌（跟前一點 avg 比）
    for (int i = 0; i < tmp.length; i++) {
      if (i == 0) {
        tmp[i] = tmp[i].copyWith(up: null);
      } else {
        final up = tmp[i].avg >= tmp[i - 1].avg;
        tmp[i] = tmp[i].copyWith(up: up);
      }
    }

    PricePoint? latest;
    PricePoint? prev;
    if (tmp.isNotEmpty) {
      latest = tmp.last;
      if (tmp.length >= 2) prev = tmp[tmp.length - 2];
    }

    setState(() {
      points = tmp;
      latestPoint = latest;
      prevPoint = prev;
    });
  } catch (e) {
    setState(() => _error = '查詢失敗：$e');
  } finally {
    setState(() => _loading = false);
  }
}

  // ----------------------------
  // 可輸入搜尋：市場
  // ----------------------------
  Widget _marketAutocomplete() {
    final marketNames =
        markets
            .map((m) => (m['MarketName'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toList();

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _marketCtrl.text),
      optionsBuilder: (TextEditingValue text) {
        final q = text.text.trim();
        if (q.isEmpty) return marketNames.take(50);
        return marketNames.where((s) => s.contains(q)).take(50);
      },
      onSelected: (v) {
        setState(() => _marketName = v);
        _marketCtrl.text = v;
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        controller.text = _marketCtrl.text;
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );

        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: '市場（可輸入搜尋）',
            hintText: '例如：台北一',
            prefixIcon: const Icon(Icons.storefront),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onChanged: (v) {
            _marketCtrl.text = v;
            setState(() => _marketName = null);
          },
        );
      },
    );
  }

  // ----------------------------
  // 可輸入搜尋：產品
  // ----------------------------
  Widget _cropAutocomplete() {
    final cropOptions =
        crops
            .map((c) {
              final code = (c['CropCode'] ?? '').toString();
              final name = (c['CropName'] ?? '').toString();
              return _CropOption(code: code, name: name);
            })
            .where((c) => c.code.isNotEmpty && c.name.isNotEmpty)
            .toList();

    return Autocomplete<_CropOption>(
      initialValue: TextEditingValue(text: _cropCtrl.text),
      optionsBuilder: (TextEditingValue text) {
        final q = text.text.trim();
        if (q.isEmpty) return cropOptions.take(50);
        return cropOptions
            .where((c) {
              return c.code.contains(q) ||
                  c.name.contains(q) ||
                  c.label.contains(q);
            })
            .take(50);
      },
      displayStringForOption: (o) => o.label,
      onSelected: (o) {
        setState(() => _cropCode = o.code);
        _cropCtrl.text = o.label;
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        controller.text = _cropCtrl.text;
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );

        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: '產品（可輸入搜尋）',
            hintText: '輸入代碼或名稱，例如：11 或 椰子',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onChanged: (v) {
            _cropCtrl.text = v;
            setState(() => _cropCode = null);
          },
        );
      },
    );
  }

  // ----------------------------
  // Header：最新價格資訊（紅綠、漲跌）
  // ----------------------------
 Widget _latestHeader() {
  final latest = latestPoint;
  if (latest == null) return const SizedBox.shrink();

  final prev = prevPoint;

  final avg = latest.avg;
  final upper = latest.upper;
  final middle = latest.middle;
  final lower = latest.lower;
  final qty = latest.qty;

  final double diff = (prev == null) ? 0.0 : (avg - prev.avg);
  final double diffPct = (prev == null || prev.avg == 0)
      ? 0.0
      : (diff / prev.avg * 100.0);

  final bool isUp = prev == null ? true : diff >= 0;
  final color = isUp ? Colors.red : Colors.green;

  return _infoCard(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 市場 + 日期
        Row(
          children: [
            Text(
              _marketName ?? '',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '最新（${_fmtDate(latest.date)}）',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // 均價 + 漲跌
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              avg.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              color: color,
              size: 28,
            ),
            const SizedBox(width: 4),
            if (prev != null)
              Text(
                '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(2)} '
                '(${diffPct >= 0 ? '+' : ''}${diffPct.toStringAsFixed(2)}%)',
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const Spacer(),
            Text(
              '量 ${qty.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Upper / Middle / Lower
        Row(
          children: [
            _priceKV('上', upper),
            _priceKV('中', middle),
            _priceKV('下', lower),
          ],
        ),
      ],
    ),
  );
}

  String _fmtDate(DateTime d) {
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  // ----------------------------
  // 主圖表：上折線（均價），下長條（量）
  // ----------------------------
  Widget _chart() {
    if (_loading) return const SizedBox(height: 420);

    if (points.isEmpty) {
      return _infoCard(
        child: const Text(
          '此區間查無資料，請調整日期或條件。',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    // 價格軸 range
    final avgVals = points.map((p) => p.avg).toList();
    final minAvg = avgVals.reduce((a, b) => a < b ? a : b);
    final maxAvg = avgVals.reduce((a, b) => a > b ? a : b);
    final pad = (maxAvg - minAvg) * 0.15;
    final minY = (minAvg - pad).clamp(0, double.infinity).toDouble();
    final maxY = (maxAvg + pad).toDouble();

    // 量軸 range
    final qtyVals = points.map((p) => p.qty).toList();
    final maxQty = qtyVals.reduce((a, b) => a > b ? a : b).toDouble();
    final qtyMax = (maxQty * 1.25).toDouble();

    return _infoCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: SizedBox(
        height: 420,
        child: SfCartesianChart(
          tooltipBehavior: _tooltip,
          plotAreaBorderWidth: 0,

          // X 軸共用
          primaryXAxis: DateTimeAxis(
            majorGridLines: const MajorGridLines(width: 0),
          ),

          // 左邊：價格
          primaryYAxis: NumericAxis(
            minimum: minY,
            maximum: maxY,
            axisLine: const AxisLine(width: 0),
            majorTickLines: const MajorTickLines(size: 0),
            labelFormat: '{value}',
          ),

          // 右邊：量（次座標軸）
          axes: <ChartAxis>[
            NumericAxis(
              name: 'qtyAxis',
              opposedPosition: true,
              minimum: 0,
              maximum: qtyMax,
              axisLine: const AxisLine(width: 0),
              majorTickLines: const MajorTickLines(size: 0),
              majorGridLines: const MajorGridLines(width: 0),
              labelFormat: '{value}',
            ),
          ],

          series: <CartesianSeries<PricePoint, DateTime>>[
            // ===== 量：長條（用 qtyAxis）=====
            ColumnSeries<PricePoint, DateTime>(
              dataSource: points,
              xValueMapper: (p, _) => p.date,
              yValueMapper: (p, _) => p.qty,
              yAxisName: 'qtyAxis',
              borderRadius: const BorderRadius.all(Radius.circular(6)),
              pointColorMapper: (p, _) {
                if (p.up == null) return Colors.black26;
                return (p.up == true) ? Colors.red : Colors.green;
              },
            ),

            // ===== 價格：灰色底線 =====
            LineSeries<PricePoint, DateTime>(
              dataSource: points,
              xValueMapper: (p, _) => p.date,
              yValueMapper: (p, _) => p.avg,
              width: 2,
              color: Colors.black26,
              markerSettings: const MarkerSettings(isVisible: false),
            ),

            // ===== 價格：上漲點（紅）=====
            ScatterSeries<PricePoint, DateTime>(
              dataSource: points.where((p) => p.up == true).toList(),
              xValueMapper: (p, _) => p.date,
              yValueMapper: (p, _) => p.avg,
              color: Colors.red,
              markerSettings: const MarkerSettings(
                isVisible: true,
                width: 8,
                height: 8,
                shape: DataMarkerType.circle,
              ),
            ),

            // ===== 價格：下跌點（綠）=====
            ScatterSeries<PricePoint, DateTime>(
              dataSource: points.where((p) => p.up == false).toList(),
              xValueMapper: (p, _) => p.date,
              yValueMapper: (p, _) => p.avg,
              color: Colors.green,
              markerSettings: const MarkerSettings(
                isVisible: true,
                width: 8,
                height: 8,
                shape: DataMarkerType.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({required Widget child, EdgeInsets? padding}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(14),
        child: child,
      ),
    );
  }

  String _typeLabel(String v) {
    switch (v) {
      case 'Veg':
        return '蔬菜';
      case 'Fruit':
        return '水果';
      case 'Flower':
        return '花卉';
    }
    return v;
  }

  // 遮罩 loading（轉圈圈）
  Widget _loadingOverlay() {
    if (!_loading) return const SizedBox.shrink();
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.25),
        child: const Center(
          child: Card(
            elevation: 8,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  SizedBox(width: 12),
                  Text('查詢中...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canQuery = _canQuery;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '進階行情查詢',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      backgroundColor: const Color(0xFFF6F6FA),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              // ---- 查詢條件卡 ----
              _infoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '查詢條件',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 類型 Segmented
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Veg', label: Text('蔬菜')),
                        ButtonSegment(value: 'Fruit', label: Text('水果')),
                        ButtonSegment(value: 'Flower', label: Text('花卉')),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) async {
                        _type = s.first;
                        await _loadMarkets();
                      },
                    ),

                    const SizedBox(height: 12),

                    _marketAutocomplete(),
                    const SizedBox(height: 12),
                    _cropAutocomplete(),

                    const SizedBox(height: 12),

                    // 日期區間
                    InkWell(
                      onTap: _pickDateRange,
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: '日期區間（可自訂）',
                          prefixIcon: const Icon(Icons.date_range),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          '${_fmtDate(_startDate)}  →  ${_fmtDate(_endDate)}',
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: canQuery ? _query : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: _primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          canQuery ? '查詢 (${_typeLabel(_type)})' : '請先選市場與產品',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              if (_error != null)
                _infoCard(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

              // ---- 最新資訊 ----
              _latestHeader(),

              const SizedBox(height: 12),

              // ---- 圖表 ----
              _chart(),
            ],
          ),

          // loading overlay
          _loadingOverlay(),
        ],
      ),
    );
  }
}

// -------------------------------------
// Model
// -------------------------------------
class PricePoint {
  final DateTime date;
  final double avg;
  final double upper;
  final double middle;
  final double lower;
  final double qty;

  /// null = 第一筆沒得比；true=漲(紅) false=跌(綠)
  final bool? up;

  const PricePoint({
    required this.date,
    required this.avg,
    required this.upper,
    required this.middle,
    required this.lower,
    required this.qty,
    required this.up,
  });

  PricePoint copyWith({bool? up}) {
    return PricePoint(
      date: date,
      avg: avg,
      upper: upper,
      middle: middle,
      lower: lower,
      qty: qty,
      up: up,
    );
  }
}

class _CropOption {
  final String code;
  final String name;
  const _CropOption({required this.code, required this.name});
  String get label => '$code $name';
}


Widget _priceKV(String label, double value) {
  return Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 2),
        Text(
          value.toStringAsFixed(2),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}