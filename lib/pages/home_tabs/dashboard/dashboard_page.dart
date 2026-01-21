import 'package:flutter/material.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:chcg_iot_app/pages/home_tabs/AlertSettingPage.dart';
import 'package:chcg_iot_app/pages/home_tabs/autocontrol.dart';
import 'package:chcg_iot_app/pages/home_tabs/observationhistory.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'camera_live_page.dart';
import 'widgets.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

final apiService = ApiService();

class DashboardPage extends StatefulWidget {
  final String targetUUID;
  final String areaName;

  const DashboardPage({
    super.key,
    required this.targetUUID,
    required this.areaName,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final Set<String> _pausedCameras = {};
  Timer? _refreshTimer;
  bool _loading = true;
  bool _refreshing = false;
  List<dynamic> _devices = [];

  bool _listMode = true;

  // ✅ 訂閱狀態快取（deviceUUID -> subscribed）
  final Map<String, bool> _subscribedMap = {}; // deviceUUID -> subscribed
  final Set<String> _subLoadingSet = {}; // 避免同一台狂點

  Future<void> _refreshSubscribeStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty || token == 'GUEST_MODE') {
        if (!mounted) return;
        setState(() => _subscribedMap.clear());
        return;
      }

      final Map<String, bool> map = {};

      for (final d in _devices) {
        final duuid = (d['deviceUUID'] ?? '').toString();
        if (duuid.isEmpty) continue;

        try {
          final status = await apiService.getDeviceSubscribeStatus(
            token: token,
            key: duuid,
          );
          // print(status);
          map[duuid] = (status['subscribed'] == true);
        } catch (_) {
          map[duuid] = false;
        }
      }

      if (!mounted) return;
      setState(() {
        _subscribedMap
          ..clear()
          ..addAll(map);
      });
    } catch (_) {}
  }

  Future<void> _toggleSubscribe(dynamic device) async {
    final deviceUUID = (device['deviceUUID'] ?? '').toString();
    if (deviceUUID.isEmpty) return;

    if (_subLoadingSet.contains(deviceUUID)) return;
    _subLoadingSet.add(deviceUUID);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty || token == 'GUEST_MODE') {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('請先登入才能訂閱裝置推播')));
      }
      _subLoadingSet.remove(deviceUUID);
      return;
    }

    final current = _subscribedMap[deviceUUID] ?? false;
    final next = !current;

    // ✅ 樂觀更新
    if (mounted) setState(() => _subscribedMap[deviceUUID] = next);

    try {
      await apiService.subscribeDevice(
        token: token,
        key: deviceUUID,
        enabled: next,
        notifyOnControl: next,
        channel: "FCM",
        targetUUID: widget.targetUUID,
      );

      // ✅ POST 後再 GET 一次確認（避免不同裝置/不同手機狀態不一致）
      final status = await apiService.getDeviceSubscribeStatus(
        token: token,
        key: deviceUUID,
      );
      

      final subscribed = (status['subscribed'] == true);

      if (!mounted) return;
      setState(() => _subscribedMap[deviceUUID] = subscribed);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(subscribed ? '已訂閱推播' : '已取消訂閱')));
    } catch (e) {
      // ❌ 失敗還原
      if (mounted) {
        setState(() => _subscribedMap[deviceUUID] = current);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('訂閱失敗: $e')));
      }
    } finally {
      _subLoadingSet.remove(deviceUUID);
    }
  }

  bool _deviceHasActuator(dynamic device) {
  final List obs = (device['observationlatest'] as List?) ?? [];
  return obs.any((o) =>
      (o['style'] ?? '').toString().toLowerCase() == 'actuator');
}

  @override
  void initState() {
    super.initState();
    _loadAndStartAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAndStartAutoRefresh() async {
    await _refreshDevices(showLoading: true);

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshDevices(); // 背景刷新
    });
  }

  Future<void> _refreshDevices({bool showLoading = false}) async {
    if (_refreshing) return;
    _refreshing = true;

    if (showLoading && mounted) {
      setState(() => _loading = true);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty || token == 'GUEST_MODE') {
        if (mounted) {
          setState(() {
            _devices = [];
            _loading = false;
          });
        }
        return;
      }

      final devices = await apiService.fetchDevices(token, widget.targetUUID);

      // ✅ 排序（跟你原本 war_room 一樣）
      devices?.sort((a, b) {
        final aName = (a['name'] ?? '').toString().toLowerCase();
        final bName = (b['name'] ?? '').toString().toLowerCase();

        int getPriority(String name) {
          if (name.contains('攝影')) return 1;
          if (name.contains('控制')) return 2;
          return 3;
        }

        final aPriority = getPriority(aName);
        final bPriority = getPriority(bName);

        if (aPriority != bPriority) return aPriority.compareTo(bPriority);
        return aName.compareTo(bName);
      });

      if (!mounted) return;
      setState(() {
        _devices = devices ?? [];
        _loading = false;
      });

      await _refreshSubscribeStates();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      // 你也可以改成靜默，不要每 5 秒跳 snackbar
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('刷新失敗: $e')));
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0F2F5),
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
            sliver:
                _listMode
                    ? _buildListByDeviceSliver()
                    : SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final device = _devices[index];
                        final deviceObservations =
                            (device["observationlatest"] as List).toList();
                        final deviceFeature =
                            (device["deviceFeature"] as List).toList();
                        return _buildDeviceCard(
                          device,
                          deviceObservations,
                          deviceFeature,
                        );
                      }, childCount: _devices.length),
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
    final cameras =
        deviceObservations
            .where(
              (o) =>
                  (o['featureEnglishName'] ?? '').toString().toLowerCase() ==
                  'camera',
            )
            .toList();

    final others =
        deviceObservations
            .where(
              (o) =>
                  (o['featureEnglishName'] ?? '').toString().toLowerCase() !=
                  'camera',
            )
            .toList()
          ..sort((a, b) {
            final aIsActuator =
                (a['style'] ?? '').toString().toLowerCase() == 'actuator';
            final bIsActuator =
                (b['style'] ?? '').toString().toLowerCase() == 'actuator';
            if (aIsActuator && !bIsActuator) return -1;
            if (!aIsActuator && bIsActuator) return 1;

            final aSerial =
                int.tryParse((a['serialId'] ?? '0').toString()) ?? 0;
            final bSerial =
                int.tryParse((b['serialId'] ?? '0').toString()) ?? 0;
            return aSerial.compareTo(bSerial);
          });

    final featureUnitMap = {
      for (var f in deviceFeature)
        (f['featureEnglishName'] ?? '').toString().toLowerCase():
            (f['unit'] ?? '').toString(),
    };

    final enrichedOthers =
        others.map((item) {
          final key =
              (item['featureEnglishName'] ?? '').toString().toLowerCase();
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
                // ✅ 訂閱按鈕
                Builder(builder: (_) {
  // ✅ 沒有 actuator 就不顯示
  if (!_deviceHasActuator(device)) {
    return const SizedBox.shrink();
  }

  final duuid = (device['deviceUUID'] ?? '').toString();
  final subscribed = _subscribedMap[duuid] ?? false;

  return IconButton(
    tooltip: subscribed ? '取消訂閱推播' : '訂閱推播',
    icon: Icon(
      subscribed
          ? Icons.notifications_active_rounded
          : Icons.notifications_off_rounded,
      color: subscribed ? const Color(0xFF7B4DBB) : Colors.black45,
      size: 6.w,
    ),
    onPressed: () => _toggleSubscribe(device),
  );
}),

              ],
            ),
            SizedBox(height: 0.6.h),

            // Cameras
            ...cameras.map(
              (c) => DashboardCameraCard(
                obs: c,
                isPaused: _pausedCameras.contains(
                  (c['value'] ?? '').toString(),
                ),
                onOpenFullscreen:
                    () => _openFullscreenCamera(
                      context,
                      (c['value'] ?? '').toString(),
                    ),
              ),
            ),

            if (enrichedOthers.isNotEmpty) ...[
              SizedBox(height: 0.8.h),
              MasonryGridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxis,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                itemCount: enrichedOthers.length,
                itemBuilder:
                    (context, i) => ObservationGridCard(
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
        final device = _devices[deviceIndex];
        final deviceFeature = (device["deviceFeature"] as List).toList();
        return _buildDeviceSectionForListMode(device, deviceFeature);
      }, childCount: _devices.length),
    );
  }

  Widget _buildDeviceSectionForListMode(
    dynamic device,
    List<dynamic> deviceFeature,
  ) {
    final deviceName = (device['name'] ?? '未命名裝置').toString();
    final List<dynamic> allObs = (device['observationlatest'] as List).toList();

    final cameras =
        allObs
            .where(
              (o) =>
                  (o['featureEnglishName'] ?? '').toString().toLowerCase() ==
                  'camera',
            )
            .toList();

    final others =
        allObs
            .where(
              (o) =>
                  (o['featureEnglishName'] ?? '').toString().toLowerCase() !=
                  'camera',
            )
            .toList()
          ..sort((a, b) {
            final aIsActuator =
                (a['style'] ?? '').toString().toLowerCase() == 'actuator';
            final bIsActuator =
                (b['style'] ?? '').toString().toLowerCase() == 'actuator';
            if (aIsActuator && !bIsActuator) return -1;
            if (!aIsActuator && bIsActuator) return 1;

            final aSerial =
                int.tryParse((a['serialId'] ?? '0').toString()) ?? 0;
            final bSerial =
                int.tryParse((b['serialId'] ?? '0').toString()) ?? 0;
            return aSerial.compareTo(bSerial);
          });

    if (allObs.isEmpty) return const SizedBox.shrink();

    final featureUnitMap = {
      for (var f in deviceFeature)
        (f['featureEnglishName'] ?? '').toString().toLowerCase():
            (f['unit'] ?? '').toString(),
    };

    final enrichedOthers =
        others.map((item) {
          final key =
              (item['featureEnglishName'] ?? '').toString().toLowerCase();
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
            child: Row(
              children: [
                Expanded(
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
                Builder(builder: (_) {
  // ✅ 沒有 actuator 就不顯示
  if (!_deviceHasActuator(device)) {
    return const SizedBox.shrink();
  }

  final duuid = (device['deviceUUID'] ?? '').toString();
  final subscribed = _subscribedMap[duuid] ?? false;

  return IconButton(
    tooltip: subscribed ? '取消訂閱推播' : '訂閱推播',
    icon: Icon(
      subscribed
          ? Icons.notifications_active_rounded
          : Icons.notifications_off_rounded,
      color: subscribed ? const Color(0xFF7B4DBB) : Colors.black45,
    ),
    onPressed: () => _toggleSubscribe(device),
  );
}),

              ],
            ),
          ),

          ...cameras.map(
            (c) => DashboardCameraListTile(
              obs: c,
              isPaused: _pausedCameras.contains((c['value'] ?? '').toString()),
              onOpenFullscreen:
                  () => _openFullscreenCamera(
                    context,
                    (c['value'] ?? '').toString(),
                  ),
            ),
          ),

          ...enrichedOthers.map(
            (o) => ObservationListItem(
              obs: o,
              onViewHistory: (x) => _viewHistory(context, x),
              onViewAutoControl: (x) => _viewAutoControl(context, x),
              onOpenAlertSetting: (x) => _openAlertSetting(context, x),
            ),
          ),
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
        builder:
            (context) => ObservationHistoryPage(
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
        builder:
            (context) => AutoControlPage(
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
        builder:
            (_) => AlertSettingPage(
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
    final userInfoInUrl =
        (username != null && password != null) ? '$username:$password@' : '';
    final controlBase =
        '$ctrlScheme://$userInfoInUrl$authority/cgi-bin/camctrl/camctrl.cgi';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => CameraLivePage(
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
