import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import '../models/models.dart';

class ApiService {
  static const String _localBaseUrl = 'http://127.0.0.1:8000/api';
  static const String _androidEmulatorBaseUrl = 'http://10.0.2.2:8000/api';
  static const String _webDefaultBaseUrl = 'http://127.0.0.1:8000/api';

  // 기본 URL을 동적으로 설정합니다.
  static String get baseUrl {
    const configuredBaseUrl =
        String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl;
    }
    if (kIsWeb) {
      return _webDefaultBaseUrl;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _androidEmulatorBaseUrl;
    }
    return _localBaseUrl;
  }

  Future<void> updateSentenceAccuracyAndText(
      int sentenceId, double accuracy, String recognizedText) async {
    final url =
        Uri.parse('$baseUrl/sentences/$sentenceId/update_accuracy_and_text/');
    final body = jsonEncode(<String, dynamic>{
      'accuracy': accuracy,
      'recognized_text': recognizedText,
    });

    print('Request URL: $url');
    print('Request body: $body');

    final response = await http.put(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      throw Exception('Failed to update sentence accuracy and text');
    }

    print('Update successful');
  }

  Future<void> updateSentenceAccuracy(
      int sentenceId, double accuracy, String recognizedText) async {
    final response = await http.put(
      Uri.parse('$baseUrl/sentences/$sentenceId/update_accuracy/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, dynamic>{
        'accuracy': accuracy,
        'recognized_text': recognizedText,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update sentence accuracy and text');
    }
  }

  Future<List<Chapter>> fetchChapters() async {
    final response = await http.get(
      Uri.parse('$baseUrl/chapters/'),
      headers: {"Content-Type": "application/json; charset=UTF-8"},
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      return jsonResponse.map((chapter) => Chapter.fromJson(chapter)).toList();
    } else {
      throw Exception('Failed to load chapters');
    }
  }

  Future<Chapter> fetchChapter(int chapterId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/chapters/$chapterId/'),
      headers: {"Content-Type": "application/json; charset=UTF-8"},
    );

    if (response.statusCode == 200) {
      return Chapter.fromJson(json.decode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Failed to load chapter');
    }
  }

  Future<double> fetchChapterAccuracy(int chapterId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/chapters/$chapterId/accuracy/'),
      headers: {"Content-Type": "application/json; charset=UTF-8"},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body)['accuracy'];
    } else {
      throw Exception('Failed to load chapter accuracy');
    }
  }

  Future<List<Word>> fetchWords(int chapterId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/chapters/$chapterId/words/'));

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((item) => Word.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load words');
    }
  }

  Future<List<Word>> fetchAllWords() async {
    final response = await http.get(Uri.parse('$baseUrl/words/'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load words');
    }
    final data = json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return data.map((item) => Word.fromJson(item)).toList();
  }

  Future<void> saveWord(int wordId) async {
    final response = await http.post(
      Uri.parse('${baseUrl}/words/$wordId/save/'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to save word');
    }
  }

  Future<List<Word>> fetchSavedWords() async {
    final response = await http.get(
      Uri.parse('$baseUrl/saved_words/'),
    );

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((item) => Word.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load saved words');
    }
  }

  Future<List<AppSentence>> fetchSentences(int chapterId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/chapters/$chapterId/sentences/'));

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      print('Fetched sentences successfully: ${data.length} sentences');
      return data.map((item) => AppSentence.fromJson(item)).toList();
    } else {
      print(
          'Failed to load sentences: ${response.statusCode} ${response.body}');
      throw Exception('Failed to load sentences');
    }
  }

  Future<List<AppSentence>> fetchAllSentences() async {
    final response = await http.get(Uri.parse('$baseUrl/sentences/'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load sentences');
    }
    final data = json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return data.map((item) => AppSentence.fromJson(item)).toList();
  }

  Future<void> saveSentence(int sentenceId) async {
    final response = await http.post(
      Uri.parse('${baseUrl}/sentences/$sentenceId/save/'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to save sentence');
    }
  }

  Future<void> updateSentenceIsCollect(
      int sentenceId, bool isCorrect, bool isCollect) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/sentences/$sentenceId/update/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'is_correct': isCorrect, 'is_collect': isCollect}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update sentence');
    }
  }

  Future<List<AppSentence>> fetchSavedSentences() async {
    final response = await http.get(
      Uri.parse('$baseUrl/saved_sentences/'),
    );

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((item) => AppSentence.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load saved sentences');
    }
  }

  Future<void> updateSentenceIsCalled(int sentenceId) async {
    final response = await http
        .post(Uri.parse('$baseUrl/sentences/$sentenceId/mark_called/'));

    if (response.statusCode != 200) {
      throw Exception('Failed to update sentence');
    }
  }

  Future<Map<String, dynamic>> resetSentencePronunciation(
      int sentenceId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sentences/$sentenceId/reset_pronunciation/'),
      headers: {"Content-Type": "application/json; charset=UTF-8"},
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    throw Exception('Failed to reset pronunciation attempts');
  }

  Future<ProgressData> fetchProgressData() async {
    final response = await http.get(
      Uri.parse('$baseUrl/get_progress/'),
    );

    if (response.statusCode == 200) {
      return ProgressData.fromJson(
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Failed to load progress data');
    }
  }

  Future<void> updateWordIsCollect(int wordId, bool isCollect) async {
    final response = await http.patch(
      Uri.parse('${baseUrl}/words/$wordId/update/'),
      headers: {"Content-Type": "application/json; charset=UTF-8"},
      body: jsonEncode({'is_collect': isCollect ? 1 : 0}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update word is_collect');
    }
  }

  Future<Chapter> fetchNextChapter() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/next_chapter/'));
      if (response.statusCode == 200) {
        return Chapter.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      } else {
        print('Failed to load next chapter: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to load next chapter');
      }
    } catch (e) {
      print('Error fetching next chapter: $e');
      throw Exception('Failed to load next chapter');
    }
  }

  Future<List<ReviewQueueItem>> fetchReviewQueue({int limit = 12}) async {
    final response =
        await http.get(Uri.parse('$baseUrl/review_queue/?limit=$limit'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load review queue');
    }
    final data = json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return data
        .whereType<Map<String, dynamic>>()
        .map(ReviewQueueItem.fromJson)
        .toList();
  }

  Future<List<Word>> fetchIncollectWords(int chapterId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/chapters/$chapterId/incollect_words/'),
    );

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((item) => Word.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load incollect words');
    }
  }

  Future<void> updateWordIsCalled(int wordId) async {
    final response =
        await http.post(Uri.parse('$baseUrl/words/$wordId/mark_called/'));

    if (response.statusCode != 200) {
      throw Exception('Failed to update word');
    }
  }

  Future<Map<String, dynamic>> fetchLearningProgress(int chapterId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/chapters/$chapterId/learning_progress/'));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load learning progress');
    }
  }

  Future<List<AppSentence>> fetchEvaluationResults(int chapterId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/chapters/$chapterId/evaluation_results/'));

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      print('Fetched evaluation results: $data'); // 로그 추가
      return data.map((item) => AppSentence.fromJson(item)).toList();
    } else {
      print(
          'Failed to load evaluation results: ${response.statusCode} ${response.body}'); // 로그 추가
      throw Exception('Failed to load evaluation results');
    }
  }

  Future<String> sendChatMessage(String message) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/chat/'),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({'message': message}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data =
          json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return (data['reply'] ?? '').toString();
    }

    final body = utf8.decode(response.bodyBytes);
    throw Exception(
        'Failed to get chat response: ${response.statusCode} $body');
  }

  Future<PronunciationEvaluationResult> evaluatePronunciation({
    required String referenceText,
    int? sentenceId,
    String? recognizedText,
    Uint8List? audioBytes,
    String fileName = 'speech.webm',
    String contentType = 'audio/webm',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/pronunciation/evaluate/'),
    );

    request.fields['reference_text'] = referenceText;
    if (sentenceId != null) {
      request.fields['sentence_id'] = sentenceId.toString();
    }
    if (recognizedText != null && recognizedText.trim().isNotEmpty) {
      request.fields['recognized_text'] = recognizedText.trim();
    }
    if (audioBytes != null && audioBytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'audio',
          audioBytes,
          filename: fileName,
          contentType: MediaType.parse(contentType),
        ),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final payload =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return PronunciationEvaluationResult.fromJson(payload);
    }
    throw Exception(
        'Failed to evaluate pronunciation: ${response.statusCode} ${response.body}');
  }

  Future<Chapter> createChapter({
    required String title,
    String difficulty = 'beginner',
    String contextTag = 'daily',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chapters/'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'title': title,
        'difficulty': difficulty,
        'context_tag': contextTag,
        'accuracy': 0.0,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create chapter: ${response.body}');
    }
    return Chapter.fromJson(
      json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<Chapter> updateChapter({
    required int chapterId,
    required String title,
    required String difficulty,
    required String contextTag,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/chapters/$chapterId/'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'title': title,
        'difficulty': difficulty,
        'context_tag': contextTag,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update chapter: ${response.body}');
    }
    return Chapter.fromJson(
      json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<void> deleteChapter(int chapterId) async {
    final response =
        await http.delete(Uri.parse('$baseUrl/chapters/$chapterId/'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete chapter: ${response.body}');
    }
  }

  Future<Word> createWord({
    required int chapterId,
    required String koreanWord,
    required String northKoreanWord,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/words/'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'chapter': chapterId,
        'korean_word': koreanWord,
        'north_korean_word': northKoreanWord,
        'is_called': false,
        'is_correct': false,
        'is_collect': false,
        'accuracy': 0.0,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create word: ${response.body}');
    }
    return Word.fromJson(
      json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<Word> updateWordContent({
    required int wordId,
    required int chapterId,
    required String koreanWord,
    required String northKoreanWord,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/words/$wordId/'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'chapter': chapterId,
        'korean_word': koreanWord,
        'north_korean_word': northKoreanWord,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update word: ${response.body}');
    }
    return Word.fromJson(
      json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<void> deleteWord(int wordId) async {
    final response = await http.delete(Uri.parse('$baseUrl/words/$wordId/'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete word: ${response.body}');
    }
  }

  Future<AppSentence> createSentence({
    required int chapterId,
    required String koreanSentence,
    required String northKoreanSentence,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sentences/'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'chapter': chapterId,
        'korean_sentence': koreanSentence,
        'north_korean_sentence': northKoreanSentence,
        'is_called': false,
        'is_correct': false,
        'is_collect': false,
        'accuracy': 0.0,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create sentence: ${response.body}');
    }
    return AppSentence.fromJson(
      json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<AppSentence> updateSentenceContent({
    required int sentenceId,
    required int chapterId,
    required String koreanSentence,
    required String northKoreanSentence,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/sentences/$sentenceId/'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'chapter': chapterId,
        'korean_sentence': koreanSentence,
        'north_korean_sentence': northKoreanSentence,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update sentence: ${response.body}');
    }
    return AppSentence.fromJson(
      json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<void> deleteSentence(int sentenceId) async {
    final response =
        await http.delete(Uri.parse('$baseUrl/sentences/$sentenceId/'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete sentence: ${response.body}');
    }
  }

  Future<List<MediaAssetItem>> fetchMediaAssets() async {
    final response = await http.get(Uri.parse('$baseUrl/media-assets/'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load media assets');
    }
    final list = json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(MediaAssetItem.fromJson)
        .toList();
  }

  Future<MediaAssetItem> createMediaAsset({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String category,
    String label = '',
    String keyText = '',
    int? chapterId,
    int? wordId,
    int? sentenceId,
  }) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/media-assets/'),
    );
    req.fields['category'] = category;
    req.fields['label'] = label;
    req.fields['key_text'] = keyText;
    if (chapterId != null) req.fields['chapter'] = chapterId.toString();
    if (wordId != null) req.fields['word'] = wordId.toString();
    if (sentenceId != null) req.fields['sentence'] = sentenceId.toString();
    req.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: fileName,
        contentType: MediaType.parse(contentType),
      ),
    );
    final streamed = await req.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 201) {
      throw Exception('Failed to create media asset: ${response.body}');
    }
    return MediaAssetItem.fromJson(
      json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<void> deleteMediaAsset(int assetId) async {
    final response =
        await http.delete(Uri.parse('$baseUrl/media-assets/$assetId/'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete media asset: ${response.body}');
    }
  }
}
