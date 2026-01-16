import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:chcg_iot_app/core/hlscamera.dart';

final apiService = ApiService();

class CameraLivePage extends StatefulWidget {
  final String url;
  final String controlBase;
  final String? username;
  final String? password;

  const CameraLivePage({
    super.key,
    required this.url,
    required this.controlBase,
    this.username,
    this.password,
  });

  @override
  State<CameraLivePage> createState() => _CameraLivePageState();
}

class _CameraLivePageState extends State<CameraLivePage> {
  bool _landscapeFullscreen = false;
  final TransformationController _tc = TransformationController();

  static const double _padHeight = 230;
  static const double _padGap = 16;

  Future<void> _restorePortrait() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    _restorePortrait();
    _tc.dispose();
    super.dispose();
  }

  Future<void> _enterLandscapeFullscreen() async {
    setState(() => _landscapeFullscreen = true);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _exitFullscreenIfNeeded() async {
    if (!_landscapeFullscreen) return;
    setState(() => _landscapeFullscreen = false);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PTZ 停止失敗')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('變焦失敗')));
    }
  }

  Widget _softCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(10)}) {
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

  Widget _roundBtn(IconData icon, {VoidCallback? onPressed, bool active = false, double size = 56}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF7B4DBB).withOpacity(0.95) : Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
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
    return _roundBtn(icon, active: isActive, size: size, onPressed: () => _nudge(dir));
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

  Widget _zoomColumn({required IconData icon, required String action, double size = 50}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _roundBtn(icon, onPressed: _zoomBusy ? null : () => _zoom(action), size: size),
      ],
    );
  }
}
