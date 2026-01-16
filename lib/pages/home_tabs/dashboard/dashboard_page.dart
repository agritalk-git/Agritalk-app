import 'package:flutter/material.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:chcg_iot_app/pages/home_tabs/AlertSettingPage.dart';
import 'package:chcg_iot_app/pages/home_tabs/autocontrol.dart';
import 'package:chcg_iot_app/pages/home_tabs/observationhistory.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'camera_live_page.dart';
import 'widgets.dart';

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
  final Set<String> _pausedCameras = {};
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
                icon: Icon(_listMode ? Icons.grid_view_rounded : Icons.view_list_rounded),
                onPressed: () => setState(() => _listMode = !_listMode),
              ),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            sliver: _listMode
                ? _buildListByDeviceSliver()
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final device = widget.devices[index];
                        final deviceObservations = (device["observationlatest"] as List).toList();
                        final deviceFeature = (device["deviceFeature"] as List).toList();
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
  Widget _buildDeviceCard(dynamic device, List<dynamic> deviceObservations, List<dynamic> deviceFeature) {
    final cameras = deviceObservations
        .where((o) => (o['featureEnglishName'] ?? '').toString().toLowerCase() == 'camera')
        .toList();

    final others = deviceObservations
        .where((o) => (o['featureEnglishName'] ?? '').toString().toLowerCase() != 'camera')
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

    final featureUnitMap = {
      for (var f in deviceFeature)
        (f['featureEnglishName'] ?? '').toString().toLowerCase(): (f['unit'] ?? '').toString(),
    };

    final enrichedOthers = others.map((item) {
      final key = (item['featureEnglishName'] ?? '').toString().toLowerCase();
      final unit = featureUnitMap[key] ?? '';
      return {...item, 'unit': unit};
    }).toList();

    final scale = MediaQuery.textScaleFactorOf(context);
    final crossAxis = scale >= 1.3 ? 1 : 2;

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

            // Cameras
            ...cameras.map((c) => DashboardCameraCard(
                  obs: c,
                  isPaused: _pausedCameras.contains((c['value'] ?? '').toString()),
                  onOpenFullscreen: () => _openFullscreenCamera(context, (c['value'] ?? '').toString()),
                )),

            if (enrichedOthers.isNotEmpty) ...[
              SizedBox(height: 0.8.h),
              MasonryGridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxis,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                itemCount: enrichedOthers.length,
                itemBuilder: (context, i) => ObservationGridCard(
                  obs: enrichedOthers[i],
                  onViewHistory: (o) => _viewHistory(context, o),
                  onViewAutoControl: (o) => _viewAutoControl(context, o),
                  onOpenAlertSetting: (o) => _openAlertSetting(context, o),
                ),
              ),
            ],
          ],
        ),
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
        .where((o) => (o['featureEnglishName'] ?? '').toString().toLowerCase() == 'camera')
        .toList();

    final others = allObs
        .where((o) => (o['featureEnglishName'] ?? '').toString().toLowerCase() != 'camera')
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

          ...cameras.map((c) => DashboardCameraListTile(
                obs: c,
                isPaused: _pausedCameras.contains((c['value'] ?? '').toString()),
                onOpenFullscreen: () => _openFullscreenCamera(context, (c['value'] ?? '').toString()),
              )),

          ...enrichedOthers.map((o) => ObservationListItem(
                obs: o,
                onViewHistory: (x) => _viewHistory(context, x),
                onViewAutoControl: (x) => _viewAutoControl(context, x),
                onOpenAlertSetting: (x) => _openAlertSetting(context, x),
              )),
        ],
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

  void _openAlertSetting(BuildContext context, dynamic obs) {
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

  // =========================
  // Fullscreen Camera + PTZ
  // =========================
  void _openFullscreenCamera(BuildContext context, String url) {
    setState(() => _pausedCameras.add(url));

    final u = Uri.parse(url);

    String? username;
    String? password;
    if (u.userInfo.isNotEmpty && u.userInfo.contains(':')) {
      final parts = u.userInfo.split(':');
      username = parts[0];
      password = parts[1];
    }

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
    final userInfoInUrl = (username != null && password != null) ? '$username:$password@' : '';
    final controlBase = '$ctrlScheme://$userInfoInUrl$authority/cgi-bin/camctrl/camctrl.cgi';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraLivePage(
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
