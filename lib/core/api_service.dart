import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class ApiService {
  final baseUrl = dotenv.env['API_BASE_URL'];

  Future<Map<String, dynamic>?> login(
    String username,
    String password,
    String? fcm_token,
  ) async {
    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/account/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'fcm_token': fcm_token,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      print('登入失敗: ${response.statusCode} ${response.body}');
      return null;
    }
  }

  Future<Map<String, dynamic>?> register({
    required String username,
    required String email,
    String firstName = '',
    String lastName = '',
    String jobTitle = '',
    String phone = '',
    String? fcmToken, // 可為 null
    String? password, // 若後端開放自訂密碼可帶，否則留空
    String? confirmPassword, // 同上
  }) async {
    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/account/register');

    // 後端序列化器鍵名（snake_case）要對上
    final payload = <String, dynamic>{
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'job_title': jobTitle,
      'phone': phone,
      // 'unit': unit,
      if (fcmToken != null) 'fcm_token': fcmToken,
      if (password != null) 'password': password,
      if (confirmPassword != null) 'confirm_password': confirmPassword,
    };

    final res = await http.post(
      url,
      headers: const {
        'Content-Type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode(payload),
    );

    // 成功：201（或 200）
    if (res.statusCode == 201 || res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }

    // 失敗：盡量回傳後端錯誤訊息格式（可能是 {"errors": {...}} 或 {"error": "..."}）
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map<String, dynamic>) {
        return {
          'error': body['error'] ?? body['errors'] ?? '註冊失敗',
          'status': res.statusCode,
        };
      }
    } catch (_) {
      // ignore json parse error
    }
    return {'error': '註冊失敗：${res.statusCode}', 'status': res.statusCode};
  }

  Future<Map<String, dynamic>> deactivateAccount(String token) async {
    // TODO: 換成你的實際 API 路徑與方法
    // 範例1：POST /account/deactivate
    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/account/deactivate');
    final res = await http.post(
      url,
      headers: {
        'Authorization': '$token', // 或 'Bearer $token'
        'Content-Type': 'application/json',
      },
      body: jsonEncode({}), // 若需要帶參數可放進來
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body.isNotEmpty ? utf8.decode(res.bodyBytes) : '{}');
    } else {
      final msg = res.body.isNotEmpty ? res.body : 'Deactivate failed';
      throw Exception(msg);
    }

    // 若你的後端是 DELETE /account，也可以改成：
    // final url = Uri.parse('$baseUrl/account');
    // final res = await http.delete(url, headers: {...});
  }

  Future<Map<String, dynamic>?> account(String token) async {
    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/account');
    final response = await http.get(
      url,
      headers: {'accept': 'application/json', 'Authorization': token},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data["user"];
    } else {
      print('查看帳號失敗: ${response.statusCode} ${response.body}');
      return null;
    }
  }

  Future<Map<String, dynamic>> updateTelegramSetting({
    required String chatId,
    required bool enabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty || token == 'GUEST_MODE') {
      throw Exception('請先登入後再設定 Telegram 推播');
    }

    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/account/telegram');

    final res = await http.post(
      url,
      headers: {
        'Authorization': token, // token 內已經有 Bearer 前綴
        'Content-Type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode({
        'chat_id': chatId,
        'enabled': enabled,
      }),
    );

    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception(
        '更新 Telegram 設定失敗：${utf8.decode(res.bodyBytes)}',
      );
    }
  }

  Future<Map<String, dynamic>> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final url = Uri.parse(
      '$baseUrl/odata/api/v1-Odata/account/change-password',
    );
    final res = await http.post(
      url,
      headers: {'Authorization': '$token', 'Content-Type': 'application/json'},
      body: json.encode({
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    );

    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } else {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final errorMessage = body['error'] ?? '變更密碼失敗';
      throw Exception(errorMessage);
    }
  }
  
  Future<List<dynamic>?> fetchdeviceFeatureName(String token) async {
    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/deviceFeatureName');
    final response = await http.get(
      url,
      headers: {'accept': 'application/json', 'Authorization': token},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['value'];
    } else {
      print('取得 Systems 失敗: ${response.statusCode}');
      return null;
    }
  }

  Future<List<dynamic>?> fetchSystems(String token) async {
    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/Systems');
    final response = await http.get(
      url,
      headers: {'accept': 'application/json', 'Authorization': token},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['value'];
    } else {
      print('取得 Systems 失敗: ${response.statusCode}');
      return null;
    }
  }

  Future<List<dynamic>?> fetchTargets(String token) async {
    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/Targets');
    final response = await http.get(
      url,
      headers: {'accept': 'application/json', 'Authorization': token},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['value'];
    } else {
      print('取得 Targets 失敗: ${response.statusCode}');
      return null;
    }
  }

  Future<List<dynamic>?> fetchDevices(String token, String targetUUID) async {
    final url = Uri.parse(
      '${baseUrl}/odata/api/v1-Odata/Devices?targetUUID=${targetUUID}',
    );
    final response = await http.get(
      url,
      headers: {'accept': 'application/json', 'Authorization': token},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['value'];
    } else {
      print('取得 Devices 失敗: ${response.statusCode}');
      return null;
    }
  }

  Future<List<dynamic>?> fetchObservationsLatest(String token) async {
    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/ObservationsLatest');
    final response = await http.get(
      url,
      headers: {'accept': 'application/json', 'Authorization': token},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['value'];
    } else {
      print('取得 ObservationsLatest 失敗: ${response.statusCode}');
      return null;
    }
  }

  Future<List<dynamic>?> fetchObservationRawData({
    required String deviceUUID,
    required String featureEnglishName,
    required String serialId,
    required DateTime startTime,
    required DateTime endTime,
    required String aggregate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return null;

    final url = Uri.parse(
      '$baseUrl/odata/api/v1-Odata/Observations/RawData'
      '?deviceUUID=$deviceUUID'
      '&featureEnglishName=$featureEnglishName'
      '&serialId=$serialId'
      '&start_time=${DateFormat('yyyy-MM-dd HH:mm:ss').format(startTime)}'
      '&end_time=${DateFormat('yyyy-MM-dd HH:mm:ss').format(endTime)}'
      '&aggregate=$aggregate',
    );

    final response = await http.get(
      url,
      headers: {'accept': 'application/json', 'Authorization': token},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['value'] ?? [];
    } else {
      print('fetchObservationRawData失敗 ${response.statusCode}');
      return null;
    }
  }

  Future<List<dynamic>?> fetchMineRawData({
    required String featureEnglishName,
    required DateTime startTime,
    required DateTime endTime,
    required String aggregate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return null;

    final url = Uri.parse(
      '$baseUrl/odata/api/v1-Odata/Observations/account/RawData'
      '?featureEnglishName=$featureEnglishName'
      '&start_time=${DateFormat('yyyy-MM-dd HH:mm:ss').format(startTime)}'
      '&end_time=${DateFormat('yyyy-MM-dd HH:mm:ss').format(endTime)}'
      '&aggregate=$aggregate'
      '&mine=mine',
    );

    final response = await http.get(
      url,
      headers: {'accept': 'application/json', 'Authorization': token},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['value'] ?? [];
    } else {
      print('fetchMineObservationRawData失敗 ${response.statusCode}');
      return null;
    }
  }

  Future<bool> switchSetting({
    required String deviceUUID,
    required String featureEnglishName,
    required String serialId,
    required bool newValue,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('No token found');
    }

    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/Settings');

    final body = {
      'deviceUUID': deviceUUID,
      'featureEnglishName': featureEnglishName,
      'value': newValue ? 'ON' : 'OFF',
      'serialId': serialId,
    };

    print(url);
    print(body);

    final response = await http.post(
      url,
      headers: {
        'accept': 'application/json',
        'Authorization': token,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return true;
    } else {
      print('Switch Setting 失敗: ${response.statusCode} ${response.body}');
      return false;
    }
  }

  /// 查詢所有 GroupDevices（包含底下 Devices 資訊）
  Future<List<dynamic>?> fetchGroupDevices(String token) async {
    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/GroupDevices');
    final response = await http.get(
      url,
      headers: {'accept': 'application/json', 'Authorization': token},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['value'];
    } else {
      print('取得 GroupDevices 失敗: ${response.statusCode}');
      return null;
    }
  }

  /// 查詢 GroupDevice 中所有裝置的平均觀測資料（raw/hours/days/months）
  Future<List<dynamic>?> fetchGroupObservation({
    required String groupUUID,
    required String featureEnglishName,
    required DateTime startTime,
    required DateTime endTime,
    String aggregate = 'raw',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return null;

    final url = Uri.parse(
      '$baseUrl/odata/api/v1-Odata/GroupDevices(\'$groupUUID\')/Observations'
      '?featureEnglishName=$featureEnglishName'
      '&start_time=${DateFormat('yyyy-MM-dd HH:mm:ss').format(startTime)}'
      '&end_time=${DateFormat('yyyy-MM-dd HH:mm:ss').format(endTime)}'
      '&aggregate=$aggregate',
    );

    final response = await http.get(
      url,
      headers: {'accept': 'application/json', 'Authorization': token},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['value'];
    } else {
      print('取得 GroupDevice 観測資料失敗: ${response.statusCode}');
      return null;
    }
  }

  /// 查詢時間排程
  Future<List<dynamic>?> fetchschedule(
    String token,
    String deviceUUID,
    String serial_id,
  ) async {
    final url = Uri.parse(
      '$baseUrl/odata/api/v1-Odata/schedule/$deviceUUID/$serial_id/',
    );
    final response = await http.get(
      url,
      headers: {'accept': 'application/json', 'Authorization': token},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['schedules'];
    } else {
      print('取得 schedule 失敗: ${response.statusCode}');
      return null;
    }
  }

  Future<Map<String, dynamic>> scheduleAdd({
    required String token,
    required String deviceUUID,
    required String featureEnglishName,
    required int serialId,
    required String action,
    required String time,
    required List<String> weekdays,
  }) async {
    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/schedule/add/');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },

      body: jsonEncode({
        'action': action, // "ON" 或 "OFF"
        'deviceUUID': deviceUUID,
        'enabled': true,
        'featureEnglishName': featureEnglishName,
        'serial_id': serialId,
        'time': time, // "05:00"
        'weekdays': weekdays, // List<String> like ["monday", "tuesday"]
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('新增排程失敗：${response.body}');
    }
  }

  Future<Map<String, dynamic>> scheduleDel({
    required String token,
    required int id,
  }) async {
    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/schedule/delete/');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },

      body: jsonEncode({'id': id}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('刪除排程失敗：${response.body}');
    }
  }

  /// 查詢時間排程
  Future<List<dynamic>?> fetchCondition(
    String token,
    String deviceUUID,
    String serial_id,
  ) async {
    final url = Uri.parse(
      '$baseUrl/odata/api/v1-Odata/condition/$deviceUUID/$serial_id/',
    );
    final response = await http.get(
      url,
      headers: {'accept': 'application/json', 'Authorization': token},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['rules'];
    } else {
      print('取得 condition 失敗: ${response.statusCode}');
      return null;
    }
  }

  Future<Map<String, dynamic>> conditionAdd({
    required String token,
    required String deviceUUID,
    required int serialId,
    required String action,
    required List<Map<String, dynamic>> conditions,
    int? durationSeconds, // ✅ 新增可選秒數參數
  }) async {
    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/condition/add/');

    final body = {
      'deviceUUID': deviceUUID,
      'serial_id': serialId,
      'action': action,
      'enabled': true,
      'rule_id': null,
      'conditions': conditions,
      if (durationSeconds != null)
        'duration_seconds': durationSeconds, // ✅ 只有有設定才會帶
    };

    print(body);

    final response = await http.post(
      url,
      headers: {'Authorization': token, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('新增條件排程失敗：${response.body}');
    }
  }

  Future<Map<String, dynamic>> conditionDel({
    required String token,
    required int id,
  }) async {
    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/condition/delete/');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },

      body: jsonEncode({'id': id}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('刪除排程失敗：${response.body}');
    }
  }

  Future<Map<String, dynamic>?> fetchGroupScore({
    required String groupUUID,
    required String fruit,
    required String disease,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return null;

    final encodedFruit = Uri.encodeComponent(fruit);
    final encodedDisease = Uri.encodeComponent(disease);

    final url = Uri.parse(
      '$baseUrl/odata/api/v1-Odata/GroupDevices/score/'
      '?groupUUID=$groupUUID'
      '&fruit=$encodedFruit'
      '&disease=$encodedDisease',
    );

    final response = await http.get(
      url,
      headers: {'accept': 'application/json', 'Authorization': token},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['data']; // ✅ 只回傳 data 欄位
    } else {
      print('取得病蟲害預測失敗: ${response.statusCode}');
      return null;
    }
  }

  Future<List<dynamic>?> fetchGroupScoreHistory({
    required String groupUUID,
    required String fruit,
    required String disease,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return null;

    final encodedFruit = Uri.encodeComponent(fruit);
    final encodedDisease = Uri.encodeComponent(disease);

    final url = Uri.parse(
      '$baseUrl/odata/api/v1-Odata/GroupDevices/score_history/'
      '?groupUUID=$groupUUID'
      '&fruit=$encodedFruit'
      '&disease=$encodedDisease',
    );

    final response = await http.get(
      url,
      headers: {'accept': 'application/json', 'Authorization': token},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map && data.containsKey('data') && data['data'] is List) {
        return data['data'] as List;
      }
      return [];
    } else {
      print('取得病蟲害歷史預測失敗: ${response.statusCode}');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchNews() async {
    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/news');

    final response = await http.get(
      url,
      headers: {'accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data; // ✅ 直接回傳整個 Map
    } else {
      print('取得新聞資料失敗: ${response.statusCode}');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchAmis() async {
    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/amis');

    final response = await http.get(
      url,
      headers: {'accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data; // ✅ 直接回傳整個 Map
    } else {
      print('取得農產品價格失敗: ${response.statusCode}');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchAmisHistory(plant_type, plant_code, start_date, end_date) async {
    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/get_amis_history?plant_type=$plant_type&plant_code=$plant_code&start_date=$start_date&end_date=$end_date');

    final response = await http.get(
      url,
      headers: {'accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data; // ✅ 直接回傳整個 Map
    } else {
      print('取得農產品價格失敗: ${response.statusCode}');
      return null;
    }
  }

  

  Future<Map<String, dynamic>?> fetchChatgpt({
    required String groupUUID,
    required String fruit,
    required String disease,
    required String score,
  }) async {
    final url = Uri.parse(
      '$baseUrl/odata/api/v1-Odata/chatgpt?groupUUID=$groupUUID&fruit=$fruit&disease=$disease&score=$score',
    );

    final response = await http.get(
      url,
      headers: {'accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data; // ✅ 直接回傳整個 Map
    } else {
      print('取得新聞資料失敗: ${response.statusCode}');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchImageDetectHistory({
    required DateTime startTime,
    required DateTime endTime,
    required String cameraIp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return null;

    final url = Uri.parse(
      '$baseUrl/odata/api/v1-Odata/image_detect_history'
      '?start_time=${startTime.toIso8601String()}'
      '&end_time=${endTime.toIso8601String()}'
      '&camera_ip=$cameraIp',
    );

    final response = await http.get(
      url,
      headers: {'accept': 'application/json', 'Authorization': token},
    );

    if (response.statusCode == 200) {
      try {
        final body = response.body;
        print("原始回應：$body");
        return jsonDecode(utf8.decode(response.bodyBytes));
      } catch (e) {
        print('解析 JSON 失敗: $e');
        print('伺服器回應: ${response.body}');
        return null;
      }
    } else {
      print("取得 image_detect_history 失敗: ${response.statusCode}");
      print("伺服器回應: ${response.body}");
      return null;
    }
  }

  Future<Uint8List?> fetchImageDetectPath({
    required String path,
    required String tag,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return null;

    print({"path": path});

    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/image_detect_image');
    print(path);
    print(jsonEncode({"path": path, "tag": tag}));
    final response = await http.post(
      url,
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
        'Accept': 'image/*', // ✅ 接受圖片格式
      },
      body: jsonEncode({"path": path, "tag": tag}),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes; // ✅ 圖片 binary
    } else {
      print("取得圖片失敗 ${response.statusCode}");
      return null;
    }
  }

  Future<Map<String, dynamic>?> uploadImageDetectNow({
    required String uploaderName,
    required String cameraId,
    required List<Uint8List> images,
    required List<String> filenames,
    bool analysisPhoto = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return null;

    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/image_detect_image_now');

    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = token;
    request.headers['Accept'] = 'application/json';

    // ✅ 加入其他欄位
    request.fields['uploader_name'] = uploaderName;
    request.fields['camera_id'] = cameraId;
    request.fields['analysis_photo'] = analysisPhoto.toString();

    // ✅ 加入圖片
    for (int i = 0; i < images.length; i++) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          images[i],
          filename: filenames[i],
        ),
      );
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        print(
          'uploadImageDetectNow 錯誤: ${response.statusCode} ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('uploadImageDetectNow 發生例外: $e');
      return null;
    }
  }

  /// 取得循環排程（同一致動器下所有規則）
  Future<List<dynamic>?> fetchCyclic(
    String token,
    String deviceUUID,
    String serialId,
  ) async {
    final url = Uri.parse(
      '$baseUrl/odata/api/v1-Odata/cyclic/$deviceUUID/$serialId/',
    );

    final res = await http.get(
      url,
      headers: {'accept': 'application/json', 'Authorization': token},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return data['rules'] as List<dynamic>;
    } else {
      print('取得 cyclic 失敗: ${res.statusCode} ${res.body}');
      return null;
    }
  }

  /// 新增／更新循環排程
  ///
  /// 備註：
  /// - 若 [ruleId] 為 null -> 新增；有值 -> 更新該規則。
  /// - startTime / endTime 請用 "HH:mm" 或 "HH:mm:ss"
  Future<Map<String, dynamic>> cyclicAdd({
    required String token,
    required String deviceUUID,
    required String featureEnglishName,
    required int serialId,
    required int onMinutes,
    required int offMinutes,
    required String startTime,
    required String endTime,
    required List<String> weekdays,
    bool enabled = true,
    int? ruleId,
  }) async {
    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/cyclic/add/');

    final body = {
      'rule_id': ruleId, // null 代表新增
      'deviceUUID': deviceUUID,
      'feature_name': featureEnglishName,
      'serial_id': serialId,
      'on_minutes': onMinutes,
      'off_minutes': offMinutes,
      'start_time': startTime, // "08:00" / "08:00:00"
      'end_time': endTime, // "20:00" / "20:00:00"
      'weekdays': weekdays, // ["monday",...]
      'enabled': enabled,
    };

    final res = await http.post(
      url,
      headers: {
        'Authorization': token, // 與 conditionAdd 保持一致（不用 Bearer 前綴）
        'Content-Type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception('新增/更新循環排程失敗：${res.statusCode} ${res.body}');
    }
  }

  /// 刪除循環排程
  Future<Map<String, dynamic>> cyclicDel({
    required String token,
    required int id,
  }) async {
    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/cyclic/delete/');

    final res = await http.post(
      url,
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode({'id': id}),
    );

    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception('刪除循環排程失敗：${res.statusCode} ${res.body}');
    }
  }

  /// 控制攝影機
  Uri _withCredsInUrl(Uri u, {String? username, String? password}) {
    // 若原 URL 已帶 userInfo 就用原本；否則塞入提供的帳密
    final userInfo =
        (u.userInfo.isNotEmpty)
            ? u.userInfo
            : ((username?.isNotEmpty ?? false) &&
                (password?.isNotEmpty ?? false))
            ? '${username!}:${password!}'
            : '';

    return u.replace(userInfo: userInfo);
  }

  Map<String, String> _authHeader(Uri u, {String? username, String? password}) {
    final usr =
        (u.userInfo.isNotEmpty)
            ? u.userInfo.split(':').first
            : (username ?? '');
    final pwd =
        (u.userInfo.isNotEmpty && u.userInfo.contains(':'))
            ? u.userInfo.split(':').last
            : (password ?? '');

    if (usr.isNotEmpty && pwd.isNotEmpty) {
      final basic = base64Encode(utf8.encode('$usr:$pwd'));
      return {'Authorization': 'Basic $basic'};
    }
    return {};
  }

  /// 直接用「完整 URL」打（例如 .../camctrl.cgi?move=up）
  /// - 會自動把帳密補進網址（若提供 username/password），也會加 Authorization header
  Future<bool> cameraControlGetByUrl(
    String url, {
    String? username,
    String? password,
  }) async {
    Uri u = Uri.parse(url);
    u = _withCredsInUrl(u, username: username, password: password);

    final headers = {
      'accept': 'application/json, */*',
      ..._authHeader(u, username: username, password: password),
    };

    final res = await http.get(u, headers: headers);
    return res.statusCode == 200;
  }

  /// 建一個「控制 base」：例如 https://host[:port]/cgi-bin/camctrl/camctrl.cgi
  /// 然後傳指令（move=up/down/left/right/stop）
  Future<bool> cameraMove({
    required String controlBase,
    required String direction, // up/down/left/right/stop
    String? username,
    String? password,
  }) async {
    final url = '$controlBase?move=$direction&channel=0&stream=0';
    print('[cameraMove] URL: $url');

    // 第一次嘗試
    final success = await cameraControlGetByUrl(
      url,
      username: username,
      password: password,
    );

    // 如果失敗且 controlBase 包含 camctrl，就改成 eCamCtrl 再試一次
    if (!success && controlBase.contains('camctrl.cgi')) {
      final fallbackBase = controlBase.replaceFirst(
        'camctrl.cgi',
        'eCamCtrl.cgi',
      );
      final fallbackUrl = '$fallbackBase?move=$direction&channel=0&stream=0';
      print('[cameraMove] Retry URL: $fallbackUrl');

      return cameraControlGetByUrl(
        fallbackUrl,
        username: username,
        password: password,
      );
    }

    return success;
  }

  /// 變焦（zoom=tele / zoom=wide）
  Future<bool> cameraZoom({
    required String controlBase,
    required String action, // tele / wide
    String? username,
    String? password,
  }) async {
    final url = '$controlBase?zoom=$action&channel=0&stream=0';
    print('[cameraZoom] URL: $url');

    // 第一次嘗試
    final success = await cameraControlGetByUrl(
      url,
      username: username,
      password: password,
    );

    // 如果失敗且 controlBase 包含 camctrl，就改成 eCamCtrl 再試一次
    if (!success && controlBase.contains('camctrl.cgi')) {
      final fallbackBase = controlBase.replaceFirst(
        'camctrl.cgi',
        'eCamCtrl.cgi',
      );
      final fallbackUrl = '$fallbackBase?zoom=$action&channel=0&stream=0';
      print('[cameraZoom] Retry URL: $fallbackUrl');

      return cameraControlGetByUrl(
        fallbackUrl,
        username: username,
        password: password,
      );
    }

    return success;
  }

    /// 取得單一 Actuator 的警戒值設定（高於 / 低於）
  Future<Map<String, dynamic>?> fetchAlertThreshold({
    required String token,
    required String deviceUUID,
    required String featureEnglishName,
    required String serialId,
  }) async {
    final url = Uri.parse(
      '$baseUrl/odata/api/v1-Odata/AlertThreshold'
      '?deviceUUID=$deviceUUID'
      '&featureEnglishName=$featureEnglishName'
      '&serialId=$serialId',
    );

    final res = await http.get(
      url,
      headers: {
        'accept': 'application/json',
        'Authorization': token,
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final list = (data['value'] as List?) ?? [];
      if (list.isEmpty) return null;
      return list.first as Map<String, dynamic>;
    } else {
      print('取得 AlertThreshold 失敗: ${res.statusCode} ${res.body}');
      return null;
    }
  }

   /// 新增 / 更新警戒值設定（後端用 update_or_create）
  Future<Map<String, dynamic>> alertThresholdAdd({
    required String token,
    required String deviceUUID,
    required String featureEnglishName,
    required String serialId,
    double? highValue,
    double? lowValue,
    String? alias,
  }) async {
    final url = Uri.parse('$baseUrl/odata/api/v1-Odata/AlertThreshold');

    final body = <String, dynamic>{
      'deviceUUID': deviceUUID,
      'featureEnglishName': featureEnglishName,
      'serialId': serialId,
      if (highValue != null) 'highValue': highValue,
      if (lowValue != null) 'lowValue': lowValue,
      if (alias != null) 'alias': alias,
    };

    final res = await http.post(
      url,
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception('新增/更新警戒值失敗：${res.statusCode} ${res.body}');
    }
  }
   /// 刪除警戒值設定
  Future<Map<String, dynamic>> alertThresholdDel({
    required String token,
    required String deviceUUID,
    required String featureEnglishName,
    required String serialId,
  }) async {
    final url = Uri.parse(
      '$baseUrl/odata/api/v1-Odata/AlertThreshold'
      '?deviceUUID=$deviceUUID'
      '&featureEnglishName=$featureEnglishName'
      '&serialId=$serialId',
    );

    final res = await http.delete(
      url,
      headers: {
        'Authorization': token,
        'accept': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception('刪除警戒值失敗：${res.statusCode} ${res.body}');
    }
  }
   /// 取得警戒值觸發歷史紀錄
  Future<List<dynamic>?> fetchAlertHistory({
    required String token,
    required String deviceUUID,
    required String featureEnglishName,
    required String serialId,
    int limit = 50,
  }) async {
    final url = Uri.parse(
      '$baseUrl/odata/api/v1-Odata/AlertHistory'
      '?deviceUUID=$deviceUUID'
      '&featureEnglishName=$featureEnglishName'
      '&serialId=$serialId'
      '&limit=$limit',
    );

    final res = await http.get(
      url,
      headers: {
        'accept': 'application/json',
        'Authorization': token,
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return (data['value'] as List?) ?? [];
    } else {
      print('取得 AlertHistory 失敗：${res.statusCode} ${res.body}');
      return null;
    }
  }

}


class DiseaseApiService {
  /// .env 裡請加一個，例如：
  /// DISEASE_API_URL=http://192.168.0.10:5000
  final String? diseaseURL = dotenv.env['DISEASE_API_URL'];

  DiseaseApiService() {
    if (diseaseURL == null || diseaseURL!.isEmpty) {
      throw Exception(
        'DISEASE_API_URL 尚未設定，請在 .env 中設定，例如 DISEASE_API_URL=http://127.0.0.1:5000',
      );
    }
  }

  Uri _buildUri(String path, [Map<String, String>? params]) {
    return Uri.parse('$diseaseURL$path').replace(
      queryParameters: params,
    );
  }

  // ====================== 既有 API ======================

  /// 封裝 /api/farms
  /// 對應 Flask：
  /// GET /api/farms?farm=火龍果
  Future<Map<String, dynamic>?> fetchFarms({String farm = '火龍果'}) async {
    final uri = _buildUri('/api/farms', {'farm': farm});

    final res = await http.get(
      uri,
      headers: const {'accept': 'application/json'},
    );

    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } else {
      print('fetchFarms 失敗: ${res.statusCode} ${res.body}');
      return null;
    }
  }

  /// 封裝 /api/bug-farm-list
  /// 對應 Flask：
  /// GET /api/bug-farm-list?farm=E215901,D135901&flag=&bug=&userange=
  Future<Map<String, dynamic>?> fetchBugFarmList({
    required String farm, // 例如 "E215901,D135901"
    String flag = '',
    String bug = '',
    String userange = '',
  }) async {
    final uri = _buildUri('/api/bug-farm-list', {
      'farm': farm,
      'flag': flag,
      'bug': bug,
      'userange': userange,
    });

    final res = await http.get(
      uri,
      headers: const {'accept': 'application/json'},
    );

    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } else {
      print('fetchBugFarmList 失敗: ${res.statusCode} ${res.body}');
      return null;
    }
  }

  /// 封裝 /api/bug-farm-userange
  /// 對應 Flask：
  /// GET /api/bug-farm-userange?farm=D135901&bug=A0301&flag=
  Future<Map<String, dynamic>?> fetchBugFarmUserange({
    required String farm, // 例如 "D135901"
    required String bug, // 例如 "A0301"
    String flag = '',
  }) async {
    final uri = _buildUri('/api/bug-farm-userange', {
      'farm': farm,
      'bug': bug,
      'flag': flag,
    });

    final res = await http.get(
      uri,
      headers: const {'accept': 'application/json'},
    );

    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } else {
      print('fetchBugFarmUserange 失敗: ${res.statusCode} ${res.body}');
      return null;
    }
  }

  // ====================== azai 病蟲害查詢 API ======================

  /// 封裝 /api/azai/search
  /// 對應 Flask：
  /// POST /api/azai/search
  /// body: { "term": "火龍果", "ty": "y,y,y,y" }
  ///
  /// 回傳格式：
  /// { "data": [ { "id": ..., "CName": ..., "pic": "完整圖片 URL", ... }, ... ] }
  Future<Map<String, dynamic>?> searchAzaiBugs({
  required String term,
  String ty = 'y,y,y,y',
}) async {
  final uri = _buildUri('/api/azai/search');

  print('[DiseaseApiService] POST $uri');
  print('[DiseaseApiService] body=${{'term': term, 'ty': ty}}');

  try {
    final res = await http.post(
      uri,
      headers: const {
        'accept': 'application/json',
        'content-type': 'application/json',
        // ⭐ 要求伺服器不要用 gzip / br 壓縮
        'accept-encoding': 'identity',
      },
      body: jsonEncode({
        'term': term,
        'ty': ty,
      }),
    );

    print('[DiseaseApiService] status=${res.statusCode}');

    if (res.statusCode == 200) {
      final text = utf8.decode(res.bodyBytes);
      print('[DiseaseApiService] body length=${text.length}');
      return jsonDecode(text) as Map<String, dynamic>;
    } else {
      print('searchAzaiBugs 失敗: ${res.statusCode} ${res.body}');
      return null;
    }
  } on http.ClientException catch (e, s) {
    print('[DiseaseApiService] ClientException: $e');
    print('$s');
    rethrow;
  } catch (e, s) {
    print('[DiseaseApiService] 其他例外: $e');
    print('$s');
    rethrow;
  }
}


  /// 封裝 /api/azai/bug-pics
  /// 對應 Flask：
  /// POST /api/azai/bug-pics
  /// body: { "bug_id": 333 }
  ///
  /// 回傳格式：
  /// { "data": [ { "image_url": "完整圖片 URL", ... }, ... ] }
  Future<Map<String, dynamic>?> fetchAzaiBugPics({
    required String bugId,
  }) async {
    final uri = _buildUri('/api/azai/bug-pics');

    final res = await http.post(
      uri,
      headers: const {
        'accept': 'application/json',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'bug_id': bugId,
      }),
    );

    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } else {
      print('fetchAzaiBugPics 失敗: ${res.statusCode} ${res.body}');
      return null;
    }
  }

  /// 封裝 /api/azai/bug-detail
  /// 對應 Flask：
  /// POST /api/azai/bug-detail
  /// body: { "bug_id": 333 }
  ///
  /// 回傳格式：
  /// { "data": [ { "CName": ..., "SName": ..., "Harm": ..., ... } ] }
  Future<Map<String, dynamic>?> fetchAzaiBugDetail({
    required String bugId,
  }) async {
    final uri = _buildUri('/api/azai/bug-detail');

    final res = await http.post(
      uri,
      headers: const {
        'accept': 'application/json',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'bug_id': bugId,
      }),
    );

    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } else {
      print('fetchAzaiBugDetail 失敗: ${res.statusCode} ${res.body}');
      return null;
    }
  }
}


class DiseaseAzaiApiService {
  final String _baseUrl =
      dotenv.env['DISEASE_API_BASE_URL'] ?? 'http://140.113.79.235:10000';

  // ✅ 直接初始化，不需要 late、不需要建構子
  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {
        'accept': 'application/json',
        'content-type': 'application/json',
      },
    ),
  )
    ..interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: true,
      responseHeader: false,
    ));

  // -------------------------------
  // 搜尋 API
  // -------------------------------
  Future<Map<String, dynamic>?> searchAzaiBugs({
    required String term,
    String ty = 'y,y,y,y',
  }) async {
    try {
      final res = await _dio.post(
        '/api/azai/search',
        data: {
          'term': term,
          'ty': ty,
        },
      );

      if (res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('[DiseaseApiService] searchAzaiBugs error=$e');
      rethrow;
    }
  }

  // -------------------------------
  // 圖片 API
  // -------------------------------
  Future<Map<String, dynamic>?> fetchAzaiBugPics({
    required String bugId,
  }) async {
    try {
      final res = await _dio.post(
        '/api/azai/bug-pics',
        data: {'bug_id': bugId},
      );
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      print('[DiseaseApiService] fetchAzaiBugPics error=$e');
      rethrow;
    }
  }

  // -------------------------------
  // 詳細資料 API
  // -------------------------------
  Future<Map<String, dynamic>?> fetchAzaiBugDetail({
    required String bugId,
  }) async {
    try {
      final res = await _dio.post(
        '/api/azai/bug-detail',
        data: {'bug_id': bugId},
      );
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      print('[DiseaseApiService] fetchAzaiBugDetail error=$e');
      rethrow;
    }
  }
}
