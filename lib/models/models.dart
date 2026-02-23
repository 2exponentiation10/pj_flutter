// Chapter(챕터)를 나타내는 클래스입니다.
class Chapter {
  final int id; // 챕터의 고유 식별자입니다.
  final String title; // 챕터의 제목입니다.
  final String difficulty; // 난이도 태그입니다.
  final String contextTag; // 상황 태그입니다.
  final String coverImageUrl;

  // Chapter 객체를 초기화하는 생성자입니다.
  Chapter({
    required this.id,
    required this.title,
    this.difficulty = 'beginner',
    this.contextTag = 'daily',
    this.coverImageUrl = '',
  });

  // JSON으로부터 Chapter 객체를 생성하는 팩토리 메서드입니다.
  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'],
      title: json['title'],
      difficulty: (json['difficulty'] ?? 'beginner').toString(),
      contextTag: (json['context_tag'] ?? 'daily').toString(),
      coverImageUrl: (json['cover_image_url'] ?? '').toString(),
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
  final String imageUrl;

  // Word 객체를 초기화하는 생성자입니다.
  Word({
    required this.id,
    required this.chapterId,
    required this.koreanWord,
    required this.northKoreanWord,
    this.isCalled = false,
    this.isCorrect = false,
    this.isCollect = false,
    this.imageUrl = '',
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
      imageUrl: (json['image_url'] ?? '').toString(),
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
  final String imageUrl;

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
    this.imageUrl = '',
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
      imageUrl: (json['image_url'] ?? '').toString(),
    );
  }
}

class MediaAssetItem {
  final int id;
  final String category;
  final String label;
  final String keyText;
  final int? chapterId;
  final int? wordId;
  final int? sentenceId;
  final String imageUrl;

  MediaAssetItem({
    required this.id,
    required this.category,
    required this.label,
    required this.keyText,
    this.chapterId,
    this.wordId,
    this.sentenceId,
    required this.imageUrl,
  });

  factory MediaAssetItem.fromJson(Map<String, dynamic> json) {
    return MediaAssetItem(
      id: json['id'] as int,
      category: (json['category'] ?? 'general').toString(),
      label: (json['label'] ?? '').toString(),
      keyText: (json['key_text'] ?? '').toString(),
      chapterId:
          json['chapter'] == null ? null : (json['chapter'] as num).toInt(),
      wordId: json['word'] == null ? null : (json['word'] as num).toInt(),
      sentenceId:
          json['sentence'] == null ? null : (json['sentence'] as num).toInt(),
      imageUrl: (json['image_url'] ?? '').toString(),
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
  final double? volumeScore;
  final double? audioDurationSec;
  final double? referenceDurationSec;
  final double? syllablesPerSec;
  final double? pitchMedianHz;
  final double? pitchStdHz;
  final List<double> userPitchCurve;
  final List<double> userVolumeCurve;
  final List<double> referencePitchCurve;
  final List<double> referenceVolumeCurve;
  final double? pitchCurveSimilarity;
  final double? volumeCurveSimilarity;
  final String pitchVerdict;
  final int? attemptId;
  final int? sentenceAttemptsCount;
  final double? sentenceBestScore;
  final int? recentWindowSize;
  final List<double> recentAttemptScores;
  final double? recentAvgScore;
  final double? recentScoreStddev;
  final double? recentAvgPitchScore;
  final double? recentAvgSpeedScore;
  final double? recentAvgVolumeScore;

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
    this.volumeScore,
    this.audioDurationSec,
    this.referenceDurationSec,
    this.syllablesPerSec,
    this.pitchMedianHz,
    this.pitchStdHz,
    this.userPitchCurve = const [],
    this.userVolumeCurve = const [],
    this.referencePitchCurve = const [],
    this.referenceVolumeCurve = const [],
    this.pitchCurveSimilarity,
    this.volumeCurveSimilarity,
    this.pitchVerdict = '',
    this.attemptId,
    this.sentenceAttemptsCount,
    this.sentenceBestScore,
    this.recentWindowSize,
    this.recentAttemptScores = const [],
    this.recentAvgScore,
    this.recentScoreStddev,
    this.recentAvgPitchScore,
    this.recentAvgSpeedScore,
    this.recentAvgVolumeScore,
  });

