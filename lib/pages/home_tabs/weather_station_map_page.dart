// lib/pages/home_tabs/weather_station_map_page.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geo;

import 'package:chcg_iot_app/core/api_service.dart';

const Color _primaryColor = Color(0xFF7B4DBB);

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

String _s(dynamic v, {String fallback = '-'}) {
  if (v == null) return fallback;
  final t = v.toString().trim();
  return t.isEmpty ? fallback : t;
}

class WeatherStationMapPage extends StatefulWidget {
  const WeatherStationMapPage({super.key});

  @override
  State<WeatherStationMapPage> createState() => _WeatherStationMapPageState();
}

class _WeatherStationMapPageState extends State<WeatherStationMapPage> {
  final moaApi = MoaApiService();

  GoogleMapController? _mapController;
  MapType _mapType = MapType.normal;
  Key _mapKey = UniqueKey();

  // Taiwan center
  static const LatLng _taiwanCenter = LatLng(23.6978, 120.9605);

  bool _loading = true;
  String? _error;

  // 搜尋
  final TextEditingController _searchCtrl = TextEditingController();
  bool _searching = false;

  // ✅ 單選：一次只顯示一種
  _StationKind _selected = _StationKind.weather;

  // 原始資料（兩種都先載入，切換只是換 markers）
  List<_StationPoint> _weatherPoints = [];
  List<_StationPoint> _rainPoints = [];

  // markers
  Set<Marker> _markers = {};

  // 防止連點造成 setState 交錯
  int _switchToken = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _searchCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final weather = await moaApi.fetchAutoWeatherStationType(
        cropMarketType: 'Veg',
      );
      final rain = await moaApi.fetchAutoRainfallStationType(
        cropMarketType: 'Veg',
      );

      final w = _parseWeatherStations(weather);
      final r = _parseRainStations(rain);

      if (!mounted) return;

