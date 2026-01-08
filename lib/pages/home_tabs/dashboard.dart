import 'package:flutter/material.dart';
import 'package:chcg_iot_app/core/observation_icons.dart';
import 'package:chcg_iot_app/core/hlscamera.dart';
import 'package:chcg_iot_app/pages/home_tabs/observationhistory.dart';
import 'package:chcg_iot_app/pages/home_tabs/autocontrol.dart';
import 'package:chcg_iot_app/pages/home_tabs/AlertSettingPage.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'dart:ui' show ImageFilter;
import 'package:flutter/services.dart';
import 'dart:async';

final apiService = ApiService();

class DashboardPage extends StatefulWidget {
  final List<dynamic> devices;
  final String areaName;

  const DashboardPage({
    super.key,
    required this.devices,
    required this.areaName,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // 記錄目前暫停顯示的串流（用 URL 辨識）
  final Set<String> _pausedCameras = {};

  // 是否為條列式
  bool _listMode = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            centerTitle: true,
            backgroundColor: const Color(0xFF7B4DBB),
            foregroundColor: Colors.white,
            elevation: 1,
            title: Text(
              '目標即時資料 - ${widget.areaName}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp),
            ),
            actions: [
              IconButton(
                tooltip: _listMode ? '切換成卡片網格' : '切換成條列式',
                icon: Icon(
                  _listMode ? Icons.grid_view_rounded : Icons.view_list_rounded,
                ),
                onPressed: () => setState(() => _listMode = !_listMode),
              ),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            sliver: _listMode
                ? _buildListByDeviceSliver() // ✅ List 模式（包含攝影機）
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final device = widget.devices[index];
                        final deviceObservations =
                            (device["observationlatest"] as List).toList();
                        final deviceFeature =
                            (device["deviceFeature"] as List).toList();
                        return _buildDeviceCard(device, deviceObservations, deviceFeature);
                      },
                      childCount: widget.devices.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // =========================
  // Grid / 卡片模式（每個 Device 一張卡）
  // =========================
  Widget _buildDeviceCard(
    dynamic device,
    List<dynamic> deviceObservations,
    List<dynamic> deviceFeature,
  ) {
    final cameras = deviceObservations
        .where((o) =>
            (o['featureEnglishName'] ?? '').toString().toLowerCase() == 'camera')
        .toList();

    final others = deviceObservations
        .where((o) =>
            (o['featureEnglishName'] ?? '').toString().toLowerCase() != 'camera')
        .toList()
      ..sort((a, b) {
        final aIsActuator = (a['style'] ?? '').toString().toLowerCase() == 'actuator';
        final bIsActuator = (b['style'] ?? '').toString().toLowerCase() == 'actuator';
        if (aIsActuator && !bIsActuator) return -1;
        if (!aIsActuator && bIsActuator) return 1;

        final aSerial = int.tryParse((a['serialId'] ?? '0').toString()) ?? 0;
        final bSerial = int.tryParse((b['serialId'] ?? '0').toString()) ?? 0;
        return aSerial.compareTo(bSerial);
      });

    // featureEnglishName -> unit
    final featureUnitMap = {
      for (var f in deviceFeature)
        (f['featureEnglishName'] ?? '').toString().toLowerCase(): (f['unit'] ?? '').toString(),
    };

    // 在 others 加上 unit
    final enrichedOthers = others.map((item) {
      final key = (item['featureEnglishName'] ?? '').toString().toLowerCase();
      final unit = featureUnitMap[key] ?? '';
      return {...item, 'unit': unit};
    }).toList();


   final scale = MediaQuery.textScaleFactorOf(context);
final crossAxis = scale >= 1.3 ? 1 : 2; // ✅ 字體大就自動變 1 欄，不會擠爆


    return Card(
      margin: EdgeInsets.symmetric(vertical: 1.h),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3.w),
        side: BorderSide(color: Colors.blue.shade100, width: 0.35.w),
      ),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device title
            Row(
              children: [
                Icon(Icons.sensors, size: 6.w, color: const Color(0xFF7B4DBB)),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    (device['name'] ?? '未命名裝置').toString(),
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF7B4DBB),
                    ),
                    softWrap: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: 0.6.h),

            // Cameras (full width)
            ...cameras.map(_buildCameraCard).toList(),

            // Others grid
            if (enrichedOthers.isNotEmpty) ...[
              SizedBox(height: 0.8.h),
              MasonryGridView.count(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  crossAxisCount: crossAxis,
  mainAxisSpacing: 12,
  crossAxisSpacing: 12,
  itemCount: enrichedOthers.length,
  itemBuilder: (context, i) => _buildObservationGridCard(enrichedOthers[i]),
)
            ],
          ],
        ),
      ),
    );
  }

  // =========================
  // Camera card (grid mode)
  // =========================
  Widget _buildCameraCard(dynamic obs) {
    final alias = (obs['alias'] ?? '').toString();
    final featureName = alias.isNotEmpty
        ? alias
        : (obs['deviceFeatureName'] ?? '').toString();
    final serialId = (obs['serialId'] ?? '').toString();
    final time = (obs['time'] ?? '').toString();
    final url = (obs['value'] ?? '').toString();

    return GestureDetector(
      onTap: () => _openFullscreenCamera(context, url),
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(vertical: 1.h),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3.w),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2)),
          ],
          border: Border.all(color: Colors.blue.shade100, width: 0.35.w),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3.w),
              child: AspectRatio(
                aspectRatio: 16 / 12,
                child: _pausedCameras.contains(url)
                    ? const ColoredBox(color: Colors.black12)
                    : CameraViewer(url: url),
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              featureName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
                color: const Color(0xFF7B4DBB),
              ),
              softWrap: true,
            ),
            SizedBox(height: 0.5.h),
            Text(
              '編號：$serialId',
              style: TextStyle(fontSize: 14.sp, color: Colors.black54),
              softWrap: true,
              textAlign: TextAlign.center,
            ),
            Text(
              time,
              style: TextStyle(fontSize: 13.sp, color: Colors.grey),
              softWrap: true,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // Grid observation card (no ellipsis, no overflow)
  // =========================
  Widget _buildObservationGridCard(dynamic obs) {
    final alias = (obs['alias'] ?? '').toString();
    final featureName = alias.isNotEmpty
        ? alias
        : (obs['deviceFeatureName'] ?? '').toString();
    final value = (obs['value'] ?? '').toString();
    final unit = (obs['unit'] ?? '').toString();
    final serialId = (obs['serialId'] ?? '').toString();
    final time = (obs['time'] ?? '').toString();
    final isActuator = (obs['style'] ?? '').toString().toLowerCase() == 'actuator';

    final iconData = ObservationIcons.getIcon(obs['deviceFeatureName']);

    bool isSwitchOn = value.toLowerCase() == 'true';
    bool isSwitchLoading = false;

    return StatefulBuilder(
      builder: (context, setInner) {
        return Container(
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3.w),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // ✅ 讓內容自然長高
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top row: serial + menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '編號：$serialId',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                      softWrap: true,
                    ),
                  ),
                  _buildMoreMenu(obs, isActuator),
                ],
              ),
              SizedBox(height: 0.7.h),

              // Middle content
              if (isActuator)
                _buildActuatorMiddle(
                  context,
                  isSwitchOn: isSwitchOn,
                  isLoading: isSwitchLoading,
                  onToggle: (newValue) async {
                    setInner(() => isSwitchLoading = true);
                    final success = await apiService.switchSetting(
                      deviceUUID: obs['deviceUUID'],
                      featureEnglishName: obs['featureEnglishName'],
                      serialId: serialId,
                      newValue: newValue,
                    );
                    if (success && context.mounted) {
                      setInner(() {
                        obs['value'] = newValue.toString();
                        isSwitchOn = newValue;
                      });
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(success ? '開關成功' : '送出失敗')),
                      );
                    }
                    setInner(() => isSwitchLoading = false);
                  },
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(2.w),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(iconData, size: 7.w, color: const Color(0xFF7B4DBB)),
                    ),
                    SizedBox(height: 0.7.h),
                    Text(
                      '$value ${unit.isEmpty ? '' : unit}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      softWrap: true, // ✅ 不截斷、不省略
                    ),
                  ],
                ),

              SizedBox(height: 0.8.h),

              // Bottom info
              Text(
                featureName,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                softWrap: true,
              ),
              SizedBox(height: 0.3.h),
              Text(
                time,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.sp, color: Colors.grey),
                softWrap: true,
              ),

              // History button
              TextButton(
                onPressed: () => _viewHistory(context, obs),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7B4DBB),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '查看歷史資料',
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMoreMenu(dynamic obs, bool isActuator) {
    return isActuator
        ? PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (key) {
              if (key == 'auto') _viewAutoControl(context, obs);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'auto',
                child: Row(
                  children: [
                    Icon(Icons.settings_suggest_rounded, size: 18),
                    SizedBox(width: 6),
                    Text('自動控制設定'),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert, color: Colors.black54),
          )
        : PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (key) {
              if (key == 'alert') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AlertSettingPage(
                      obs: obs,
                      deviceUUID: obs['deviceUUID'],
                      featureEnglishName: obs['featureEnglishName'],
                      serialId: obs['serialId'],
                    ),
                  ),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'alert',
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18),
                    SizedBox(width: 6),
                    Text('警戒值設定'),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert, color: Colors.black54),
          );
  }

  Widget _buildActuatorMiddle(
    BuildContext context, {
    required bool isSwitchOn,
    required bool isLoading,
    required Future<void> Function(bool) onToggle,
  }) {
    // ✅ 用 Wrap：字變大也不會 overflow
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 6,
        children: [
          Text(
            isSwitchOn ? 'ON' : 'OFF',
            style: TextStyle(
              fontSize: 16.sp,
              color: isSwitchOn ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: Transform.scale(
              scale: 0.9,
              child: Switch.adaptive(
                value: isSwitchOn,
                onChanged: isLoading ? null : (v) => onToggle(v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // List mode (包含攝影機)
  // =========================
  Widget _buildListByDeviceSliver() {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, deviceIndex) {
        final device = widget.devices[deviceIndex];
        final deviceFeature = (device["deviceFeature"] as List).toList();
        return _buildDeviceSectionForListMode(device, deviceFeature);
      }, childCount: widget.devices.length),
    );
  }

  Widget _buildDeviceSectionForListMode(dynamic device, List<dynamic> deviceFeature) {
    final deviceName = (device['name'] ?? '未命名裝置').toString();

    final List<dynamic> allObs = (device['observationlatest'] as List).toList();

    final cameras = allObs
        .where((o) =>
            (o['featureEnglishName'] ?? '').toString().toLowerCase() == 'camera')
        .toList();

    final others = allObs
        .where((o) =>
            (o['featureEnglishName'] ?? '').toString().toLowerCase() != 'camera')
        .toList()
      ..sort((a, b) {
        final aIsActuator = (a['style'] ?? '').toString().toLowerCase() == 'actuator';
        final bIsActuator = (b['style'] ?? '').toString().toLowerCase() == 'actuator';
        if (aIsActuator && !bIsActuator) return -1;
        if (!aIsActuator && bIsActuator) return 1;

        final aSerial = int.tryParse((a['serialId'] ?? '0').toString()) ?? 0;
        final bSerial = int.tryParse((b['serialId'] ?? '0').toString()) ?? 0;
        return aSerial.compareTo(bSerial);
      });

    if (allObs.isEmpty) return const SizedBox.shrink();

    final featureUnitMap = {
      for (var f in deviceFeature)
        (f['featureEnglishName'] ?? '').toString().toLowerCase(): (f['unit'] ?? '').toString(),
    };

    final enrichedOthers = others.map((item) {
      final key = (item['featureEnglishName'] ?? '').toString().toLowerCase();
      final unit = featureUnitMap[key] ?? '';
      return {...item, 'unit': unit};
    }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device title
          Padding(
            padding: EdgeInsets.symmetric(vertical: 0.5.h, horizontal: 1.w),
            child: Text(
              deviceName,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF7B4DBB),
              ),
              softWrap: true,
            ),
          ),

          // ✅ List mode cameras
          ...cameras.map(_buildCameraListTile).toList(),

          // Others
          ...enrichedOthers.map(_buildListItem).toList(),
        ],
      ),
    );
  }

  Widget _buildCameraListTile(dynamic obs) {
    final alias = (obs['alias'] ?? '').toString();
    final featureName =
        alias.isNotEmpty ? alias : (obs['deviceFeatureName'] ?? '').toString();
    final time = (obs['time'] ?? '').toString();
    final url = (obs['value'] ?? '').toString();

    return Padding(
      padding: EdgeInsets.only(bottom: 1.2.h),
      child: GestureDetector(
        onTap: () => _openFullscreenCamera(context, url),
        child: Container(
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3.w),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2)),
            ],
            border: Border.all(color: Colors.blue.shade100, width: 0.35.w),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                featureName,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF7B4DBB),
                ),
                softWrap: true,
              ),
              SizedBox(height: 0.6.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(2.6.w),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: _pausedCameras.contains(url)
                      ? const ColoredBox(color: Colors.black12)
                      : CameraViewer(url: url),
                ),
              ),
              SizedBox(height: 0.6.h),
              Text(
                time,
                style: TextStyle(fontSize: 13.sp, color: Colors.grey),
                textAlign: TextAlign.center,
                softWrap: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

 Widget _buildListItem(dynamic obs) {
  final alias = (obs['alias'] ?? '').toString();
  final featureName =
      alias.isNotEmpty ? alias : (obs['deviceFeatureName'] ?? '').toString();
  final serialId = (obs['serialId'] ?? '').toString();
  final time = (obs['time'] ?? '').toString();
  final valueRaw = (obs['value'] ?? '').toString();
  final unit = (obs['unit'] ?? '').toString();

  final isActuator = (obs['style'] ?? '').toString().toLowerCase() == 'actuator';
  final iconData = ObservationIcons.getIcon(obs['deviceFeatureName']);

  bool isSwitchOn = valueRaw.toLowerCase() == 'true';
  bool isSwitchLoading = false;

  return Padding(
    padding: EdgeInsets.only(bottom: 1.2.h),
    child: StatefulBuilder(
      builder: (context, setInner) {
        return Container(
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3.w),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2)),
            ],
            border: Border.all(color: Colors.blue.shade100, width: 0.35.w),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top row: icon + title + menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(2.6.w),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconData, size: 7.w, color: const Color(0xFF7B4DBB)),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          featureName,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          softWrap: true,
                        ),
                        SizedBox(height: 0.3.h),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            Text(
                              '編號：$serialId',
                              style: TextStyle(fontSize: 13.5.sp, color: Colors.black54),
                              softWrap: true,
                            ),
                            Text(
                              time,
                              style: TextStyle(fontSize: 13.5.sp, color: Colors.black54),
                              softWrap: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildMoreMenu(obs, isActuator),
                ],
              ),

              SizedBox(height: 0.9.h),

              // Value / Switch row + History button on the right (compact)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: isActuator
                        ? Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                isSwitchOn ? 'ON' : 'OFF',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: isSwitchOn ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Theme(
                                data: Theme.of(context).copyWith(
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Transform.scale(
                                  scale: 0.9,
                                  child: Switch.adaptive(
                                    value: isSwitchOn,
                                    onChanged: isSwitchLoading
                                        ? null
                                        : (newValue) async {
                                            setInner(() => isSwitchLoading = true);
                                            final success = await apiService.switchSetting(
                                              deviceUUID: obs['deviceUUID'],
                                              featureEnglishName: obs['featureEnglishName'],
                                              serialId: serialId,
                                              newValue: newValue,
                                            );
                                            if (success && context.mounted) {
                                              setInner(() {
                                                obs['value'] = newValue.toString();
                                                isSwitchOn = newValue;
                                              });
                                            }
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(success ? '開關成功' : '送出失敗')),
                                              );
                                            }
                                            setInner(() => isSwitchLoading = false);
                                          },
                                  ),
                                ),
                              ),
                            ],
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              unit.isEmpty ? valueRaw : '$valueRaw $unit',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                  ),

                  SizedBox(width: 2.w),

                  TextButton(
                    onPressed: () => _viewHistory(context, obs),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF7B4DBB),
                      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '查看歷史',
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

  // =========================
  // Navigation
  // =========================
  void _viewHistory(BuildContext context, dynamic obs) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ObservationHistoryPage(
          deviceUUID: obs['deviceUUID'],
          featureEnglishName: obs['featureEnglishName'],
          serialId: obs['serialId'],
          alias: obs['alias'],
          deviceFeatureName: obs['deviceFeatureName'],
        ),
      ),
    );
  }

  void _viewAutoControl(BuildContext context, dynamic obs) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AutoControlPage(
          obs: obs,
          deviceUUID: obs['deviceUUID'],
          featureEnglishName: obs['featureEnglishName'],
          serialId: obs['serialId'],
        ),
      ),
    );
  }

  // =========================
  // Fullscreen Camera + PTZ
  // =========================
  void _openFullscreenCamera(BuildContext context, String url) {
    setState(() => _pausedCameras.add(url));

    Uri u = Uri.parse(url);

    // 取得帳密（若 url 有 user:pass@）
    final userInfo = u.userInfo;
    String? username;
    String? password;
    if (userInfo.isNotEmpty && userInfo.contains(':')) {
      final parts = userInfo.split(':');
      username = parts[0];
      password = parts[1];
    }

    // 推得控制端點 base
    String ctrlScheme;
    int? ctrlPort;

    if (u.scheme == 'http' || u.scheme == 'https') {
      ctrlScheme = u.scheme;
      ctrlPort = u.hasPort ? u.port : null;
    } else {
      ctrlScheme = 'http';
      if (u.hasPort) {
        final p = u.port - 1;
        ctrlPort = p > 0 ? p : null;
      } else {
        ctrlPort = null;
      }
    }

    final authority = (ctrlPort != null) ? '${u.host}:$ctrlPort' : u.host;
    final userInfoInUrl =
        (username != null && password != null) ? '$username:$password@' : '';

    final controlBase =
        '$ctrlScheme://$userInfoInUrl$authority/cgi-bin/camctrl/camctrl.cgi';

    Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => _CameraLivePage(
      url: url,
      controlBase: controlBase,
      username: username,
      password: password,
    ),
  ),
).then((_) {
  if (mounted) setState(() => _pausedCameras.remove(url));
});

  }
}

