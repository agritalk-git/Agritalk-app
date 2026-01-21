import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import 'package:chcg_iot_app/register_page.dart'; // 註冊畫面

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final ApiService apiService = ApiService();

  bool _rememberMe = false;
  bool _isLoggingIn = false;

  static const Color _primaryColor = Color(0xFF7B4DBB);

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('saved_username') ?? '';
    final savedPassword = prefs.getString('saved_password') ?? '';

    if (savedUsername.isNotEmpty && savedPassword.isNotEmpty) {
      setState(() {
        usernameController.text = savedUsername;
        passwordController.text = savedPassword;
        _rememberMe = true;
      });
    }
  }

  Future<void> _login(BuildContext context, {bool isGuest = false}) async {
    if (!isGuest) {
      if (usernameController.text.trim().isEmpty ||
          passwordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請輸入帳號與密碼')),
        );
        return;
      }
    }

    setState(() => _isLoggingIn = true);

    final username = isGuest ? 'guest' : usernameController.text.trim();
    final password = isGuest ? 'guest' : passwordController.text;
    // String? fcmToken = "";

    final prefs = await SharedPreferences.getInstance();
    final fcmToken = prefs.getString('fcm_token'); // 可能為 null

    final result = await apiService.login(username, password, fcmToken);


    if (!mounted) return;

    setState(() => _isLoggingIn = false);

    if (result != null && result['token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', result['token']);

      if (!isGuest) {
        if (_rememberMe) {
          await prefs.setString('saved_username', username);
          await prefs.setString('saved_password', password);
        } else {
          await prefs.remove('saved_username');
          await prefs.remove('saved_password');
        }
      }

      Navigator.pushReplacementNamed(context, '/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isGuest ? '訪客登入失敗' : '登入失敗，請檢查帳號密碼'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 讓內容延伸到狀態列下方
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7B4DBB), Color(0xFF4C2E91)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Image.asset(
                      'assets/logo_icon.png',
                      width: 140,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '彰化智慧雲',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '請先登入以使用完整功能',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 白色卡片
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              '帳號登入',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 帳號
                            TextField(
                              controller: usernameController,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: '帳號',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF7F7F9),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 密碼
                            TextField(
                              controller: passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: '密碼',
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF7F7F9),
                                isDense: true,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // 記住帳密 + 忘記密碼
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _rememberMe = value ?? false;
                                    });
                                  },
                                  visualDensity: VisualDensity.compact,
                                ),
                                const Text(
                                  '記住帳號密碼',
                                  style: TextStyle(fontSize: 13),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    // 之後可導到忘記密碼頁
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    '忘記密碼？',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // 登入按鈕
                            SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                onPressed:
                                    _isLoggingIn ? null : () => _login(context),
                                child: _isLoggingIn
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Text(
                                        '登入',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // 訪客瀏覽
                            SizedBox(
                              height: 44,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _primaryColor,
                                  side: BorderSide(
                                    color: _primaryColor.withOpacity(0.7),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                onPressed: _isLoggingIn
                                    ? null
                                    : () async {
                                        final prefs =
                                            await SharedPreferences
                                                .getInstance();
                                        await prefs.setString(
                                            'token', 'GUEST_MODE');
                                        if (!mounted) return;
                                        Navigator.pushReplacementNamed(
                                            context, '/home');
                                      },
                                child: const Text(
                                  '訪客瀏覽',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // 註冊
                            Center(
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RegisterPage(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.person_add_alt_1,
                                  size: 18,
                                  color: _primaryColor,
                                ),
                                label: const Text(
                                  '註冊新帳號',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      '建議使用者於公共裝置上避免勾選「記住帳號密碼」。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