      setState(() {
        _weatherPoints = w;
        _rainPoints = r;
        _markers = _buildMarkersForSelected(); // ✅ 初次依單選狀態顯示
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '載入失敗：$e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // -------------------------
  // Parse
  // -------------------------
  List<_StationPoint> _parseWeatherStations(List<Map<String, dynamic>> list) {
    final out = <_StationPoint>[];

    for (final e in list) {
      final name =
          (e['Station_name'] ??
                  e['StationName'] ??
                  e['Station_name(string)'] ??
                  '氣象測站')
              .toString();
      final id = (e['Station_ID'] ?? e['StationID'] ?? '').toString();

      final rawLat = e['Station_Latitude'];
      final rawLon = e['Station_Longitude'];

      final latNum = _toDouble(rawLat);
      final lonNum = _toDouble(rawLon);
      if (latNum == 0.0 || lonNum == 0.0) continue;

      final ll = _ensureLatLng(latNum, lonNum);
      if (ll == null) continue;

      out.add(
        _StationPoint(
          id: 'W-$id-$name',
          name: name,
          stationId: id,
          latLng: ll,
          kind: _StationKind.weather,
          raw: e,
        ),
      );
    }

    return out;
  }

  List<_StationPoint> _parseRainStations(List<Map<String, dynamic>> list) {
    final out = <_StationPoint>[];

    for (final e in list) {
      final name = (e['Station_name'] ?? e['StationName'] ?? '雨量測站').toString();
      final id = (e['Station_ID'] ?? e['StationID'] ?? '').toString();

      final rawLat = e['LAT'] ?? e['Lat'] ?? e['lat'];
      final rawLon = e['LON'] ?? e['Lon'] ?? e['lon'];

      final latNum = _toDouble(rawLat);
      final lonNum = _toDouble(rawLon);
      if (latNum == 0.0 || lonNum == 0.0) continue;

      final ll = _ensureLatLng(latNum, lonNum);
      if (ll == null) continue;

      out.add(
        _StationPoint(
          id: 'R-$id-$name',
          name: name,
          stationId: id,
          latLng: ll,
          kind: _StationKind.rain,
          raw: e,
        ),
      );
    }

    return out;
  }

  /// 如果數值看起來像經緯度（<=90/180）就直接用；
  /// 否則視為 TWD67 TM2(121) 公尺座標，嘗試轉 WGS84
  LatLng? _ensureLatLng(double a, double b) {
    // case 1: already degrees
    if (a.abs() <= 90 && b.abs() <= 180) {
      return LatLng(a, b);
    }

    // case 2: likely meters (TWD67 TM2)
    final x = b;
    final y = a;

    final ll1 = _twd67Tm2ToWgs84(x: x, y: y);
    if (ll1 != null && ll1.latitude.abs() <= 90 && ll1.longitude.abs() <= 180) {
      return ll1;
    }

    // try swapped
    final ll2 = _twd67Tm2ToWgs84(x: a, y: b);
    if (ll2 != null && ll2.latitude.abs() <= 90 && ll2.longitude.abs() <= 180) {
      return ll2;
    }

    return null;
  }

  /// TWD67 / TM2 zone 121 → WGS84 (近似換算)
  LatLng? _twd67Tm2ToWgs84({required double x, required double y}) {
    if (x.abs() < 1000 || y.abs() < 1000) return null;

    const double a = 6378160.0; // TWD67 ellipsoid
    const double b = 6356774.719;
    const double lon0 = 121 * math.pi / 180;
    const double k0 = 0.9999;
    const double dx = 250000.0;

    final double e = math.sqrt(1 - (b * b) / (a * a));
    final double xAdj = x - dx;
    final double yAdj = y;

    final double m = yAdj / k0;
    final double mu =
        m /
        (a *
            (1 -
                math.pow(e, 2) / 4 -
                3 * math.pow(e, 4) / 64 -
                5 * math.pow(e, 6) / 256));

    final double e1 = (1 - math.sqrt(1 - e * e)) / (1 + math.sqrt(1 - e * e));

    final double j1 = 3 * e1 / 2 - 27 * math.pow(e1, 3) / 32;
    final double j2 = 21 * math.pow(e1, 2) / 16 - 55 * math.pow(e1, 4) / 32;
    final double j3 = 151 * math.pow(e1, 3) / 96;
    final double j4 = 1097 * math.pow(e1, 4) / 512;

    final double fp =
        mu +
        j1 * math.sin(2 * mu) +
        j2 * math.sin(4 * mu) +
        j3 * math.sin(6 * mu) +
        j4 * math.sin(8 * mu);

    final double e2 = (e * e) / (1 - e * e);
    final double c1 = e2 * math.pow(math.cos(fp), 2);
    final double t1 = math.tan(fp) * math.tan(fp);
    final double r1 =
        a * (1 - e * e) / math.pow(1 - e * e * math.pow(math.sin(fp), 2), 1.5);
    final double n1 = a / math.sqrt(1 - e * e * math.pow(math.sin(fp), 2));

    final double d = xAdj / (n1 * k0);

    // latitude
    final double q1 = n1 * math.tan(fp) / r1;
    final double q2 = (d * d) / 2;
    final double q3 =
        (5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * e2) * math.pow(d, 4) / 24;
    final double q4 =
        (61 + 90 * t1 + 298 * c1 + 45 * t1 * t1 - 252 * e2 - 3 * c1 * c1) *
        math.pow(d, 6) /
        720;
    final double lat = fp - q1 * (q2 - q3 + q4);

    // longitude
    final double q5 = d;
    final double q6 = (1 + 2 * t1 + c1) * math.pow(d, 3) / 6;
    final double q7 =
        (5 - 2 * c1 + 28 * t1 - 3 * c1 * c1 + 8 * e2 + 24 * t1 * t1) *
        math.pow(d, 5) /
        120;
    final double lon = lon0 + (q5 - q6 + q7) / math.cos(fp);

    return LatLng(lat * 180 / math.pi, lon * 180 / math.pi);
  }

  // -------------------------
  // Markers
  // -------------------------
  Set<Marker> _buildMarkersForSelected() {
    final next = <Marker>{};

    if (_selected == _StationKind.weather) {
      for (final p in _weatherPoints) {
        next.add(_markerFromPoint(p, hue: BitmapDescriptor.hueAzure));
      }
    } else {
      for (final p in _rainPoints) {
        next.add(_markerFromPoint(p, hue: BitmapDescriptor.hueOrange));
      }
    }

    return next;
  }

  Marker _markerFromPoint(_StationPoint p, {required double hue}) {
    final lat = p.latLng.latitude.toStringAsFixed(6);
    final lon = p.latLng.longitude.toStringAsFixed(6);
    final prefix = (p.kind == _StationKind.rain) ? '🌧️ 雨量' : '🌤️ 氣象';

    return Marker(
      markerId: MarkerId(p.id),
      position: p.latLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      onTap: () => _openStationSheet(p),
      infoWindow: InfoWindow(
        title: '$prefix｜${p.name}',
        snippet: '($lat, $lon)',
      ),
    );
  }

  Future<void> _animateTo(LatLng target, {double zoom = 13.5}) async {
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: zoom),
      ),
    );
  }

  // ✅ 單選切換：先清乾淨（markers = {}），再畫新的
  Future<void> _switchTo(_StationKind kind) async {
  if (_selected == kind) return;

  final token = ++_switchToken;

  // 1) 先清 markers + 換 key（強制重建 GoogleMap）
  setState(() {
    _selected = kind;
    _markers = <Marker>{};     // ✅ 清到空
    _mapKey = UniqueKey();     // ✅ 強制原生地圖重建，舊點必消失
  });

  // 2) 給一個 frame 時間讓原生層真的清掉
  await Future.delayed(const Duration(milliseconds: 60));
  if (!mounted || token != _switchToken) return;

  // 3) 再放新的 markers
  setState(() {
    _markers = _buildMarkersForSelected();
  });
}

  String _formatMmInt(dynamic v) {
    if (v == null) return '0 mm';
    if (v is num) return '${v.toInt()} mm';
    final s = v.toString().trim();
    if (s.isEmpty) return '0 mm';
    final n = int.tryParse(s) ?? double.tryParse(s)?.toInt();
    return '${n ?? 0} mm';
  }

  String _formatNum(dynamic v, {String unit = ''}) {
    if (v == null) return '-';
    if (v is int) return '$v$unit';
    if (v is double) {
      final txt =
          v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
      return '$txt$unit';
    }
    final s = v.toString().trim();
    if (s.isEmpty) return '-';
    final n = double.tryParse(s);
    if (n == null) return '$s$unit';
    final txt =
        n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(1);
    return '$txt$unit';
  }

  void _openStationSheet(_StationPoint p) {
    final raw = p.raw;

    final city = _s(raw['CITY']);
    final town = _s(raw['TOWN']);
    final stationNo = _s(raw['Station_ID'], fallback: p.stationId);
    final updatedAt = _s(raw['TIME'], fallback: '');

    final List<_KVRow> displayRows =
        (p.kind == _StationKind.rain)
            ? <_KVRow>[
              _KVRow('時間(起)', _s(raw['Start_time'])),
              _KVRow('時間(迄)', _s(raw['End_time'])),
              _KVRow('測站名稱', _s(raw['Station_name'])),
              _KVRow('測站編號', _s(raw['Station_ID'])),
              _KVRow('觀測資料時間', _s(raw['TIME'])),
              _KVRow('緯度', _s(raw['LAT'])),
              _KVRow('經度', _s(raw['LON'])),
              _KVRow('高度', _s(raw['ELEV'])),
              _KVRow('本日累積雨量', _formatMmInt(raw['NOW'])),
              _KVRow('10分鐘累積雨量', _formatMmInt(raw['MIN_10'])),
              _KVRow('60分鐘累積雨量', _formatMmInt(raw['RAIN'])),
              _KVRow('3小時累積雨量', _formatMmInt(raw['HOUR_3'])),
              _KVRow('6小時累積雨量', _formatMmInt(raw['HOUR_6'])),
              _KVRow('12小時累積雨量', _formatMmInt(raw['HOUR_12'])),
              _KVRow('24小時累積雨量', _formatMmInt(raw['HOUR_24'])),
              _KVRow('自動站屬性', _s(raw['ATTRIBUTE'])),
            ]
            : <_KVRow>[
              _KVRow('時間(起)', _s(raw['Start_time'])),
              _KVRow('時間(迄)', _s(raw['End_time'])),
              _KVRow('測站名稱', _s(raw['Station_name'])),
              _KVRow('測站編號', _s(raw['Station_ID'])),
              _KVRow('緯度', _s(raw['Station_Latitude'])),
              _KVRow('經度', _s(raw['Station_Longitude'])),
              _KVRow('高度', _s(raw['ELEV'])),
              _KVRow('觀測資料時間', _s(raw['TIME'])),
              _KVRow('風向', _formatNum(raw['WDIR'], unit: '°')),
              _KVRow('風速', _formatNum(raw['WDSD'], unit: ' m/s')),
              _KVRow('溫度', _formatNum(raw['TEMP'], unit: ' °C')),
              _KVRow('相對濕度', _formatNum(raw['HUMD'], unit: ' %')),
              _KVRow('氣壓', _formatNum(raw['PRES'], unit: ' hPa')),
              _KVRow('日照', _formatNum(raw['SUN'], unit: ' hr')),
              _KVRow('日累積雨量', _formatNum(raw['H_24R'], unit: ' mm')),
            ];

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _StationBottomSheet(
          title: p.name,
          updatedAt: updatedAt,
          city: city,
          town: town,
          stationNo: stationNo,
          rows: displayRows,
          onLocate: () async {
            Navigator.pop(context);
            await _animateTo(p.latLng, zoom: 14.5);
          },
        );
      },
    );
  }

  // -------------------------
  // Search
  // -------------------------
  Future<void> _doSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    

    setState(() => _searching = true);

    try {
      final results = await geo.locationFromAddress(q);
      if (results.isEmpty) {
        _snack('找不到地點：$q');
        return;
      }

      final first = results.first;
      final target = LatLng(first.latitude, first.longitude);
      await _animateTo(target, zoom: 13.5);
    } catch (e) {
      _snack('搜尋失敗：$e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _toggleMapType() {
    setState(() {
      _mapType = (_mapType == MapType.normal) ? MapType.hybrid : MapType.normal;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final total =
        (_selected == _StationKind.weather)
            ? _weatherPoints.length
            : _rainPoints.length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          '氣象/雨量測站地圖',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        centerTitle: true,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _mapType == MapType.normal ? '切換衛星圖' : '切換一般圖',
            icon: Icon(
              _mapType == MapType.normal ? Icons.satellite_alt : Icons.map,
            ),
            onPressed: _toggleMapType,
          ),
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
  key: _mapKey, // ✅ 強制重建地圖，保證清乾淨
  onMapCreated: (c) => _mapController = c,
  initialCameraPosition: const CameraPosition(
    target: _taiwanCenter,
    zoom: 7.5,
  ),
  mapType: _mapType,
  markers: _markers,
  myLocationEnabled: true,
  myLocationButtonEnabled: true,
  compassEnabled: true,
),


          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 10),
                  _buildSingleSelectLegend(total),
                ],
              ),
            ),
          ),

          if (_error != null)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 106, 12, 0),
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.search, color: _primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _doSearch(),
                decoration: const InputDecoration(
                  hintText: '搜尋地點（例如：湖西、台北車站、台南市政府）',
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (_searching)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            else if (_searchCtrl.text.trim().isNotEmpty)
              IconButton(
                tooltip: '清除',
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => _searchCtrl.clear()),
              ),
            const SizedBox(width: 2),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              onPressed: _doSearch,
              child: const Text('搜尋'),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 單選 Legend（一次只選一個）
  Widget _buildSingleSelectLegend(int total) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            _choiceChip(
              colorDot: Colors.blue,
              label: '氣象測站',
              selected: _selected == _StationKind.weather,
              onTap: () => _switchTo(_StationKind.weather),
            ),
            const SizedBox(width: 10),
            _choiceChip(
              colorDot: Colors.orange,
              label: '雨量測站',
              selected: _selected == _StationKind.rain,
              onTap: () => _switchTo(_StationKind.rain),
            ),
            const Spacer(),
            Text(
              '共 $total 站',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choiceChip({
    required Color colorDot,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF2F0FA) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? _primaryColor.withOpacity(0.35) : Colors.black12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: colorDot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? _primaryColor : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------
// Bottom Sheet UI
// -------------------------
class _StationBottomSheet extends StatelessWidget {
  final String title;
  final String updatedAt;
  final String city;
  final String town;
  final String stationNo;
  final List<_KVRow> rows;
  final VoidCallback onLocate;

  const _StationBottomSheet({
    required this.title,
    required this.updatedAt,
    required this.city,
    required this.town,
    required this.stationNo,
    required this.rows,
    required this.onLocate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Color(0x22000000),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.water_drop_rounded,
                      color: _primaryColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (updatedAt.isNotEmpty)
                    Text(
                      updatedAt,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill('縣市：$city'),
                  _pill('鄉鎮：$town'),
                  _pill('站號：$stationNo'),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: rows
                      .map(
                        (r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.k,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                r.v,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: onLocate,
                  icon: const Icon(Icons.my_location),
                  label: const Text(
                    '定位到此測站',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F2FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x1A7B4DBB)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _KVRow {
  final String k;
  final String v;
  const _KVRow(this.k, this.v);
}

// -------------------------
// Model
// -------------------------
enum _StationKind { weather, rain }

class _StationPoint {
  final String id;
  final String name;
  final String stationId;
  final LatLng latLng;
  final _StationKind kind;
  final Map<String, dynamic> raw;

  const _StationPoint({
    required this.id,
    required this.name,
    required this.stationId,
    required this.latLng,
    required this.kind,
    required this.raw,
  });
}
