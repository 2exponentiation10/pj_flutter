// Chapter(챕터)를 나타내는 클래스입니다.
class Chapter {
  final int id; // 챕터의 고유 식별자입니다.
  final String title; // 챕터의 제목입니다.

  // Chapter 객체를 초기화하는 생성자입니다.
  Chapter({required this.id, required this.title});

  // JSON으로부터 Chapter 객체를 생성하는 팩토리 메서드입니다.
  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'],
      title: json['title'],
    );
  }
}

// Word(단어)를 나타내는 클래스입니다.
class Word {
  final int id; // 단어의 고유 식별자입니다.
  final int chapterId; // 단어가 속한 챕터의 식별자입니다.
  final String koreanWord; // 남한 버전의 단어입니다.
  final String northKoreanWord; // 북한 버전의 단어입니다.
  bool isCalled; // 단어가 호출되었는지 여부를 나타냅니다.
  bool isCorrect; // 단어가 정답으로 맞춰졌는지 여부를 나타냅니다.
  bool isCollect; // 단어가 수집되었는지 여부를 나타냅니다.

  // Word 객체를 초기화하는 생성자입니다.
  Word({
    required this.id,
    required this.chapterId,
    required this.koreanWord,
    required this.northKoreanWord,
    this.isCalled = false,
    this.isCorrect = false,
    this.isCollect = false,
  });

  // JSON으로부터 Word 객체를 생성하는 팩토리 메서드입니다.
  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'],
      chapterId: json['chapter'],
      koreanWord: json['korean_word'],
      northKoreanWord: json['north_korean_word'],
      isCalled: json['is_called'],
      isCorrect: json['is_correct'],
      isCollect: json['is_collect'],
    );
  }
}

// ProgressData(진행 데이터)를 나타내는 클래스입니다.
class ProgressData {
  final List<ChapterProgress> progressData; // 챕터 진행 데이터를 나타내는 리스트입니다.
  final int completedChapters; // 완료된 챕터 수입니다.
  final double overallProgress; // 전체 진행률입니다.

  // ProgressData 객체를 초기화하는 생성자입니다.
  ProgressData({
    required this.progressData,
    required this.completedChapters,
    required this.overallProgress,
  });

  // JSON으로부터 ProgressData 객체를 생성하는 팩토리 메서드입니다.
  factory ProgressData.fromJson(Map<String, dynamic> json) {
    var list = json['progress_data'] as List;
    List<ChapterProgress> progressDataList =
        list.map((i) => ChapterProgress.fromJson(i)).toList();

    return ProgressData(
      progressData: progressDataList,
      completedChapters: json['completed_chapters'],
      overallProgress: json['overall_progress'],
    );
  }
}

// ChapterProgress(챕터 진행 상황)을 나타내는 클래스입니다.
class ChapterProgress {
  final int chapterId; // 챕터의 고유 식별자입니다.
  final String chapterTitle; // 챕터의 제목입니다.
  final double progress; // 챕터 진행률입니다.
  final double accuracy; // 챕터 정확도입니다.

  // ChapterProgress 객체를 초기화하는 생성자입니다.
  ChapterProgress({
    required this.chapterId,
    required this.chapterTitle,
    required this.progress,
    required this.accuracy,
  });

  // JSON으로부터 ChapterProgress 객체를 생성하는 팩토리 메서드입니다.
  factory ChapterProgress.fromJson(Map<String, dynamic> json) {
    return ChapterProgress(
      chapterId: json['chapter_id'],
      chapterTitle: json['chapter_title'],
      progress: json['progress'],
      accuracy: json['accuracy'],
    );
  }
}

class AppSentence {
  final int id; // 문장의 고유 식별자입니다.
  final int chapterId; // 문장이 속한 챕터의 식별자입니다.
  final String koreanSentence; // 남한 버전의 문장입니다.
  final String northKoreanSentence; // 북한 버전의 문장입니다.
  bool isCalled; // 문장이 호출되었는지 여부를 나타냅니다.
  bool isCorrect; // 문장이 정답으로 맞춰졌는지 여부를 나타냅니다.
  bool isCollect; // 문장이 수집되었는지 여부를 나타냅니다.
  double accuracy; // 문장의 정확도입니다.
  String recognizedText; // 인식된 텍스트입니다.

