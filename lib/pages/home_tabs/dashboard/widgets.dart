import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:chcg_iot_app/core/hlscamera.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:chcg_iot_app/core/observation_icons.dart';

final apiService = ApiService();

typedef ObsCallback = void Function(dynamic obs);

class DashboardCameraCard extends StatelessWidget {
  final dynamic obs;
  final bool isPaused;
  final VoidCallback onOpenFullscreen;

  const DashboardCameraCard({
    super.key,
    required this.obs,
    required this.isPaused,
    required this.onOpenFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final alias = (obs['alias'] ?? '').toString();
    final featureName = alias.isNotEmpty ? alias : (obs['deviceFeatureName'] ?? '').toString();
    final serialId = (obs['serialId'] ?? '').toString();
    final time = (obs['time'] ?? '').toString();
    final url = (obs['value'] ?? '').toString();

    return GestureDetector(
      onTap: onOpenFullscreen,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(vertical: 1.h),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3.w),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))],
          border: Border.all(color: Colors.blue.shade100, width: 0.35.w),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3.w),
              child: AspectRatio(
                aspectRatio: 16 / 12,
                child: isPaused ? const ColoredBox(color: Colors.black12) : CameraViewer(url: url),
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              featureName,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: const Color(0xFF7B4DBB)),
              softWrap: true,
            ),
            SizedBox(height: 0.5.h),
            Text('編號：$serialId', style: TextStyle(fontSize: 14.sp, color: Colors.black54), textAlign: TextAlign.center),
            Text(time, style: TextStyle(fontSize: 13.sp, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class DashboardCameraListTile extends StatelessWidget {
  final dynamic obs;
  final bool isPaused;
  final VoidCallback onOpenFullscreen;

  const DashboardCameraListTile({
    super.key,
    required this.obs,
    required this.isPaused,
    required this.onOpenFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final alias = (obs['alias'] ?? '').toString();
    final featureName = alias.isNotEmpty ? alias : (obs['deviceFeatureName'] ?? '').toString();
    final time = (obs['time'] ?? '').toString();
    final url = (obs['value'] ?? '').toString();

    return Padding(
      padding: EdgeInsets.only(bottom: 1.2.h),
      child: GestureDetector(
        onTap: onOpenFullscreen,
        child: Container(
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3.w),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))],
            border: Border.all(color: Colors.blue.shade100, width: 0.35.w),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                featureName,
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: const Color(0xFF7B4DBB)),
                softWrap: true,
              ),
              SizedBox(height: 0.6.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(2.6.w),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: isPaused ? const ColoredBox(color: Colors.black12) : CameraViewer(url: url),
                ),
              ),
              SizedBox(height: 0.6.h),
              Text(time, style: TextStyle(fontSize: 13.sp, color: Colors.grey), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class ObservationGridCard extends StatelessWidget {
  final dynamic obs;
  final ObsCallback onViewHistory;
  final ObsCallback onViewAutoControl;
  final ObsCallback onOpenAlertSetting;

  const ObservationGridCard({
    super.key,
    required this.obs,
    required this.onViewHistory,
    required this.onViewAutoControl,
    required this.onOpenAlertSetting,
  });

  @override
  Widget build(BuildContext context) {
    final alias = (obs['alias'] ?? '').toString();
    final featureName = alias.isNotEmpty ? alias : (obs['deviceFeatureName'] ?? '').toString();
    final value = (obs['value'] ?? '').toString();
    final unit = (obs['unit'] ?? '').toString();
    final serialId = (obs['serialId'] ?? '').toString();
    final time = (obs['time'] ?? '').toString();
    final isActuator = (obs['style'] ?? '').toString().toLowerCase() == 'actuator';
    final iconData = ObservationIcons.getIcon(obs['deviceFeatureName']);

    return _ObservationCardBase(
      header: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '編號：$serialId',
              style: TextStyle(fontSize: 14.sp, color: Colors.black54, fontWeight: FontWeight.bold),
              softWrap: true,
            ),
          ),
          _MoreMenu(
            isActuator: isActuator,
            onAuto: () => onViewAutoControl(obs),
            onAlert: () => onOpenAlertSetting(obs),
          ),
        ],
      ),
      middle: isActuator
          ? _ActuatorSwitch(
              obs: obs,
              serialId: serialId,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                  child: Icon(iconData, size: 7.w, color: const Color(0xFF7B4DBB)),
                ),
                SizedBox(height: 0.7.h),
                Text(
                  '$value ${unit.isEmpty ? '' : unit}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.black87),
                  softWrap: true,
                ),
              ],
            ),
      footer: Column(
        children: [
          SizedBox(height: 0.8.h),
          Text(featureName, textAlign: TextAlign.center, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 0.3.h),
          Text(time, textAlign: TextAlign.center, style: TextStyle(fontSize: 14.sp, color: Colors.grey)),
          TextButton(
            onPressed: () => onViewHistory(obs),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF7B4DBB),
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('查看歷史資料', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class ObservationListItem extends StatelessWidget {
  final dynamic obs;
  final ObsCallback onViewHistory;
  final ObsCallback onViewAutoControl;
  final ObsCallback onOpenAlertSetting;

  const ObservationListItem({
    super.key,
    required this.obs,
    required this.onViewHistory,
    required this.onViewAutoControl,
    required this.onOpenAlertSetting,
  });

  @override
  Widget build(BuildContext context) {
    final alias = (obs['alias'] ?? '').toString();
    final featureName = alias.isNotEmpty ? alias : (obs['deviceFeatureName'] ?? '').toString();
    final serialId = (obs['serialId'] ?? '').toString();
    final time = (obs['time'] ?? '').toString();
    final valueRaw = (obs['value'] ?? '').toString();
    final unit = (obs['unit'] ?? '').toString();

    final isActuator = (obs['style'] ?? '').toString().toLowerCase() == 'actuator';
    final iconData = ObservationIcons.getIcon(obs['deviceFeatureName']);

    return Padding(
      padding: EdgeInsets.only(bottom: 1.2.h),
      child: _ObservationCardBase(
        header: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(2.6.w),
              decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
              child: Icon(iconData, size: 7.w, color: const Color(0xFF7B4DBB)),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(featureName, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700)),
                  SizedBox(height: 0.3.h),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text('編號：$serialId', style: TextStyle(fontSize: 13.5.sp, color: Colors.black54)),
                      Text(time, style: TextStyle(fontSize: 13.5.sp, color: Colors.black54)),
                    ],
                  ),
                ],
              ),
            ),
            _MoreMenu(
              isActuator: isActuator,
              onAuto: () => onViewAutoControl(obs),
              onAlert: () => onOpenAlertSetting(obs),
            ),
          ],
        ),
        middle: Padding(
          padding: EdgeInsets.only(top: 0.9.h),
          child: Row(
            children: [
              Expanded(
                child: isActuator
                    ? _ActuatorSwitch(obs: obs, serialId: serialId)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          unit.isEmpty ? valueRaw : '$valueRaw $unit',
                          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
              SizedBox(width: 2.w),
              TextButton(
                onPressed: () => onViewHistory(obs),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7B4DBB),
                  padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('查看歷史', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        footer: const SizedBox.shrink(),
      ),
    );
  }
}

/// ============ 小元件：共用底卡 ============
class _ObservationCardBase extends StatelessWidget {
  final Widget header;
  final Widget middle;
  final Widget footer;

  const _ObservationCardBase({
    required this.header,
    required this.middle,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3.w),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          middle,
          footer,
        ],
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  final bool isActuator;
  final VoidCallback onAuto;
  final VoidCallback onAlert;

  const _MoreMenu({
    required this.isActuator,
    required this.onAuto,
    required this.onAlert,
  });

  @override
  Widget build(BuildContext context) {
    return isActuator
        ? PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (key) {
              if (key == 'auto') onAuto();
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
              if (key == 'alert') onAlert();
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
}

/// ============ 致動器 Switch：封裝內部 Stateful ============
class _ActuatorSwitch extends StatefulWidget {
  final dynamic obs;
  final String serialId;

  const _ActuatorSwitch({required this.obs, required this.serialId});

  @override
  State<_ActuatorSwitch> createState() => _ActuatorSwitchState();
}

class _ActuatorSwitchState extends State<_ActuatorSwitch> {
  late bool isSwitchOn;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    final v = (widget.obs['value'] ?? '').toString().toLowerCase();
    isSwitchOn = v == 'true';
  }

  @override
  void didUpdateWidget(covariant _ActuatorSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果外部 obs 更新 value，也同步
    final v = (widget.obs['value'] ?? '').toString().toLowerCase();
    isSwitchOn = v == 'true';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        alignment: WrapAlignment.start,
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
                onChanged: isLoading
                    ? null
                    : (newValue) async {
                        setState(() => isLoading = true);
                        final success = await apiService.switchSetting(
                          deviceUUID: widget.obs['deviceUUID'],
                          featureEnglishName: widget.obs['featureEnglishName'],
                          serialId: widget.serialId,
                          newValue: newValue,
                        );
                        if (success && mounted) {
                          setState(() {
                            widget.obs['value'] = newValue.toString();
                            isSwitchOn = newValue;
                          });
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(success ? '開關成功' : '送出失敗')),
                          );
                        }
                        if (mounted) setState(() => isLoading = false);
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
