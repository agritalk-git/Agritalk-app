import 'package:flutter/material.dart';
import 'package:chcg_iot_app/pages/home_tabs/grape_page/GrapeObservationPage.dart';
import 'package:chcg_iot_app/pages/home_tabs/grape_page/grape_disease.dart';

class GrapePage extends StatelessWidget {
  const GrapePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '葡萄雲平台',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF7B4DBB),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
        children: [
          // ✅ 顯示圖片
          SizedBox(
            width: double.infinity,
            child: Image.asset(
              'assets/homepage/grape.jpg',
              fit: BoxFit.cover,
              height: 180,
            ),
          ),

          const SizedBox(height: 16),

          // ✅ 兩個卡片
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // 環境數據
                Expanded(
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GrapeObservationPage(),
                          ),
                        );
                      },

                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.thermostat,
                              size: 48,
                              color: Colors.indigo,
                            ),
                            SizedBox(height: 12),
                            Text(
                              '環境數據',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // 病蟲害預測
                Expanded(
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GrapeDiseasePage(), // ✅ 前往 guava_disease.dart
      ),
    );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.bug_report,
                              size: 48,
                              color: Colors.deepOrange,
                            ),
                            SizedBox(height: 12),
                            Text(
                              '病蟲害預測',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
              children: const [
                Text(
                  '葡萄雲平台說明',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7B4DBB),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '本平台致力於提升彰化葡萄產區的智慧化管理能力，透過感測設備、即時數據與預測技術，提供農民便捷的數位工具與決策依據。',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '「環境數據」功能整合溫濕度、日照、雨量等資訊，協助農民掌握田區氣候變化，並可查閱歷史數據進行趨勢分析。',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '「病蟲害預測」則依據氣候條件與歷史資料模型，預測可能發生的病蟲害風險，提前介入防治，有效減少損失。',
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
      )
    );
  }
}