class _CameraLivePage extends StatefulWidget {
  final String url;
  final String controlBase;
  final String? username;
  final String? password;

  const _CameraLivePage({
    required this.url,
    required this.controlBase,
    this.username,
    this.password,
  });

  @override
  State<_CameraLivePage> createState() => _CameraLivePageState();
}

class _CameraLivePageState extends State<_CameraLivePage> {
  bool _landscapeFullscreen = false;

  // pinch/zoom 控制器
  final TransformationController _tc = TransformationController();

  // 控制盤預留高度（你可以依手感微調）
  static const double _padHeight = 230;
  static const double _padGap = 16;

  Future<void> _restorePortrait() async {
  // 還原系統 UI
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // 強制回直向（這一行是關鍵）
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
}


  @override
void dispose() {
  _restorePortrait(); // ✅ 不管怎樣離開，一定回直向
  _tc.dispose();
  super.dispose();
}

  Future<void> _enterLandscapeFullscreen() async {
    setState(() => _landscapeFullscreen = true);

    // 橫向 + 隱藏系統列（沉浸）
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _exitFullscreenIfNeeded() async {
    if (!_landscapeFullscreen) return;

    setState(() => _landscapeFullscreen = false);

    // 還原系統列
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // 還原允許方向（你也可以只留 portraitUp）
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final showPad = !_landscapeFullscreen;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isLandscape
      ? null
      : AppBar(
          centerTitle: true,
          backgroundColor: const Color(0xFF7B4DBB),
          foregroundColor: Colors.white,
          title: const Text('攝影機直播'),
          actions: [
            IconButton(
              tooltip: _landscapeFullscreen ? '退出全螢幕' : '橫向全螢幕',
              icon: Icon(_landscapeFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
              onPressed: () async {
                if (_landscapeFullscreen) {
                  await _exitFullscreenIfNeeded();
                } else {
                  await _enterLandscapeFullscreen();
                }
              },
            ),
            IconButton(
              tooltip: '重置縮放',
              icon: const Icon(Icons.refresh),
              onPressed: () => _tc.value = Matrix4.identity(),
            ),
          ],
        ),
      body: Stack(
        children: [
          // =========================
          // 影像區：預留控制盤高度，避免重疊
          // =========================
          Positioned.fill(
            bottom: showPad ? (_padHeight + _padGap) : 0,
            child: Center(
              child: ClipRect(
                child: InteractiveViewer(
                  transformationController: _tc,
                  panEnabled: true,
                  scaleEnabled: true,
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: AspectRatio(
                    aspectRatio: 16 / 12,
                    child: CameraViewer(url: widget.url),
                  ),
                ),
              ),
            ),
          ),

          // =========================
          // 控制盤：只有非全螢幕才顯示
          // =========================
          if (showPad)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: _padGap),
                  child: SizedBox(
                    height: _padHeight,
                    child: _PtzPad(
                      controlBase: widget.controlBase,
                      username: widget.username,
                      password: widget.password,
                    ),
                  ),
                ),
              ),
            ),
        
                if (isLandscape)
        Positioned(
          top: 8,
          left: 8,
          child: SafeArea(
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),

        ],
      ),
    );
  }

}


