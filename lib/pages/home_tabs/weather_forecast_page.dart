// lib/pages/home_tabs/weather_forecast_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class WeatherForecastPage extends StatefulWidget {
  const WeatherForecastPage({super.key});

  @override
  State<WeatherForecastPage> createState() => _WeatherForecastPageState();
}

class _WeatherForecastPageState extends State<WeatherForecastPage> {
  final apiService = ApiService();

  // 跟你 App 其他頁一致（紫色系）
  final Color _primaryColor = const Color(0xFF7B4DBB);

  bool loading = true;
  Map<String, dynamic>? data;

  // 先固定彰化（你要做切換時，再把這兩個接 UI 下拉）
  String county = "彰化縣";
  String township = "彰化市";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final res = await apiService.fetchCwaFd0047019(
        county: county,
        township: township,
      );
      if (!mounted) return;
      setState(() {
        data = res;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        data = {"error": true, "message": e.toString()};
        loading = false;
      });
    }
  }

  // -----------------------------
  // 解析：把 WeatherElement(Time[]) 合併成「每個時段一筆」
  // root['raw']['WeatherElement'] -> slots
  // -----------------------------
  List<_Slot> _buildSlots(Map<String, dynamic> root) {
    final raw = (root["raw"] is Map) ? (root["raw"] as Map).cast<String, dynamic>() : <String, dynamic>{};
    final elements = (raw["WeatherElement"] is List) ? (raw["WeatherElement"] as List) : const [];

    final Map<String, _Slot> slotMap = {}; // key = "start|end"

    for (final e in elements) {
      if (e is! Map) continue;
      final elementName = (e["ElementName"] ?? "").toString().trim();
      final times = (e["Time"] is List) ? (e["Time"] as List) : const [];
      if (elementName.isEmpty || times.isEmpty) continue;

      for (final t in times) {
        if (t is! Map) continue;
        final start = (t["StartTime"] ?? "").toString();
        final end = (t["EndTime"] ?? "").toString();
        if (start.isEmpty || end.isEmpty) continue;

        final k = "$start|$end";
        final slot = slotMap.putIfAbsent(k, () => _Slot(startTime: start, endTime: end));

        final ev = (t["ElementValue"] is List) ? (t["ElementValue"] as List) : const [];
        if (ev.isNotEmpty && ev.first is Map) {
          slot.values[elementName] = (ev.first as Map).cast<String, dynamic>();
        } else {
          slot.values[elementName] = {"value": ev.isNotEmpty ? ev.first : null};
        }
      }
    }

    final slots = slotMap.values.toList();
    slots.sort((a, b) => a.startDt.compareTo(b.startDt));
    return slots;
  }

  // 取值：slot.values[elementName] 的 map 裡拿 key
  String _pick(_Slot s, String elementName, List<String> keys) {
    final v = s.values[elementName];
    if (v is Map) {
      for (final k in keys) {
        final r = v[k];
        if (r != null && r.toString().trim().isNotEmpty) return r.toString().trim();
      }
      final r = v["value"];
      if (r != null && r.toString().trim().isNotEmpty) return r.toString().trim();
    }
    return "";
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s) ?? double.tryParse(s)?.round();
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  String _two(int n) => n.toString().padLeft(2, "0");

  String _fmtMd(DateTime dt) => "${_two(dt.month)}/${_two(dt.day)}";
  String _fmtHm(DateTime dt) => "${_two(dt.hour)}:${_two(dt.minute)}";

  // -----------------------------
  // WeatherCode -> icon (Material icon) + 顏色
  // -----------------------------
  _WxUI _wxByCode(String code, {String weatherText = ""}) {
    final c = code.trim().padLeft(2, "0");

    _WxUI byText() {
      final t = weatherText;
      if (t.contains("雷")) return const _WxUI(icon: Icons.thunderstorm, tint: 0xFF2D3748);
      if (t.contains("雨")) return const _WxUI(icon: Icons.umbrella, tint: 0xFF1E5AA8);
      if (t.contains("霧") || t.contains("霾")) return const _WxUI(icon: Icons.foggy, tint: 0xFF5A6772);
      if (t.contains("晴") && (t.contains("雲") || t.contains("多雲"))) {
        return const _WxUI(icon: Icons.cloud, tint: 0xFF6B46C1);
      }
      if (t.contains("多雲") || t.contains("陰")) return const _WxUI(icon: Icons.cloud, tint: 0xFF553C9A);
      if (t.contains("晴")) return const _WxUI(icon: Icons.wb_sunny, tint: 0xFFEAA300);
      return const _WxUI(icon: Icons.cloud, tint: 0xFF553C9A);
    }

    switch (c) {
      case "01":
        return const _WxUI(icon: Icons.wb_sunny, tint: 0xFFEAA300);
      case "02":
      case "03":
        return const _WxUI(icon: Icons.cloud, tint: 0xFF6B46C1);
      case "04":
      case "05":
      case "06":
      case "07":
        return const _WxUI(icon: Icons.cloud, tint: 0xFF553C9A);
      case "08":
      case "09":
        return const _WxUI(icon: Icons.foggy, tint: 0xFF5A6772);
      case "10":
      case "11":
      case "12":
      case "13":
      case "14":
      case "15":
      case "16":
      case "17":
      case "18":
        return const _WxUI(icon: Icons.umbrella, tint: 0xFF1E5AA8);
      case "19":
      case "20":
      case "21":
      case "22":
        return const _WxUI(icon: Icons.thunderstorm, tint: 0xFF2D3748);
      default:
        return byText();
    }
  }

  // -----------------------------
  // 圖表資料：像 iOS 的「白天 / 夜晚」
  // - 以 slot.startDt 的小時判斷：06~17 = 白天，其餘 = 夜晚
  // - 每天取白天最高 / 夜晚最低（視覺上接近你參考圖）
  // -----------------------------
  List<_DayNightPoint> _buildDayNight(List<_Slot> slots) {
    final Map<String, List<_Slot>> byDate = {};

    for (final s in slots) {
      final d = "${s.startDt.year}-${_two(s.startDt.month)}-${_two(s.startDt.day)}";
      byDate.putIfAbsent(d, () => []).add(s);
    }

    final keys = byDate.keys.toList()..sort();
    final List<_DayNightPoint> points = [];

    for (final k in keys) {
      final daySlots = <_Slot>[];
      final nightSlots = <_Slot>[];

      for (final s in byDate[k]!) {
        final h = s.startDt.hour;
        if (h >= 6 && h < 18) {
          daySlots.add(s);
        } else {
          nightSlots.add(s);
        }
      }

      double? dayTemp;
      double? nightTemp;

      double? pickTemp(_Slot s) {
        final avg = _pick(s, "平均溫度", ["Temperature"]);
        final maxT = _pick(s, "最高溫度", ["MaxTemperature"]);
        final minT = _pick(s, "最低溫度", ["MinTemperature"]);
        return _toDouble(avg) ?? _toDouble(maxT) ?? _toDouble(minT);
      }

      // 白天：取最高
      for (final s in daySlots) {
        final t = pickTemp(s);
        if (t == null) continue;
        dayTemp = (dayTemp == null) ? t : math.max(dayTemp!, t);
      }

      // 夜晚：取最低
      for (final s in nightSlots) {
        final t = pickTemp(s);
        if (t == null) continue;
        nightTemp = (nightTemp == null) ? t : math.min(nightTemp!, t);
      }

      // 若某天完全沒白天/夜晚資料，盡量用那天任一筆補
      if (dayTemp == null || nightTemp == null) {
        for (final s in byDate[k]!) {
          final t = pickTemp(s);
          if (t == null) continue;
          dayTemp ??= t;
          nightTemp ??= t;
        }
      }

      final first = byDate[k]!.reduce((a, b) => a.startDt.isBefore(b.startDt) ? a : b);
      points.add(
        _DayNightPoint(
          label: _fmtMd(first.startDt),
          day: dayTemp,
          night: nightTemp,
        ),
      );
    }

    // 只顯示前 7 天左右，避免太長
    return points.take(7).toList();
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final hasData = d != null;
    final isError = hasData && d!["error"] == true;

    final slots = (!loading && hasData && !isError)
        ? _buildSlots(d!.cast<String, dynamic>())
        : <_Slot>[];

    final todaySlot = slots.isNotEmpty ? slots.first : null;

    // 今日資訊（主卡）
    String weather = "";
    String weatherCode = "";
    String desc = "";
    String pop = "";
    String rh = "";
    String windSpeed = "";
    String windDir = "";
    String tAvg = "";
    String tMax = "";
    String tMin = "";

    if (todaySlot != null) {
      weather = _pick(todaySlot, "天氣現象", ["Weather"]);
      weatherCode = _pick(todaySlot, "天氣現象", ["WeatherCode"]);
      desc = _pick(todaySlot, "天氣預報綜合描述", ["WeatherDescription"]);
      pop = _pick(todaySlot, "12小時降雨機率", ["ProbabilityOfPrecipitation"]);
      rh = _pick(todaySlot, "平均相對濕度", ["RelativeHumidity"]);
      windSpeed = _pick(todaySlot, "風速", ["WindSpeed"]);
      windDir = _pick(todaySlot, "風向", ["WindDirection"]);

      tAvg = _pick(todaySlot, "平均溫度", ["Temperature"]);
      tMax = _pick(todaySlot, "最高溫度", ["MaxTemperature"]);
      tMin = _pick(todaySlot, "最低溫度", ["MinTemperature"]);
    }

    final wx = _wxByCode(weatherCode, weatherText: weather);
    final points = slots.isEmpty ? <_DayNightPoint>[] : _buildDayNight(slots);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '天氣預報',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
      ),
      
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            if (loading) const LinearProgressIndicator(),
           
            const SizedBox(height: 12),

            if (!loading && !hasData) _infoCard("讀取失敗，請下拉重新整理"),
            if (!loading && isError) _errorCard(d!),

            if (!loading && hasData && !isError) ...[
              // ========= 今日主卡（你給的參考那種形式） =========
              _todayHeroCard(
                context: context,
                location: "$township",
                temp: tAvg,
                tMax: tMax,
                tMin: tMin,
                weather: weather,
                weatherCode: weatherCode,
                icon: wx.icon,
                tint: Color(wx.tint),
                pop: pop,
                rh: rh,
                windSpeed: windSpeed,
                windDir: windDir,
                description: desc,
              ),

              const SizedBox(height: 12),

              // ========= 只有圖表（白天/夜晚） =========
              _chartCard(
                context: context,
                points: points,
              ),

              const Padding(
                padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "資料來源：中央氣象署開放資料",
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // -----------------------------
  // UI
  // -----------------------------

  Widget _todayHeroCard({
    required BuildContext context,
    required String location,
    required String temp,
    required String tMax,
    required String tMin,
    required String weather,
    required String weatherCode,
    required IconData icon,
    required Color tint,
    required String pop,
    required String rh,
    required String windSpeed,
    required String windDir,
    required String description,
  }) {
    // 大字體自適應：字越大，主溫度字就稍微縮
    final textScale = MediaQuery.textScaleFactorOf(context);
    final tempSize = math.max(34.0, 56.0 / textScale);

    String tempText = "—°C";
    final ti = _toInt(temp);
    if (ti != null) tempText = "$ti°C";

    String maxMinText = "";
    final maxI = _toInt(tMax);
    final minI = _toInt(tMin);
    if (maxI != null || minI != null) {
      maxMinText = "最高 ${maxI ?? "—"}°  最低 ${minI ?? "—"}°";
    }

    Widget stat(IconData ic, String label, String value) {
      final v = value.trim().isEmpty ? "—" : value.trim();
      return Expanded(
        child: Column(
          children: [
            Icon(ic, color: Colors.white.withOpacity(0.95), size: 22),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(color: Colors.white.withOpacity(0.92), fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                v,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],
        ),
      );
    }

    String popText = pop.trim().isEmpty ? "—" : "${_toInt(pop) ?? pop}%";
    String rhText = rh.trim().isEmpty ? "—" : "${_toInt(rh) ?? rh}%";
    String windText = windSpeed.trim().isEmpty ? "—" : windSpeed.trim();

    // 背景：用插畫感的漸層（不靠圖片也好看）
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2FB9A8).withOpacity(0.98),
            const Color(0xFF1F8F86).withOpacity(0.98),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // 柔光泡泡
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
            ),
            Positioned(
              left: -40,
              bottom: -50,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.10),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 地點
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.place, size: 16, color: Colors.white.withOpacity(0.95)),
                            const SizedBox(width: 6),
                            Text(
                              location,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // 天氣 icon（對應 WeatherCode）
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: Colors.white, size: 26),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // 大溫度 + 天氣文字/碼
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            tempText,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: tempSize,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              weather.isEmpty ? "—" : weather,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (weatherCode.trim().isNotEmpty)
                                  _chipWhite("WeatherCode $weatherCode"),
                                if (maxMinText.isNotEmpty) _chipWhite(maxMinText),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 三個最重要指標（農民最在意）
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: Row(
                      children: [
                        stat(Icons.umbrella, "降雨機率", popText),
                        Container(width: 1, height: 48, color: Colors.white.withOpacity(0.18)),
                        stat(Icons.water_drop, "濕度", rhText),
                        Container(width: 1, height: 48, color: Colors.white.withOpacity(0.18)),
                        stat(Icons.air, "風速", windText),
                      ],
                    ),
                  ),

                  // WeatherDescription（今天的完整描述）
                  if (description.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      description.trim(),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],

                  if (windDir.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      "風向：$windDir",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.90),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipWhite(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _chartCard({
    required BuildContext context,
    required List<_DayNightPoint> points,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "氣溫預測",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            "白天 / 夜晚趨勢（近 7 天）",
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const SizedBox(height: 12),

          if (points.isEmpty)
            _infoInline("目前資料不足，稍後再試")
          else
            SizedBox(
              height: 260,
              child: SfCartesianChart(
                margin: EdgeInsets.zero,
                legend: const Legend(
                  isVisible: true,
                  position: LegendPosition.top,
                  overflowMode: LegendItemOverflowMode.wrap,
                ),
                primaryXAxis: const CategoryAxis(
                  labelPlacement: LabelPlacement.onTicks,
                  majorGridLines: MajorGridLines(width: 0),
                ),
                primaryYAxis: const NumericAxis(
                  axisLine: AxisLine(width: 0),
                  majorTickLines: MajorTickLines(size: 0),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <LineSeries<_DayNightPoint, String>>[
                  LineSeries<_DayNightPoint, String>(
                    name: "白天",
                    dataSource: points,
                    xValueMapper: (p, _) => p.label,
                    yValueMapper: (p, _) => p.day,
                    markerSettings: const MarkerSettings(isVisible: true),
                  ),
                  LineSeries<_DayNightPoint, String>(
                    name: "夜晚",
                    dataSource: points,
                    xValueMapper: (p, _) => p.label,
                    yValueMapper: (p, _) => p.night,
                    markerSettings: const MarkerSettings(isVisible: true),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoInline(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.black54, height: 1.3)),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(Map<String, dynamic> d) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("讀取失敗", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            (d["message"] ?? "未知錯誤").toString(),
            style: const TextStyle(color: Colors.redAccent, height: 1.35),
          ),
        ],
      ),
    );
  }
}

// -----------------------------
// Models
// -----------------------------
class _Slot {
  final String startTime;
  final String endTime;

  // elementName -> elementValueMap
  final Map<String, dynamic> values = {};

  _Slot({required this.startTime, required this.endTime});

  DateTime get startDt => DateTime.tryParse(startTime) ?? DateTime.fromMillisecondsSinceEpoch(0);
  DateTime get endDt => DateTime.tryParse(endTime) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

class _WxUI {
  final IconData icon;
  final int tint; // ARGB int
  const _WxUI({required this.icon, required this.tint});
}

class _DayNightPoint {
  final String label; // MM/dd
  final double? day;
  final double? night;

  _DayNightPoint({
    required this.label,
    required this.day,
    required this.night,
  });
}
