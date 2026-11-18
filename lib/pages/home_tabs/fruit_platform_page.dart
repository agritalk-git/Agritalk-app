import 'package:flutter/material.dart';

import 'package:chcg_iot_app/pages/home_tabs/fruit_observation_page(heavy).dart'
    as heavy_observation;
import 'package:chcg_iot_app/pages/home_tabs/fruit_observation_page(light).dart'
    as light_observation;
import 'package:chcg_iot_app/pages/home_tabs/fruit_disease_page.dart';

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
                              builder: (_) {
                                const heavyFruits = {'白柚', '洋香瓜', '芒果'};
                                if (heavyFruits.contains(fruitName)) {
                                  return heavy_observation.FruitObservationPage(
                                    fruitName: fruitName,
                                    groupUUID: groupUUID!,
                                  );
                                }
                                return light_observation.FruitObservationPage(
                                  fruitName: fruitName,
                                  groupUUID: groupUUID!,
                                );
                              },
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
                      onTap: () {
                        final currentGroupUUID = groupUUID;
                        if (fruitName == '白柚' && currentGroupUUID != null) {
                          _openDiseasePrediction(
                            context,
                            groupUUID: currentGroupUUID,
                            cropName: '白柚',
                            apiFruitName: '白柚',
                            diseaseNames: ['潰瘍病', '柑橘木虱'],
                            groupLabel: '彰化縣二水鄉白柚',
                          );
                        } else if (fruitName == '小果番茄' &&
                            currentGroupUUID != null) {
                          _openDiseasePrediction(
                            context,
                            groupUUID: currentGroupUUID,
                            cropName: '小番茄',
                            apiFruitName: '番茄',
                            diseaseNames: ['銀葉粉虱', '白粉病', '灰黴病'],
                            apiFruitNameByDisease: {'銀葉粉虱': '小番茄'},
                            groupLabel: '彰化縣秀水鄉小番茄',
                          );
                        } else if (fruitName == '洋香瓜' &&
                            currentGroupUUID != null) {
                          _openDiseasePrediction(
                            context,
                            groupUUID: currentGroupUUID,
                            cropName: '洋香瓜',
                            apiFruitName: '哈密瓜',
                            diseaseNames: [
                              '瓜實蠅',
                              '白粉病',
                              '銀葉粉虱',
                              '炭疽病',
                              '露菌病',
                              '灰黴病',
                            ],
                            groupLabel: '彰化縣永靖鄉洋香瓜',
                          );
                        } else if (fruitName == '芒果' &&
                            currentGroupUUID != null) {
                          _openDiseasePrediction(
                            context,
                            groupUUID: currentGroupUUID,
                            cropName: '芒果',
                            apiFruitName: '芒果',
                            diseaseNames: ['東方果實蠅', '炭疽病'],
                            groupLabel: '彰化縣埔心鄉芒果',
                          );
                        } else if (fruitName == '小黃瓜' &&
                            currentGroupUUID != null) {
                          _openDiseasePrediction(
                            context,
                            groupUUID: currentGroupUUID,
                            cropName: '小黃瓜',
                            apiFruitName: '小黃瓜',
                            diseaseNames: ['露菌病'],
                            groupLabel: '彰化縣埤頭鄉小黃瓜',
                          );
                        } else if (fruitName == '紅龍果' &&
                            currentGroupUUID != null) {
                          _openDiseasePrediction(
                            context,
                            groupUUID: currentGroupUUID,
                            cropName: '紅龍果',
                            apiFruitName: '火龍果',
                            diseaseNames: ['莖潰瘍病'],
                            groupLabel: '彰化縣二林鎮紅龍果',
                          );
                        } else if (fruitName == '青蔥') {
                          _openDiseasePrediction(
                            context,
                            groupUUID: currentGroupUUID ?? '',
                            cropName: '青蔥',
                            apiFruitName: '青蔥',
                            diseaseNames: ['蔥薊馬', '紫斑病'],
                            apiFruitNameByDisease: {'蔥薊馬': '蔥'},
                            groupLabel: '彰化縣埔鹽鄉青蔥',
                          );
                        } else if (fruitName == '豌豆' &&
                            currentGroupUUID != null) {
                          _openDiseasePrediction(
                            context,
                            groupUUID: currentGroupUUID,
                            cropName: '豌豆',
                            apiFruitName: '豌豆',
                            diseaseNames: ['斜紋夜蛾', '白粉病'],
                            groupLabel: '彰化縣溪湖鎮豌豆',
                          );
                        } else if (fruitName == '花卉') {
                          _openDiseasePrediction(
                            context,
                            groupUUID: currentGroupUUID ?? '',
                            cropName: '菊花',
                            apiFruitName: '菊花',
                            diseaseNames: ['花薊馬', '灰黴病'],
                            groupLabel: '彰化縣田尾鄉菊花',
                          );
                        } else if (fruitName == '稻米') {
                          _openDiseasePrediction(
                            context,
                            groupUUID: currentGroupUUID ?? '',
                            cropName: '稻米',
                            apiFruitName: '水稻',
                            diseaseNames: ['褐飛蝨', '稻熱病'],
                            groupLabel: '彰化縣竹塘鄉稻米',
                          );
                        } else {
                          _openPlaceholder(context, title: '病蟲害預測');
                        }
                      },
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

  void _openDiseasePrediction(
    BuildContext context, {
    required String groupUUID,
    required String cropName,
    required String apiFruitName,
    Map<String, String> apiFruitNameByDisease = const {},
    required List<String> diseaseNames,
    required String groupLabel,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => FruitDiseasePage(
              groupUUID: groupUUID,
              cropName: cropName,
              apiFruitName: apiFruitName,
              apiFruitNameByDisease: apiFruitNameByDisease,
              diseaseNames: diseaseNames,
              groupLabel: groupLabel,
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
