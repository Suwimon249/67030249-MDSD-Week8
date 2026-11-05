import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  // รับ API Key จาก:
  // flutter run --dart-define=GEMINI_API_KEY=YOUR_API_KEY
  static const String _apiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  static const String _model = 'gemini-3.5-flash-lite';

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  Future<String> generateText(String prompt) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'ไม่พบ API Key กรุณารันแอปด้วย '
        '--dart-define=GEMINI_API_KEY=your_key',
      );
    }

    final uri = Uri.parse(_baseUrl);

    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {
              "text": prompt,
            }
          ]
        }
      ]
    });

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
            body: body,
          )
          .timeout(
            const Duration(seconds: 20),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['candidates'] != null &&
            data['candidates'].isNotEmpty) {
          final candidate = data['candidates'][0];

          if (candidate['content'] != null &&
              candidate['content']['parts'] != null &&
              candidate['content']['parts'].isNotEmpty) {
            return candidate['content']['parts'][0]['text'];
          }
        }

        throw Exception(
          'AI ไม่สามารถสร้างคำตอบได้ '
          '(โครงสร้าง JSON ไม่ตรงที่คาดหวัง)',
        );
      } else {
        throw Exception(
          'เกิดข้อผิดพลาดจาก Gemini API: '
          '${response.statusCode}\n${response.body}',
        );
      }
    } on TimeoutException {
      throw Exception(
        'การเชื่อมต่อหมดเวลา (20 วินาที) '
        'AI อาจประมวลผลนานเกินไป',
      );
    } catch (e) {
      rethrow;
    }
  }
}