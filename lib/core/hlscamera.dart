import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 單一入口：自動判斷是 RTSP 還是 MJPEG
class CameraViewer extends StatelessWidget {
    final String url;
    final BorderRadius? borderRadius;
    final BoxFit fit;

    const CameraViewer({
        super.key,
        required this.url,
        this.borderRadius,
        this.fit = BoxFit.cover,
    });

    @override
    Widget build(BuildContext context) {
        final uri = Uri.parse(url);
        final isRtsp = uri.scheme.toLowerCase() == 'rtsp';
        if (isRtsp) {
            return RtspCameraPlayer(url: url, borderRadius: borderRadius, fit: fit);
        } else {
            return MjpegCameraViewer(url: url, borderRadius: borderRadius, fit: fit);
        }
    }
}

/// ========== MJPEG 播放器（你原本的邏輯，整理與修正） ==========
class MjpegCameraViewer extends StatefulWidget {
    final String url;
    final BorderRadius? borderRadius;
    final BoxFit fit;

    const MjpegCameraViewer({
        super.key,
        required this.url,
        this.borderRadius,
        this.fit = BoxFit.cover,
    });

    @override
    State<MjpegCameraViewer> createState() => _MjpegCameraViewerState();
}

class _MjpegCameraViewerState extends State<MjpegCameraViewer> {
    late http.Client _client;
    final ValueNotifier<Uint8List?> _frameNotifier = ValueNotifier(null);
    bool _isRunning = true;

    @override
    void initState() {
        super.initState();
        _client = http.Client();
        _startStream();
    }

    Future<void> _startStream() async {
        while (_isRunning) {
            try {
                final uri = Uri.parse(widget.url);
                String username = '';
                String password = '';
                String baseUrl = widget.url;

                // 解析帳密（http://user:pass@host:port/path）
                if (uri.userInfo.isNotEmpty) {
                    final parts = uri.userInfo.split(':');
                    if (parts.length == 2) {
                        username = parts[0];
                        password = parts[1];
                    }
                    // 若原本 URL 內含帳密，重建無帳密的 baseUrl 以避免 400
                    baseUrl = '${uri.scheme}://${uri.host}'
                            '${uri.hasPort ? ':${uri.port}' : ''}'
                            '${uri.path}'
                            '${uri.hasQuery ? '?${uri.query}' : ''}';
                }

                final request = http.Request('GET', Uri.parse(baseUrl));
                if (username.isNotEmpty && password.isNotEmpty) {
                    final auth = base64Encode(utf8.encode('$username:$password'));
                    request.headers['Authorization'] = 'Basic $auth';
                }

                final response = await _client.send(request);

                if (response.statusCode == 200) {
                    final stream = response.stream;
                    final List<int> buffer = [];

                    await for (var chunk in stream) {
                        if (!_isRunning) break;
                        buffer.addAll(chunk);

                        // 限制 buffer 最大長度 (2MB)
                        if (buffer.length > 2 * 1024 * 1024) {
                            buffer.removeRange(0, buffer.length - 1024 * 1024);
                        }

                        final start = _indexOf(buffer, const [0xFF, 0xD8]); // JPEG SOI
                        final end = _indexOf(buffer, const [0xFF, 0xD9], start); // JPEG EOI

                        if (start != -1 && end != -1) {
                            final imageBytes = buffer.sublist(start, end + 2);
                            _frameNotifier.value = Uint8List.fromList(imageBytes);

                            // 移除已處理部分
                            buffer.removeRange(0, end + 2);
                        }
                    }
                } else {
                    debugPrint('MJPEG HTTP Error: ${response.statusCode}');
                }
            } catch (e) {
                debugPrint('MJPEG stream error: $e');
            }

            // 重連間隔
            if (_isRunning) {
                await Future.delayed(const Duration(seconds: 3));
            }
        }
    }

    int _indexOf(List<int> data, List<int> pattern, [int start = 0]) {
        if (start < 0) return -1;
        for (var i = start; i <= data.length - pattern.length; i++) {
            var match = true;
            for (var j = 0; j < pattern.length; j++) {
                if (data[i + j] != pattern[j]) {
                    match = false;
                    break;
                }
            }
            if (match) return i;
        }
        return -1;
    }

    @override
    void dispose() {
        _isRunning = false;
        _client.close();
        _frameNotifier.dispose();
        super.dispose();
    }

    @override
    Widget build(BuildContext context) {
        final radius = widget.borderRadius ?? BorderRadius.circular(8);
        return ValueListenableBuilder<Uint8List?>(
            valueListenable: _frameNotifier,
            builder: (context, frame, _) {
                if (frame != null) {
                    return ClipRRect(
                        borderRadius: radius,
                        child: Image.memory(
                            frame,
                            gaplessPlayback: true,
                            fit: widget.fit,
                            width: double.infinity,
                            height: double.infinity,
                        ),
                    );
                } else {
                    return const Center(child: CircularProgressIndicator());
                }
            },
        );
    }
}

/// ========== RTSP 播放器（改用 media_kit，相容 iOS / Android） ==========
class RtspCameraPlayer extends StatefulWidget {
    final String url;
    final BorderRadius? borderRadius;
    final BoxFit fit;

    const RtspCameraPlayer({
        super.key,
        required this.url,
        this.borderRadius,
        this.fit = BoxFit.cover,
    });

    @override
    State<RtspCameraPlayer> createState() => _RtspCameraPlayerState();
}

class _RtspCameraPlayerState extends State<RtspCameraPlayer> {
    late final Player _player;
    late final VideoController _videoController;

    StreamSubscription<int?>? _wSub;
    StreamSubscription<int?>? _hSub;

    int? _w;
    int? _h;
    bool _hasFirstFrame = false;

    @override
    @override
  void initState() {
    super.initState();

    final uri = Uri.parse(widget.url);

    // ⭐ 強制 RTSP 使用 554 port
    final fixedUri = Uri(
        scheme: uri.scheme,
        userInfo: uri.userInfo, // 保留帳密
        host: uri.host,
        port: uri.port,              // ⭐ 強制 554
        path: uri.path,
        query: uri.query,
    );

    final fixedUrl = fixedUri.toString();
    print('[RTSP FIX PORT] $fixedUrl');

    _player = Player(
        configuration: const PlayerConfiguration(
            bufferSize: 4 * 1024 * 1024,
        ),
    );

    _videoController = VideoController(_player);

    // ⭐ 用修正後的 URL
    _player.open(Media(fixedUrl));

    void checkFirstFrame() {
        final w = _w ?? 0;
        final h = _h ?? 0;
        final ok = w > 0 && h > 0;
        if (!_hasFirstFrame && ok && mounted) {
            setState(() => _hasFirstFrame = true);
        }
    }

    _wSub = _player.stream.width.listen((v) {
        _w = v;
        checkFirstFrame();
    });

    _hSub = _player.stream.height.listen((v) {
        _h = v;
        checkFirstFrame();
    });
}

    @override
    void dispose() {
        _wSub?.cancel();
        _hSub?.cancel();
        _player.dispose();
        super.dispose();
    }

    @override
    Widget build(BuildContext context) {
        final radius = widget.borderRadius ?? BorderRadius.circular(8);

        return ClipRRect(
            borderRadius: radius,
            child: Stack(
                fit: StackFit.expand,
                children: [
                    Video(
                        controller: _videoController,
                        fit: widget.fit,
                        controls: null,
                        fill: const Color(0xFF000000),
                    ),
                    if (!_hasFirstFrame)
                        const Center(child: CircularProgressIndicator()),
                ],
            ),
        );
    }
}