  // AppSentence 객체를 초기화하는 생성자입니다.
  AppSentence({
    required this.id,
    required this.chapterId,
    required this.koreanSentence,
    required this.northKoreanSentence,
    this.isCalled = false,
    this.isCorrect = false,
    this.isCollect = false,
    this.accuracy = 0.0,
    this.recognizedText = '',
  });

  // JSON으로부터 AppSentence 객체를 생성하는 팩토리 메서드입니다.
  factory AppSentence.fromJson(Map<String, dynamic> json) {
    return AppSentence(
      id: json['id'],
      chapterId: json['chapter'],
      koreanSentence: json['korean_sentence'],
      northKoreanSentence: json['north_korean_sentence'],
      isCalled: json['is_called'] ?? false,
      isCorrect: json['is_correct'] ?? false,
      isCollect: json['is_collect'] ?? false,
      accuracy: (json['accuracy'] ?? 0.0).toDouble(),
      recognizedText: json['recognized_text'] ?? '',
    );
  }
}

class PronunciationEvaluationResult {
  final String transcript;
  final double accuracyRatio;
  final double scorePercent;
  final double charSimilarity;
  final double tokenSimilarity;
  final String feedback;
  final String model;
  final String scoreLevel;
  final Map<String, dynamic> scoreRule;
  final double textScore;
  final bool audioMetricsAvailable;
  final double? speedScore;
  final double? pitchScore;
  final double? audioDurationSec;
  final double? syllablesPerSec;
  final double? pitchMedianHz;
  final double? pitchStdHz;

  PronunciationEvaluationResult({
    required this.transcript,
    required this.accuracyRatio,
    required this.scorePercent,
    required this.charSimilarity,
    required this.tokenSimilarity,
    required this.feedback,
    required this.model,
    required this.scoreLevel,
    required this.scoreRule,
    required this.textScore,
    required this.audioMetricsAvailable,
    this.speedScore,
    this.pitchScore,
    this.audioDurationSec,
    this.syllablesPerSec,
    this.pitchMedianHz,
    this.pitchStdHz,
  });

  factory PronunciationEvaluationResult.fromJson(Map<String, dynamic> json) {
    return PronunciationEvaluationResult(
      transcript: (json['transcript'] ?? '').toString(),
      accuracyRatio: (json['accuracy_ratio'] ?? 0).toDouble(),
      scorePercent: (json['score_percent'] ?? 0).toDouble(),
      charSimilarity: (json['char_similarity'] ?? 0).toDouble(),
      tokenSimilarity: (json['token_similarity'] ?? 0).toDouble(),
      feedback: (json['feedback'] ?? '').toString(),
      model: (json['model'] ?? '').toString(),
      scoreLevel: (json['score_level'] ?? '').toString(),
      scoreRule: (json['score_rule'] is Map<String, dynamic>)
          ? (json['score_rule'] as Map<String, dynamic>)
          : const <String, dynamic>{},
      textScore: (json['text_score'] ?? 0).toDouble(),
      audioMetricsAvailable: (json['audio_metrics_available'] ?? false) == true,
      speedScore: json['speed_score'] == null
          ? null
          : (json['speed_score'] as num).toDouble(),
      pitchScore: json['pitch_score'] == null
          ? null
          : (json['pitch_score'] as num).toDouble(),
      audioDurationSec: json['audio_duration_sec'] == null
          ? null
          : (json['audio_duration_sec'] as num).toDouble(),
      syllablesPerSec: json['syllables_per_sec'] == null
          ? null
          : (json['syllables_per_sec'] as num).toDouble(),
      pitchMedianHz: json['pitch_median_hz'] == null
          ? null
          : (json['pitch_median_hz'] as num).toDouble(),
      pitchStdHz: json['pitch_std_hz'] == null
          ? null
          : (json['pitch_std_hz'] as num).toDouble(),
    );
  }
}
