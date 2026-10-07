import 'package:flutter/material.dart';

import 'package:chcg_iot_app/pages/home_tabs/fruit_observation_page.dart';

class FruitPlatformPage extends StatelessWidget {
  final String fruitName;
  final String? groupUUID;
  final bool observationsEnabled;
  final String? introduction;
  final String? image;

  const FruitPlatformPage({
    super.key,
    required this.fruitName,
    this.groupUUID,
    this.observationsEnabled = false,
    this.introduction,
    this.image,
  });

  static const _primaryColor = Color(0xFF7B4DBB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$fruitName雲平台'),
        centerTitle: true,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 180,
              child:
                  image == null
                      ? const ColoredBox(
                        color: Color(0xFFEDE8F5),
                        child: Center(
                          child: Icon(
                            Icons.eco_outlined,
                            size: 72,
                            color: _primaryColor,
                          ),
                        ),
                      )
                      : Image.asset(image!, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _FeatureCard(
                      icon: Icons.thermostat,
                      iconColor: Colors.indigo,
                      title: '環境數據',
                      onTap: () {
                        if (observationsEnabled && groupUUID != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FruitObservationPage(
                                fruitName: fruitName,
                                groupUUID: groupUUID!,
                              ),
                            ),
                          );
                        } else {
                          _openPlaceholder(context, title: '環境數據');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _FeatureCard(
                      icon: Icons.bug_report,
                      iconColor: Colors.deepOrange,
                      title: '病蟲害預測',
                      onTap: () => _openPlaceholder(context, title: '病蟲害預測'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$fruitName雲平台說明',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    introduction ??
                        '本平台致力於提升彰化$fruitName產區的智慧化管理能力，'
                            '透過感測設備、即時數據與預測技術，提供農民便捷的數位工具與決策依據。',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '「環境數據」功能將整合溫濕度、日照、雨量等資訊，'
                    '協助農民掌握田區氣候變化，並可查閱歷史數據進行趨勢分析。',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '「病蟲害預測」將依據氣候條件與歷史資料模型，'
                    '呈現可能發生的病蟲害風險資訊。',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPlaceholder(BuildContext context, {required String title}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => _FruitFeaturePlaceholderPage(
              fruitName: fruitName,
              title: title,
            ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: iconColor),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FruitFeaturePlaceholderPage extends StatelessWidget {
  final String fruitName;
  final String title;

  const _FruitFeaturePlaceholderPage({
    required this.fruitName,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final icon = title == '環境數據' ? Icons.thermostat : Icons.bug_report;

    return Scaffold(
      appBar: AppBar(
        title: Text('$fruitName$title'),
        centerTitle: true,
        backgroundColor: FruitPlatformPage._primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: FruitPlatformPage._primaryColor),
            const SizedBox(height: 16),
            Text('$title資料尚未串接', style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
