import 'package:flutter/material.dart';
import 'package:chcg_iot_app/core/api_service.dart';

class ChanghuaDisasterPage extends StatefulWidget {
  const ChanghuaDisasterPage({super.key});

  @override
  State<ChanghuaDisasterPage> createState() => _ChanghuaDisasterPageState();
}

// ============================
// 1) Risk / Color / Text helpers
// ============================
enum RiskLevel { green, yellow, red }

int sevOf(String? c) {
  switch ((c ?? '').toLowerCase()) {
    case 'red':
      return 2;
    case 'yellow':
      return 1;
    default:
      return 0;
  }
}

RiskLevel riskFromSev(int sev) {
  if (sev >= 2) return RiskLevel.red;
  if (sev == 1) return RiskLevel.yellow;
  return RiskLevel.green;
}

Color colorOfLight(String c) {
  switch (c.toLowerCase()) {
    case 'red':
      return const Color(0xFFC62828);
    case 'yellow':
      return const Color(0xFFF9A825);
    default:
      return const Color(0xFF2E7D32);
  }
}

String textOfLight(String c) {
  switch (c.toLowerCase()) {
    case 'red':
      return '紅燈';
    case 'yellow':
      return '黃燈';
    default:
      return '綠燈';
  }
}

// ============================
// 2) ViewModels (clean structure)
// ============================
class HazardVM {
  final String name;
  final String light; // green/yellow/red
  HazardVM({required this.name, required this.light});
  int get sev => sevOf(light);
  bool get isWarning => sev >= 1; // yellow/red
}

class CropVM {
  final String name;
  final String acreage;
  final List<HazardVM> hazards;

  CropVM({required this.name, required this.acreage, required this.hazards});

  int get maxSev {
    int m = 0;
    for (final h in hazards) {
      if (h.sev > m) m = h.sev;
      if (m == 2) break;
    }
    return m;
  }

  RiskLevel get risk => riskFromSev(maxSev);

  bool get isWarning => risk == RiskLevel.yellow || risk == RiskLevel.red;

  String get riskLight => (risk == RiskLevel.red)
      ? 'red'
      : (risk == RiskLevel.yellow)
          ? 'yellow'
          : 'green';

  List<HazardVM> get warningHazards =>
      hazards.where((h) => h.isWarning).toList();
}

class TownVM {
  final String town;
  final List<CropVM> crops;

  TownVM({required this.town, required this.crops});

  List<CropVM> get warningCrops => crops.where((c) => c.isWarning).toList();

  int get maxSev {
    int m = 0;
    for (final c in warningCrops) {
      if (c.maxSev > m) m = c.maxSev;
      if (m == 2) break;
    }
    return m;
  }

  RiskLevel get risk => riskFromSev(maxSev);

  int get cropCount => warningCrops.length;
  int get redCropCount =>
      warningCrops.where((c) => c.risk == RiskLevel.red).length;
  int get yellowCropCount =>
      warningCrops.where((c) => c.risk == RiskLevel.yellow).length;

  List<String> topHazards({int limit = 3}) {
    final Map<String, int> score = {};
    for (final c in warningCrops) {
      for (final h in c.warningHazards) {
        final add = (h.light == 'red') ? 3 : 2; // only yellow/red
        score[h.name] = (score[h.name] ?? 0) + add;
      }
    }
    final sorted = score.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }
}

class _PageVM {
  final String initialDate;
  final List<TownVM> towns;

  _PageVM({required this.initialDate, required this.towns});

  int get redCropTotal =>
      towns.fold(0, (sum, t) => sum + t.redCropCount);
  int get yellowCropTotal =>
      towns.fold(0, (sum, t) => sum + t.yellowCropCount);

  int get warningCropTotal => redCropTotal + yellowCropTotal;
}

// ============================
// 3) Page
// ============================
class _ChanghuaDisasterPageState extends State<ChanghuaDisasterPage> {
  final api = ApiService();
  final Color _primaryColor = const Color(0xFF7B4DBB);