// =========================
// PTZ Pad (unchanged)
// =========================
class _PtzPad extends StatefulWidget {
  final String controlBase;
  final String? username;
  final String? password;

  const _PtzPad({required this.controlBase, this.username, this.password});

  @override
  State<_PtzPad> createState() => _PtzPadState();
}

class _PtzPadState extends State<_PtzPad> {
  bool _zoomBusy = false;
  bool _moving = false;
  String? _movingDir;
  Timer? _nudgeTimer;

  Future<void> _startMove(String dir) async {
    if (_moving && _movingDir == dir) return;
    _moving = true;
    _movingDir = dir;
    HapticFeedback.selectionClick();
    await apiService.cameraMove(
      controlBase: widget.controlBase,
      direction: dir,
      username: widget.username,
      password: widget.password,
    );
  }

  Future<void> _stopMove() async {
    if (!_moving) return;
    _moving = false;
    final ok = await apiService.cameraMove(
      controlBase: widget.controlBase,
      direction: 'stop',
      username: widget.username,
      password: widget.password,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PTZ 停止失敗')),
      );
    }
    _movingDir = null;
  }

  Future<void> _nudge(String dir, {int ms = 200}) async {
    await _startMove(dir);
    _nudgeTimer?.cancel();
    _nudgeTimer = Timer(Duration(milliseconds: ms), _stopMove);
  }

  Future<void> _zoom(String action) async {
    if (_zoomBusy) return;
    setState(() => _zoomBusy = true);
    HapticFeedback.lightImpact();
    final ok = await apiService.cameraZoom(
      controlBase: widget.controlBase,
      action: action,
      username: widget.username,
      password: widget.password,
    );
    if (!mounted) return;
    setState(() => _zoomBusy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('變焦失敗')),
      );
    }
  }

  Widget _softCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(10),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.28),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _roundBtn(
    IconData icon, {
    VoidCallback? onPressed,
    bool active = false,
    double size = 56,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF7B4DBB).withOpacity(0.95)
            : Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: active ? Colors.white : const Color(0xFF7B4DBB)),
        onPressed: onPressed,
      ),
    );
  }

  Widget _dirBtn(IconData icon, String dir, {double size = 56}) {
    final isActive = _moving && _movingDir == dir;
    return _roundBtn(
      icon,
      active: isActive,
      size: size,
      onPressed: () => _nudge(dir),
    );
  }

  @override
  void dispose() {
    _nudgeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double btnSize = 56;
    const double gap = 10;
    const double sideGap = 12;

    return _softCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _zoomColumn(icon: Icons.zoom_in, action: 'tele', size: 50),
          const SizedBox(width: sideGap),
          _dpad(btnSize: btnSize, gap: gap),
          const SizedBox(width: sideGap),
          _zoomColumn(icon: Icons.zoom_out, action: 'wide', size: 50),
        ],
      ),
    );
  }

  Widget _dpad({required double btnSize, required double gap}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: btnSize + gap),
            _dirBtn(Icons.keyboard_arrow_up_rounded, 'up', size: btnSize),
            SizedBox(width: btnSize + gap),
          ],
        ),
        SizedBox(height: gap),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dirBtn(Icons.keyboard_arrow_left_rounded, 'left', size: btnSize),
            SizedBox(width: gap),
            _dirBtn(Icons.stop_rounded, 'home', size: btnSize),
            SizedBox(width: gap),
            _dirBtn(Icons.keyboard_arrow_right_rounded, 'right', size: btnSize),
          ],
        ),
        SizedBox(height: gap),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: btnSize + gap),
            _dirBtn(Icons.keyboard_arrow_down_rounded, 'down', size: btnSize),
            SizedBox(width: btnSize + gap),
          ],
        ),
      ],
    );
  }

  Widget _zoomColumn({
    required IconData icon,
    required String action,
    double size = 50,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _roundBtn(
          icon,
          onPressed: _zoomBusy ? null : () => _zoom(action),
          size: size,
        ),
      ],
    );
  }
}
