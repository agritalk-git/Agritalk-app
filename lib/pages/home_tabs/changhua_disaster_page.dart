import 'package:flutter/material.dart';
import 'package:chcg_iot_app/core/api_service.dart';

class ChanghuaDisasterPage extends StatefulWidget {
  const ChanghuaDisasterPage({super.key});

  @override
  State<ChanghuaDisasterPage> createState() => _ChanghuaDisasterPageState();
}

enum RiskLevel { yellow, red } // ✅ 只保留黃 / 紅（綠燈不顯示）

class _ChanghuaDisasterPageState extends State<ChanghuaDisasterPage> {
  final api = ApiService();

  final Color _primaryColor = const Color(0xFF7B4DBB);

  static const _red = Color(0xFFC62828);
  static const _yellow = Color(0xFFF9A825);
  static const _bg = Color(0xFFF5F5F5);

  bool loading = true;
  String? error;

  String initialDate = '';
  Map<String, dynamic> cropData = {}; // town -> List<item>

  String? expandedTown;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ----------------------------
  // Data
  // ----------------------------
  Future<void> _load() async {
    try {
      final data = await api.fetchchanghua_coordinate();
      if (!mounted) return;

      if (data == null) {
        setState(() {
          loading = false;
          error = 'API 回傳 null';
        });
        return;
      }

      final wrapper = data['changhua_coordinate_list'];
      if (wrapper is! Map<String, dynamic>) {
        setState(() {
          loading = false;
          error = '回傳格式不符合預期（找不到 changhua_coordinate_list）';
        });
        return;
      }

      final cd = wrapper['crop_data'];

      setState(() {
        initialDate = (wrapper['InitialDateTime'] ?? '').toString();
        cropData = (cd is Map<String, dynamic>) ? cd : {};
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  // ----------------------------
  // Helpers: severity / color
  // ----------------------------
  int _sev(String? c) {
    switch ((c ?? '').toLowerCase()) {
      case 'red':
        return 2;
      case 'yellow':
        return 1;
      default:
        return 0; // green/unknown -> 0
    }
  }

  Color _colorFor(String light) {
    switch (light.toLowerCase()) {
      case 'red':
        return _red;
      case 'yellow':
      default:
        return _yellow;
    }
  }

  String _textFor(String light) {
    switch (light.toLowerCase()) {
      case 'red':
        return '紅燈';
      case 'yellow':
      default:
        return '黃燈';
    }
  }

  RiskLevel _levelFromMaxSev(int maxSev) {
    return (maxSev >= 2) ? RiskLevel.red : RiskLevel.yellow;
  }

  Color _levelColor(RiskLevel lv) => (lv == RiskLevel.red) ? _red : _yellow;
  String _levelText(RiskLevel lv) => (lv == RiskLevel.red) ? '紅燈' : '黃燈';

  // ----------------------------
  // Build filtered towns/crops (ONLY yellow/red)
  // ----------------------------

  /// 回傳這個 crop item 內「非綠燈」的災害 chips
  List<_DisasterChipData> _alertDisastersFromItem(Map m) {
    final dn = (m['Disaster_name'] is List) ? (m['Disaster_name'] as List) : const [];
    final lc = (m['Light_color'] is List) ? (m['Light_color'] as List) : const [];

    final out = <_DisasterChipData>[];
    for (int i = 0; i < dn.length; i++) {
      final name = (dn[i] ?? '').toString().trim();
      final light = (i < lc.length) ? (lc[i] ?? 'green').toString() : 'green';
      if (name.isEmpty) continue;
      if (_sev(light) <= 0) continue; // ✅ 綠燈不要
      out.add(_DisasterChipData(name: name, light: light));
    }
    return out;
  }

  /// town 內「至少有一個作物是黃/紅」才算要顯示
  bool _townHasAlerts(String town) {
    final list = cropData[town];
    final items = (list is List) ? list : const [];
    for (final it in items) {
      if (it is Map) {
        if (_alertDisastersFromItem(Map<String, dynamic>.from(it)).isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  /// town 的最高風險（只會是黃或紅；因為 town 會先篩掉沒有預警的）
  RiskLevel _townRisk(String town) {
    final list = cropData[town];
    final items = (list is List) ? list : const [];
    int maxSev = 0;

    for (final it in items) {
      if (it is Map) {
        final m = Map<String, dynamic>.from(it);
        final lc = (m['Light_color'] is List) ? (m['Light_color'] as List) : const [];
        for (final c in lc) {
          final s = _sev(c?.toString());
          if (s > maxSev) maxSev = s;
          if (maxSev >= 2) break;
        }
      }
      if (maxSev >= 2) break;
    }

    // 這裡 maxSev 可能是 0（理論上 town 會先過濾，所以不會）
    if (maxSev <= 1) return RiskLevel.yellow;
    return RiskLevel.red;
  }

  /// town 的「預警作物數」：只算有黃/紅災害的作物
  int _townAlertCropCount(String town) {
    final list = cropData[town];
    final items = (list is List) ? list : const [];
    int count = 0;
    for (final it in items) {
      if (it is Map) {
        final m = Map<String, dynamic>.from(it);
        if (_alertDisastersFromItem(m).isNotEmpty) count++;
      }
    }
    return count;
  }

  /// town 的「預警災害種類數」：只算黃/紅災害的種類（去重）
  int _townAlertDisasterKindCount(String town) {
    final list = cropData[town];
    final items = (list is List) ? list : const [];
    final set = <String>{};

    for (final it in items) {
      if (it is Map) {
        final m = Map<String, dynamic>.from(it);
        final alerts = _alertDisastersFromItem(m);
        for (final a in alerts) {
          set.add(a.name);
        }
      }
    }
    return set.length;
  }

  /// 全縣統計：紅/黃鄉鎮數 & 紅/黃作物數
  _Summary _summaryOfVisibleTowns(List<String> visibleTowns) {
    int redTowns = 0, yellowTowns = 0;
    int redCrops = 0, yellowCrops = 0;

    for (final t in visibleTowns) {
      final risk = _townRisk(t);
      if (risk == RiskLevel.red) redTowns++;
      if (risk == RiskLevel.yellow) yellowTowns++;

      final list = cropData[t];
      final items = (list is List) ? list : const [];
      for (final it in items) {
        if (it is! Map) continue;
        final m = Map<String, dynamic>.from(it);
        final alerts = _alertDisastersFromItem(m);
        if (alerts.isEmpty) continue;

        // 作物等級：只看該作物 alerts 裡面是否有紅
        final hasRed = alerts.any((x) => _sev(x.light) >= 2);
        if (hasRed) {
          redCrops++;
        } else {
          yellowCrops++;
        }
      }
    }

    return _Summary(
      redTowns: redTowns,
      yellowTowns: yellowTowns,
      redCrops: redCrops,
      yellowCrops: yellowCrops,
    );
  }

  // ----------------------------
  // UI
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    // ✅ 文字放大時也要穩：盡量避免固定高度
    final textScale = MediaQuery.textScaleFactorOf(context);

    final allTowns = cropData.keys.toList()..sort();
    final visibleTowns = allTowns.where(_townHasAlerts).toList();

    // ✅ 排序：紅在上、黃在下；同色按鄉鎮名稱
    visibleTowns.sort((a, b) {
      final ra = _townRisk(a) == RiskLevel.red ? 1 : 0;
      final rb = _townRisk(b) == RiskLevel.red ? 1 : 0;
      if (ra != rb) return rb.compareTo(ra);
      return a.compareTo(b);
    });

    final summary = _summaryOfVisibleTowns(visibleTowns);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '農作物災害預警（彰化縣）',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (error != null)
              ? _ErrorView(error: error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      _SummaryHeader(
                        initialDate: initialDate,
                        redTowns: summary.redTowns,
                        yellowTowns: summary.yellowTowns,
                        redCrops: summary.redCrops,
                        yellowCrops: summary.yellowCrops,
                      ),
                      const SizedBox(height: 10),

                      _LegendCard(primaryColor: _primaryColor),
                      const SizedBox(height: 12),

                      if (visibleTowns.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            '目前沒有黃燈 / 紅燈預警資料',
                            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                          ),
                        ),

                      ...visibleTowns.map((town) {
                        final risk = _townRisk(town);
                        final color = _levelColor(risk);

                        final alertCropCount = _townAlertCropCount(town);
                        final alertKinds = _townAlertDisasterKindCount(town);

                        final expanded = expandedTown == town;

                        final rawItems = cropData[town];
                        final items = (rawItems is List) ? rawItems : const [];

                        // town 展開時：只顯示有黃/紅的作物
                        final alertItems = items.where((it) {
                          if (it is! Map) return false;
                          final m = Map<String, dynamic>.from(it);
                          return _alertDisastersFromItem(m).isNotEmpty;
                        }).toList();

                        return _TownCard(
                          town: town,
                          levelText: _levelText(risk),
                          color: color,
                          alertCropCount: alertCropCount,
                          alertKinds: alertKinds,
                          expanded: expanded,
                          textScale: textScale,
                          onToggle: () {
                            setState(() {
                              expandedTown = expanded ? null : town;
                            });
                          },
                          children: alertItems.map((it) => _CropCard(item: it)).toList(),
                        );
                      }),

                      // ✅ 你指定要放在最下面
                      const Padding(
                        padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '資料來源：農作物災害預警平台',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// =====================================================
// Widgets
// =====================================================

class _SummaryHeader extends StatelessWidget {
  final String initialDate;
  final int redTowns;
  final int yellowTowns;
  final int redCrops;
  final int yellowCrops;

  const _SummaryHeader({
    required this.initialDate,
    required this.redTowns,
    required this.yellowTowns,
    required this.redCrops,
    required this.yellowCrops,
  });

  static const _red = Color(0xFFC62828);
  static const _yellow = Color(0xFFF9A825);

  @override
  Widget build(BuildContext context) {
    // ✅ 這邊用 Column + Wrap，字放大也不容易爆
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('資料日期：$initialDate', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 10),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CountPill(
                color: _red,
                title: '紅燈鄉鎮',
                value: redTowns,
                subtitle: '紅燈作物 $redCrops',
              ),
              _CountPill(
                color: _yellow,
                title: '黃燈鄉鎮',
                value: yellowTowns,
                subtitle: '黃燈作物 $yellowCrops',
              ),
            ],
          ),

          // const SizedBox(height: 10),
          // const Text(
          //   '只顯示黃燈 / 紅燈預警。\n點鄉鎮可查看「哪些作物、哪一種災害」正在警戒。',
          //   style: TextStyle(color: Colors.black45, fontSize: 12, height: 1.25),
          // ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final Color color;
  final String title;
  final int value;
  final String subtitle;

  const _CountPill({
    required this.color,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ 不用 Expanded，避免 Wrap 時硬擠爆；用 ConstrainedBox 限制最小寬度
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ title 太長也不爆
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$value',
                    style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900, height: 1.0),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color.withOpacity(0.85), fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendCard extends StatelessWidget {
  final Color primaryColor;
  const _LegendCard({required this.primaryColor});

  static const _red = Color(0xFFC62828);
  static const _yellow = Color(0xFFF9A825);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('燈號說明', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _LegendItem(
                color: _red,
                title: '紅燈',
                desc: '風險高，建議優先處理',
              ),
              _LegendItem(
                color: _yellow,
                title: '黃燈',
                desc: '需要留意，提早準備防範',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String title;
  final String desc;

  const _LegendItem({
    required this.color,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 12, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TownCard extends StatelessWidget {
  final String town;
  final String levelText;
  final Color color;

  final int alertCropCount;
  final int alertKinds;

  final bool expanded;
  final double textScale;

  final VoidCallback onToggle;
  final List<Widget> children;

  const _TownCard({
    required this.town,
    required this.levelText,
    required this.color,
    required this.alertCropCount,
    required this.alertKinds,
    required this.expanded,
    required this.textScale,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ header 不用固定高度，避免字變大爆掉
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onToggle,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左色條
                  Container(
                    width: 6,
                    height: (48.0 * (textScale.clamp(1.0, 1.4))), // ✅ 文字變大就長一點
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 鄉鎮名
                        Text(
                          town,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),

                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _MetaPill(icon: Icons.grass, text: '預警作物 $alertCropCount'),
                            _MetaPill(icon: Icons.warning_amber_rounded, text: '預警種類 $alertKinds'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _LevelBadge(text: levelText, color: color),
                      const SizedBox(height: 8),
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.black45,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (expanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  children: children,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _LevelBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    // ✅ 長字也不爆：用 FittedBox scaleDown
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _CropCard extends StatelessWidget {
  final dynamic item;
  const _CropCard({required this.item});

  static const _red = Color(0xFFC62828);
  static const _yellow = Color(0xFFF9A825);
  static const _green = Color(0xFF2E7D32);

  int _sev(String? c) {
    switch ((c ?? '').toLowerCase()) {
      case 'red':
        return 2;
      case 'yellow':
        return 1;
      default:
        return 0;
    }
  }

  Color _c(String light) {
    switch (light.toLowerCase()) {
      case 'red':
        return _red;
      case 'yellow':
        return _yellow;
      default:
        return _green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = (item is Map) ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    final name = (m['Name'] ?? '').toString().trim();
    final acreage = (m['Acreage'] ?? '').toString().trim();

    final dn = (m['Disaster_name'] is List) ? (m['Disaster_name'] as List) : const [];
    final lc = (m['Light_color'] is List) ? (m['Light_color'] as List) : const [];

    // ✅ 只留下黃/紅災害
    final alerts = <_DisasterChipData>[];
    for (int i = 0; i < dn.length; i++) {
      final d = (dn[i] ?? '').toString().trim();
      final light = (i < lc.length) ? (lc[i] ?? 'green').toString() : 'green';
      if (d.isEmpty) continue;
      if (_sev(light) <= 0) continue;
      alerts.add(_DisasterChipData(name: d, light: light));
    }

    // 保險：如果沒預警就不顯示
    if (alerts.isEmpty) return const SizedBox.shrink();

    final hasRed = alerts.any((x) => _sev(x.light) >= 2);
    final cropLevel = hasRed ? 'red' : 'yellow';
    final cropColor = _c(cropLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題列：作物 + 作物燈號
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name.isEmpty ? '(未命名作物)' : name,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  softWrap: true,
                ),
              ),
              const SizedBox(width: 8),
              _LevelBadge(
                text: (cropLevel == 'red') ? '紅燈' : '黃燈',
                color: cropColor,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 面積 + 災害 chips（只黃/紅）
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (acreage.isNotEmpty)
                _PlainChip(text: '面積 $acreage'),

              ...alerts.map((a) => _LightChip(text: a.name, light: a.light)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlainChip extends StatelessWidget {
  final String text;
  const _PlainChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _LightChip extends StatelessWidget {
  final String text;
  final String light;
  const _LightChip({required this.text, required this.light});

  static const _red = Color(0xFFC62828);
  static const _yellow = Color(0xFFF9A825);

  Color _c(String c) {
    switch (c.toLowerCase()) {
      case 'red':
        return _red;
      case 'yellow':
      default:
        return _yellow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _c(light);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color),
            softWrap: true,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 10),
            Text('讀取失敗', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('重試')),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// Small data classes
// =====================================================

class _DisasterChipData {
  final String name;
  final String light;
  _DisasterChipData({required this.name, required this.light});
}

class _Summary {
  final int redTowns;
  final int yellowTowns;
  final int redCrops;
  final int yellowCrops;

  _Summary({
    required this.redTowns,
    required this.yellowTowns,
    required this.redCrops,
    required this.yellowCrops,
  });
}
