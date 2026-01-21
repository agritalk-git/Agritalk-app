import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart'; // <-- 要引入！
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
OverlayEntry? _topBannerEntry;

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔴 背景收到通知: ${message.messageId}');
}

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FirebaseMessaging.instance.requestPermission();

  String? token = await FirebaseMessaging.instance.getToken();
  print('✅ FCM Token: $token');

  final prefs = await SharedPreferences.getInstance();
  if (token != null && token.isNotEmpty) {
    await prefs.setString('fcm_token', token);
  }

  await FirebaseMessaging.instance.subscribeToTopic("all_news");

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', newToken);
    print('🔄 FCM Token refreshed: $newToken');
  });

  runApp(
    ResponsiveSizer(
      builder: (context, orientation, screenType) {
        return MyApp();
      },
    ),
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final title = message.notification?.title ?? '公告通知';
    final body = message.notification?.body ?? '';

    showTopInAppBanner(title: title, body: body);
  });
}

class BannerHost extends StatefulWidget {
  final Widget child;
  const BannerHost({super.key, required this.child});

  static _BannerHostState? of(BuildContext context) {
    return context.findAncestorStateOfType<_BannerHostState>();
  }

  @override
  State<BannerHost> createState() => _BannerHostState();
}

class _BannerHostState extends State<BannerHost> with TickerProviderStateMixin {
  OverlayEntry? _entry;
  AnimationController? _controller;

  void show({
    required String title,
    required String body,
    Duration duration = const Duration(seconds: 4),
  }) {
    // 移除舊的（安全）
    if (_entry?.mounted ?? false) _entry!.remove();
    _entry = null;

    _controller?.dispose();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );

    final fade = CurvedAnimation(parent: _controller!, curve: Curves.easeOut);
    final slide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller!, curve: Curves.easeOutCubic),
    );

    _entry = OverlayEntry(
      builder: (context) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: FadeTransition(
                opacity: fade,
                child: SlideTransition(
                  position: slide,
                  child: Material(
                    color: Colors.transparent,
                    child: GestureDetector(
                      onTap: hide,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 12,
                              offset: Offset(0, 6),
                              color: Colors.black26,
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.notifications_active, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    body,
                                    style: const TextStyle(fontSize: 14),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.close, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    // 插入 overlay（用 BannerHost 的 context 一定有 overlay）
    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState == null) {
      // ✅ Navigator/Overlay 還沒準備好，延後一幀再插入
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        show(title: title, body: body, duration: duration);
      });
      return;
    }

    overlayState.insert(_entry!);

    // 進場動畫
    _controller!.forward();

    // 自動消失（先退場動畫再 remove）
    Future.delayed(duration, () async {
      if (!mounted) return;
      await hide();
    });
  }

  Future<void> hide() async {
    if (_controller == null) return;
    if (_entry == null) return;

    // 退場動畫
    try {
      await _controller!.reverse();
    } catch (_) {}

    if (_entry?.mounted ?? false) _entry!.remove();
    _entry = null;

    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BannerHost(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'AgriTalk IoT',
        theme: ThemeData(
          primaryColor: const Color(0xFF7B4DBB),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7B4DBB)),
          fontFamily: 'SourceHanSansTW',
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => LoginPage(),
          '/home': (context) => const HomePage(),
        },
      ),
    );
  }
}

void showTopInAppBanner({
  required String title,
  required String body,
  Duration duration = const Duration(seconds: 4),
}) {
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;

  final host = BannerHost.of(ctx);
  if (host == null) return;

  host.show(title: title, body: body, duration: duration);
}