  bool loading = true;
  String? error;
  _PageVM? vm;

  String? expandedTown;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

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

      final initialDate = (wrapper['InitialDateTime'] ?? '').toString();
      final cropData = wrapper['crop_data'];

      if (cropData is! Map<String, dynamic>) {
        setState(() {
          loading = false;
          error = '回傳格式不符合預期（crop_data 不是 Map）';
        });
        return;
      }

      final towns = <TownVM>[];

      for (final entry in cropData.entries) {
        final town = entry.key.toString();
        final list = entry.value;
        if (list is! List) continue;

        final crops = <CropVM>[];
        for (final it in list) {
          if (it is! Map) continue;

          final name = (it['Name'] ?? '').toString().trim();
          final acreage = (it['Acreage'] ?? '').toString().trim();

          final dn = (it['Disaster_name'] is List)
              ? (it['Disaster_name'] as List)
              : const [];
          final lc = (it['Light_color'] is List)
              ? (it['Light_color'] as List)
              : const [];

          final hazards = <HazardVM>[];
          for (int i = 0; i < dn.length; i++) {
            final hName = (dn[i] ?? '').toString().trim();
            if (hName.isEmpty) continue;
            final light =
                (i < lc.length) ? (lc[i] ?? 'green').toString() : 'green';
            hazards.add(HazardVM(name: hName, light: light));
          }

          final crop = CropVM(
            name: name.isEmpty ? '(未命名作物)' : name,
            acreage: acreage,
            hazards: hazards,
          );

          // ✅ 只收「黃/紅作物」
          if (crop.isWarning) crops.add(crop);
        }

        if (crops.isEmpty) continue; // ✅ 這個鄉鎮沒有黃/紅就不顯示

        // 作物排序：紅在上、黃在下
        crops.sort((a, b) => b.maxSev.compareTo(a.maxSev));

        towns.add(TownVM(town: town, crops: crops));
      }

      // 鄉鎮排序：紅在上、黃在下（只剩黃/紅）
      towns.sort((a, b) => b.maxSev.compareTo(a.maxSev));