  static List<double> _toDoubleList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<num>()
        .map((e) => e.toDouble())
        .toList(growable: false);
  }

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
      volumeScore: json['volume_score'] == null
          ? null
          : (json['volume_score'] as num).toDouble(),
      audioDurationSec: json['audio_duration_sec'] == null
          ? null
          : (json['audio_duration_sec'] as num).toDouble(),
      referenceDurationSec: json['reference_duration_sec'] == null
          ? null
          : (json['reference_duration_sec'] as num).toDouble(),
      syllablesPerSec: json['syllables_per_sec'] == null
          ? null
          : (json['syllables_per_sec'] as num).toDouble(),
      pitchMedianHz: json['pitch_median_hz'] == null
          ? null
          : (json['pitch_median_hz'] as num).toDouble(),
      pitchStdHz: json['pitch_std_hz'] == null
          ? null
          : (json['pitch_std_hz'] as num).toDouble(),
      userPitchCurve: _toDoubleList(json['user_pitch_curve']),
      userVolumeCurve: _toDoubleList(json['user_volume_curve']),
      referencePitchCurve: _toDoubleList(json['reference_pitch_curve']),
      referenceVolumeCurve: _toDoubleList(json['reference_volume_curve']),
      pitchCurveSimilarity: json['pitch_curve_similarity'] == null
          ? null
          : (json['pitch_curve_similarity'] as num).toDouble(),
      volumeCurveSimilarity: json['volume_curve_similarity'] == null
          ? null
          : (json['volume_curve_similarity'] as num).toDouble(),
      pitchVerdict: (json['pitch_verdict'] ?? '').toString(),
      attemptId: json['attempt_id'] == null
          ? null
          : (json['attempt_id'] as num).toInt(),
      sentenceAttemptsCount: json['sentence_attempts_count'] == null
          ? null
          : (json['sentence_attempts_count'] as num).toInt(),
      sentenceBestScore: json['sentence_best_score'] == null
          ? null
          : (json['sentence_best_score'] as num).toDouble(),
      recentWindowSize: json['recent_window_size'] == null
          ? null
          : (json['recent_window_size'] as num).toInt(),
      recentAttemptScores: _toDoubleList(json['recent_attempt_scores']),
      recentAvgScore: json['recent_avg_score'] == null
          ? null
          : (json['recent_avg_score'] as num).toDouble(),
      recentScoreStddev: json['recent_score_stddev'] == null
          ? null
          : (json['recent_score_stddev'] as num).toDouble(),
      recentAvgPitchScore: json['recent_avg_pitch_score'] == null
          ? null
          : (json['recent_avg_pitch_score'] as num).toDouble(),
      recentAvgSpeedScore: json['recent_avg_speed_score'] == null
          ? null
          : (json['recent_avg_speed_score'] as num).toDouble(),
      recentAvgVolumeScore: json['recent_avg_volume_score'] == null
          ? null
          : (json['recent_avg_volume_score'] as num).toDouble(),
    );
  }
}

class ReviewQueueItem {
  final int sentenceId;
  final int chapterId;
  final String chapterTitle;
  final String difficulty;
  final String contextTag;
  final String koreanSentence;
  final String northKoreanSentence;
  final double sentenceAccuracyRatio;
  final double? lastScorePercent;
  final double? recentAvgScorePercent;
  final double priorityScore;
  final String reason;

  ReviewQueueItem({
    required this.sentenceId,
    required this.chapterId,
    required this.chapterTitle,
    required this.difficulty,
    required this.contextTag,
    required this.koreanSentence,
    required this.northKoreanSentence,
    required this.sentenceAccuracyRatio,
    required this.lastScorePercent,
    required this.recentAvgScorePercent,
    required this.priorityScore,
    required this.reason,
  });

  factory ReviewQueueItem.fromJson(Map<String, dynamic> json) {
    return ReviewQueueItem(
      sentenceId: (json['sentence_id'] as num).toInt(),
      chapterId: (json['chapter_id'] as num).toInt(),
      chapterTitle: (json['chapter_title'] ?? '').toString(),
      difficulty: (json['difficulty'] ?? 'beginner').toString(),
      contextTag: (json['context_tag'] ?? 'daily').toString(),
      koreanSentence: (json['korean_sentence'] ?? '').toString(),
      northKoreanSentence: (json['north_korean_sentence'] ?? '').toString(),
      sentenceAccuracyRatio:
          ((json['sentence_accuracy_ratio'] ?? 0) as num).toDouble(),
      lastScorePercent: json['last_score_percent'] == null
          ? null
          : (json['last_score_percent'] as num).toDouble(),
      recentAvgScorePercent: json['recent_avg_score_percent'] == null
          ? null
          : (json['recent_avg_score_percent'] as num).toDouble(),
      priorityScore: ((json['priority_score'] ?? 0) as num).toDouble(),
      reason: (json['reason'] ?? '').toString(),
    );
  }
}