      setState(() {
        vm = _PageVM(initialDate: initialDate, towns: towns);
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

  @override
  Widget build(BuildContext context) {
    final page = vm;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      // ✅ 你的 AppBar
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
              : (page == null)
                  ? _ErrorView(error: '資料為空', onRetry: _load)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      children: [
                        _SummaryCard(
                          primaryColor: _primaryColor,
                          initialDate: page.initialDate,
                          red: page.redCropTotal,
                          yellow: page.yellowCropTotal,
                          total: page.warningCropTotal,
                        ),
                        const SizedBox(height: 12),

                        if (page.towns.isEmpty)
                          _EmptyState(primaryColor: _primaryColor),

                        ...page.towns.map((t) {
                          final isExpanded = expandedTown == t.town;
                          return _TownCard(
                            primaryColor: _primaryColor,
                            town: t,
                            expanded: isExpanded,
                            onToggle: () {
                              setState(() {
                                expandedTown = isExpanded ? null : t.town;
                              });
                            },
                          );
                        }).toList(),

                        // ✅ 你指定的資料來源
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
    );
  }
}

// ============================
// 4) Widgets (UX optimized)
// ============================
class _SummaryCard extends StatelessWidget {
  final Color primaryColor;
  final String initialDate;
  final int red;
  final int yellow;
  final int total;

  const _SummaryCard({
    required this.primaryColor,
    required this.initialDate,
    required this.red,
    required this.yellow,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ 字體跟隨系統字體大小（農民可能調很大）
    final textScale = MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.4);

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
          Text(
            '資料日期：$initialDate',
            textScaleFactor: textScale,
            style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),

          // ✅ 只顯示紅/黃，綠不出現
          Row(
            children: [
              _CountPill(label: '紅燈', value: red, color: const Color(0xFFC62828)),
              const SizedBox(width: 8),
              _CountPill(label: '黃燈', value: yellow, color: const Color(0xFFF9A825)),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            '目前只顯示「黃燈 / 紅燈」鄉鎮與作物（綠燈不顯示）。共 $total 筆警示作物。',
            textScaleFactor: textScale,
            style: const TextStyle(color: Colors.black45, height: 1.3),
          ),
          const SizedBox(height: 6),
          Text(
            '點鄉鎮可展開查看：哪些作物、哪個災害在黃/紅燈。',
            textScaleFactor: textScale,
            style: TextStyle(
              color: primaryColor.withOpacity(0.95),
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _CountPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.4);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.28)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$label $value',
                textScaleFactor: textScale,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TownCard extends StatelessWidget {
  final Color primaryColor;
  final TownVM town;
  final bool expanded;
  final VoidCallback onToggle;

  const _TownCard({
    required this.primaryColor,
    required this.town,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.4);

    // 只會是 yellow/red
    final isRedTown = town.redCropCount > 0;
    final townLight = isRedTown ? 'red' : 'yellow';
    final color = colorOfLight(townLight);

    final topHazards = town.topHazards(limit: 3);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onToggle,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 82,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ✅ 鄉鎮名稱：大字體也不爆
                              Text(
                                town.town,
                                textScaleFactor: textScale,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // ✅ 關鍵數字：更直覺
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  _MetaPill(icon: Icons.grass, text: '警示作物 ${town.cropCount}'),
                                  _MetaPill(icon: Icons.error_outline, text: '紅 ${town.redCropCount} / 黃 ${town.yellowCropCount}'),
                                ],
                              ),

                              if (topHazards.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: topHazards.map((h) => _MiniTag(text: h)).toList(),
                                )
                              ],
                            ],
                          ),
                        ),

                        // badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: color.withOpacity(0.26)),
                          ),
                          child: Text(
                            textOfLight(townLight),
                            textScaleFactor: textScale,
                            style: TextStyle(color: color, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(expanded ? Icons.expand_less : Icons.expand_more, color: Colors.black45),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (expanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  children: town.warningCrops.map((c) => _CropCard(crop: c)).toList(),
                ),
              ),
            ],
          ],
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
    final textScale = MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.4);

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
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            text,
            textScaleFactor: textScale,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String text;
  const _MiniTag({required this.text});

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.35);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Text(
        text,
        textScaleFactor: textScale,
        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
      ),
    );
  }
}

class _CropCard extends StatelessWidget {
  final CropVM crop;
  const _CropCard({required this.crop});

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.4);

    final cropLight = crop.riskLight; // yellow/red only here
    final cropColor = colorOfLight(cropLight);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // title
          Row(
            children: [
              Expanded(
                child: Text(
                  crop.name,
                  textScaleFactor: textScale,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: cropColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: cropColor.withOpacity(0.25)),
                ),
                child: Text(
                  textOfLight(cropLight),
                  textScaleFactor: textScale,
                  style: TextStyle(color: cropColor, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (crop.acreage.isNotEmpty) _PlainChip(text: '面積 ${crop.acreage}'),
              // ✅ 只顯示黃/紅災害 chip
              ...crop.warningHazards.map((h) => _LightChip(text: h.name, light: h.light)),
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
    final textScale = MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
      ),
      child: Text(
        text,
        textScaleFactor: textScale,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _LightChip extends StatelessWidget {
  final String text;
  final String light; // yellow/red
  const _LightChip({required this.text, required this.light});

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.35);

    final c = colorOfLight(light);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            text,
            textScaleFactor: textScale,
            style: TextStyle(fontWeight: FontWeight.w900, color: c),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color primaryColor;
  const _EmptyState({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.4);

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [
          Icon(Icons.verified, color: primaryColor, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '目前沒有黃燈 / 紅燈警示（因此列表不顯示綠燈資料）。',
              textScaleFactor: textScale,
              style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
            ),
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
    final textScale = MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.4);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 10),
            Text('讀取失敗', textScaleFactor: textScale, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              error,
              textScaleFactor: textScale,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('重試')),
          ],
        ),
      ),
    );
  }
}
