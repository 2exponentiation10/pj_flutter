import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';

class AdminConsolePage extends StatefulWidget {
  const AdminConsolePage({
    super.key,
    required this.adminPin,
  });

  final String adminPin;

  @override
  State<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends State<AdminConsolePage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  late final TabController _tabController;
  Timer? _visualJobPollingTimer;

  bool _isLoading = true;
  bool _isRegeneratingVisuals = false;
  String _searchQuery = '';
  String _assetCategoryFilter = 'all';
  VisualGenerationJobStatus? _visualJob;
  int? _lastAnnouncedVisualJobId;

  List<Chapter> _chapters = const [];
  List<Word> _words = const [];
  List<AppSentence> _sentences = const [];
  List<MediaAssetItem> _assets = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _refreshAll();
    unawaited(_loadLatestVisualJob());
  }

  @override
  void dispose() {
    _visualJobPollingTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    setState(() => _isLoading = true);
    try {
      final chapters = await _api.fetchChapters();
      final words = await _api.fetchAllWords();
      final sentences = await _api.fetchAllSentences();
      final assets = await _api.fetchMediaAssets();
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _words = words;
        _sentences = sentences;
        _assets = assets;
      });
    } catch (e) {
      _showSnack('관리 데이터 로드 실패: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLatestVisualJob({bool announceCompletion = false}) async {
    try {
      final job = await _api.fetchLatestLearningVisualJob(
        adminPin: widget.adminPin,
      );
      if (!mounted) return;

      final previousJob = _visualJob;
      setState(() {
        _visualJob = job;
        _isRegeneratingVisuals = job?.isRunning ?? false;
      });

      if (job != null && job.isRunning) {
        _startVisualJobPolling();
      } else {
        _visualJobPollingTimer?.cancel();
      }

      final justFinished = previousJob != null &&
          previousJob.id == job?.id &&
          previousJob.isRunning &&
          job != null &&
          !job.isRunning;
      if (announceCompletion &&
          justFinished &&
          _lastAnnouncedVisualJobId != job.id) {
        _lastAnnouncedVisualJobId = job.id;
        if (job.status == 'succeeded') {
          await _refreshAll();
          _showSnack(
            '자동 시각자료 재생성 완료 · 챕터 ${job.chaptersCount} / 단어 ${job.wordsCount} / 문장 ${job.sentencesCount}',
          );
        } else if (job.status == 'failed') {
          _showSnack(
            '자동 시각자료 재생성 실패: ${job.errorText.isEmpty ? job.message : job.errorText}',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('시각자료 작업 상태 조회 실패: $e');
    }
  }

  void _startVisualJobPolling() {
    _visualJobPollingTimer?.cancel();
    _visualJobPollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_loadLatestVisualJob(announceCompletion: true));
    });
  }

  Future<void> _regenerateLearningVisuals() async {
    setState(() => _isRegeneratingVisuals = true);
    try {
      final job = await _api.regenerateLearningVisuals(
        adminPin: widget.adminPin,
      );
      if (!mounted) return;
      setState(() {
        _visualJob = job;
        _isRegeneratingVisuals = job.isRunning;
      });
      _startVisualJobPolling();
      _showSnack('자동 시각자료 재생성 작업을 시작했습니다.');
    } catch (e) {
      _showSnack('자동 시각자료 재생성 실패: $e');
    } finally {
      if (mounted && !(_visualJob?.isRunning ?? false)) {
        setState(() => _isRegeneratingVisuals = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool _matches(String text) {
    if (_searchQuery.trim().isEmpty) return true;
    return text.toLowerCase().contains(_searchQuery.trim().toLowerCase());
  }

  Future<bool> _confirmDelete(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('삭제'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _openChapterDialog({Chapter? initial}) async {
    final titleCtrl = TextEditingController(text: initial?.title ?? '');
    String difficulty = initial?.difficulty ?? 'beginner';
    final contextCtrl =
        TextEditingController(text: initial?.contextTag ?? 'daily');

    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(initial == null ? '챕터 추가' : '챕터 수정'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: '제목'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: difficulty,
                  items: const [
                    DropdownMenuItem(
                        value: 'beginner', child: Text('beginner')),
                    DropdownMenuItem(
                        value: 'intermediate', child: Text('intermediate')),
                    DropdownMenuItem(
                        value: 'advanced', child: Text('advanced')),
                  ],
                  onChanged: (v) => difficulty = v ?? 'beginner',
                  decoration: const InputDecoration(labelText: '난이도'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contextCtrl,
                  decoration:
                      const InputDecoration(labelText: '상황 태그(context_tag)'),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('저장')),
            ],
          ),
        ) ??
        false;

    if (!ok) return;
    try {
      if (initial == null) {
        await _api.createChapter(
          title: titleCtrl.text.trim(),
          difficulty: difficulty,
          contextTag: contextCtrl.text.trim(),
        );
      } else {
        await _api.updateChapter(
          chapterId: initial.id,
          title: titleCtrl.text.trim(),
          difficulty: difficulty,
          contextTag: contextCtrl.text.trim(),
        );
      }
      await _refreshAll();
      _showSnack('챕터 저장 완료');
    } catch (e) {
      _showSnack('챕터 저장 실패: $e');
    }
  }

  Future<void> _openWordDialog({Word? initial}) async {
    int chapterId =
        initial?.chapterId ?? (_chapters.isNotEmpty ? _chapters.first.id : 1);
    final koCtrl = TextEditingController(text: initial?.koreanWord ?? '');
    final nkCtrl = TextEditingController(text: initial?.northKoreanWord ?? '');

    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(initial == null ? '단어 추가' : '단어 수정'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: chapterId,
                  items: _chapters
                      .map((c) => DropdownMenuItem(
                          value: c.id, child: Text('#${c.id} ${c.title}')))
                      .toList(),
                  onChanged: (v) => chapterId = v ?? chapterId,
                  decoration: const InputDecoration(labelText: '챕터'),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: koCtrl,
                    decoration: const InputDecoration(labelText: '남한 단어')),
                const SizedBox(height: 10),
                TextField(
                    controller: nkCtrl,
                    decoration: const InputDecoration(labelText: '북한 단어')),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('저장')),
            ],
          ),
        ) ??
        false;

    if (!ok) return;
    try {
      if (initial == null) {
        await _api.createWord(
          chapterId: chapterId,
          koreanWord: koCtrl.text.trim(),
          northKoreanWord: nkCtrl.text.trim(),
        );
      } else {
        await _api.updateWordContent(
          wordId: initial.id,
          chapterId: chapterId,
          koreanWord: koCtrl.text.trim(),
          northKoreanWord: nkCtrl.text.trim(),
        );
      }
      await _refreshAll();
      _showSnack('단어 저장 완료');
    } catch (e) {
      _showSnack('단어 저장 실패: $e');
    }
  }

  Future<void> _openSentenceDialog({AppSentence? initial}) async {
    int chapterId =
        initial?.chapterId ?? (_chapters.isNotEmpty ? _chapters.first.id : 1);
    final koCtrl = TextEditingController(text: initial?.koreanSentence ?? '');
    final nkCtrl =
        TextEditingController(text: initial?.northKoreanSentence ?? '');

    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(initial == null ? '문장 추가' : '문장 수정'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: chapterId,
                  items: _chapters
                      .map((c) => DropdownMenuItem(
                          value: c.id, child: Text('#${c.id} ${c.title}')))
                      .toList(),
                  onChanged: (v) => chapterId = v ?? chapterId,
                  decoration: const InputDecoration(labelText: '챕터'),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: koCtrl,
                    decoration: const InputDecoration(labelText: '남한 문장')),
                const SizedBox(height: 10),
                TextField(
                    controller: nkCtrl,
                    decoration: const InputDecoration(labelText: '북한 문장')),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('저장')),
            ],
          ),
        ) ??
        false;

    if (!ok) return;
    try {
      if (initial == null) {
        await _api.createSentence(
          chapterId: chapterId,
          koreanSentence: koCtrl.text.trim(),
          northKoreanSentence: nkCtrl.text.trim(),
        );
      } else {
        await _api.updateSentenceContent(
          sentenceId: initial.id,
          chapterId: chapterId,
          koreanSentence: koCtrl.text.trim(),
          northKoreanSentence: nkCtrl.text.trim(),
        );
      }
      await _refreshAll();
      _showSnack('문장 저장 완료');
    } catch (e) {
      _showSnack('문장 저장 실패: $e');
    }
  }

  Future<void> _openAssetDialog() async {
    String category = 'word';
    int? chapterId;
    int? wordId;
    int? sentenceId;
    final labelCtrl = TextEditingController();
    final keyCtrl = TextEditingController();

    Uint8List? selectedBytes;
    String selectedName = 'upload.png';
    String selectedMime = 'image/png';

    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setStateDialog) => AlertDialog(
              title: const Text('이미지 업로드'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: category,
                      items: const [
                        DropdownMenuItem(value: 'word', child: Text('word')),
                        DropdownMenuItem(
                            value: 'sentence', child: Text('sentence')),
                        DropdownMenuItem(
                            value: 'chapter', child: Text('chapter')),
                        DropdownMenuItem(
                            value: 'general', child: Text('general')),
                      ],
                      onChanged: (v) {
                        category = v ?? 'word';
                        if (category == 'general') {
                          chapterId = null;
                          wordId = null;
                          sentenceId = null;
                        } else if (category == 'chapter') {
                          wordId = null;
                          sentenceId = null;
                        } else if (category == 'word') {
                          sentenceId = null;
                        } else if (category == 'sentence') {
                          wordId = null;
                        }
                        setStateDialog(() {});
                      },
                      decoration: const InputDecoration(labelText: '카테고리'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                        controller: labelCtrl,
                        decoration: const InputDecoration(labelText: '라벨(선택)')),
                    const SizedBox(height: 10),
                    TextField(
                      controller: keyCtrl,
                      decoration: const InputDecoration(
                          labelText: 'key_text(자동매핑용: 단어/문장 원문)'),
                    ),
                    const SizedBox(height: 10),
                    if (category == 'chapter' ||
                        category == 'word' ||
                        category == 'sentence') ...[
                      DropdownButtonFormField<int?>(
                        value: chapterId,
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null, child: Text('챕터 연결 없음')),
                          ..._chapters.map(
                            (c) => DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text('#${c.id} ${c.title}')),
                          ),
                        ],
                        onChanged: (v) {
                          chapterId = v;
                          setStateDialog(() {});
                        },
                        decoration: const InputDecoration(labelText: '챕터 연결'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (category == 'word') ...[
                      DropdownButtonFormField<int?>(
                        value: wordId,
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null, child: Text('단어 연결 없음')),
                          ..._words
                              .where((w) =>
                                  chapterId == null || w.chapterId == chapterId)
                              .map(
                                (w) => DropdownMenuItem<int?>(
                                  value: w.id,
                                  child: Text('#${w.id} ${w.koreanWord}'),
                                ),
                              ),
                        ],
                        onChanged: (v) {
                          wordId = v;
                          Word? selectedWord;
                          for (final word in _words) {
                            if (word.id == v) {
                              selectedWord = word;
                              break;
                            }
                          }
                          if (selectedWord != null) {
                            chapterId = selectedWord.chapterId;
                            if (keyCtrl.text.trim().isEmpty) {
                              keyCtrl.text = selectedWord.koreanWord;
                            }
                          }
                          setStateDialog(() {});
                        },
                        decoration: const InputDecoration(labelText: '단어 연결'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (category == 'sentence') ...[
                      DropdownButtonFormField<int?>(
                        value: sentenceId,
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null, child: Text('문장 연결 없음')),
                          ..._sentences
                              .where((s) =>
                                  chapterId == null || s.chapterId == chapterId)
                              .map(
                                (s) => DropdownMenuItem<int?>(
                                  value: s.id,
                                  child: Text('#${s.id} ${s.koreanSentence}'),
                                ),
                              ),
                        ],
                        onChanged: (v) {
                          sentenceId = v;
                          AppSentence? selectedSentence;
                          for (final sentence in _sentences) {
                            if (sentence.id == v) {
                              selectedSentence = sentence;
                              break;
                            }
                          }
                          if (selectedSentence != null) {
                            chapterId = selectedSentence.chapterId;
                            if (keyCtrl.text.trim().isEmpty) {
                              keyCtrl.text = selectedSentence.koreanSentence;
                            }
                          }
                          setStateDialog(() {});
                        },
                        decoration: const InputDecoration(labelText: '문장 연결'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          withData: true,
                        );
                        if (result == null || result.files.isEmpty) return;
                        final file = result.files.first;
                        Uint8List? bytes = file.bytes;
                        if (bytes == null && file.path != null && !kIsWeb) {
                          bytes = await File(file.path!).readAsBytes();
                        }
                        if (bytes == null || bytes.isEmpty) return;
                        selectedBytes = bytes;
                        selectedName = file.name;
                        selectedMime = _guessImageMime(file.name);
                        setStateDialog(() {});
                      },
                      icon: const Icon(Icons.file_upload_rounded),
                      label: const Text('이미지 선택'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      selectedBytes == null
                          ? '선택된 파일 없음'
                          : '선택됨: $selectedName (${selectedBytes!.lengthInBytes} bytes)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (selectedBytes != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          selectedBytes!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('업로드')),
              ],
            ),
          ),
        ) ??
        false;

    if (!ok) return;
    if (selectedBytes == null || selectedBytes!.isEmpty) {
      _showSnack('업로드할 이미지 파일을 먼저 선택해 주세요.');
      return;
    }

    try {
      await _api.createMediaAsset(
        bytes: selectedBytes!,
        fileName: selectedName,
        contentType: selectedMime,
        category: category,
        label: labelCtrl.text.trim(),
        keyText: keyCtrl.text.trim(),
        chapterId: chapterId,
        wordId: wordId,
        sentenceId: sentenceId,
      );
      await _refreshAll();
      _showSnack('이미지 업로드 완료');
    } catch (e) {
      _showSnack('이미지 업로드 실패: $e');
    }
  }

  String _guessImageMime(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/png';
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = _tabController.index;

    return Scaffold(
      appBar: AppBar(
        title: const Text('시나브로 Admin Studio'),
        actions: [
          TextButton.icon(
            onPressed:
                _isRegeneratingVisuals ? null : _regenerateLearningVisuals,
            icon: _isRegeneratingVisuals
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_rounded),
            label: const Text('자동 시각자료'),
          ),
          IconButton(
              onPressed: _refreshAll, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (currentTab == 0) {
            _openAssetDialog();
          } else if (currentTab == 1) {
            _openChapterDialog();
          } else if (currentTab == 2) {
            _openWordDialog();
          } else {
            _openSentenceDialog();
          }
        },
        label: Text(currentTab == 0 ? '이미지 업로드' : '콘텐츠 추가'),
        icon: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildOverviewPanel(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                hintText: '단어/문장/태그 검색',
              ),
            ),
          ),
          const SizedBox(height: 10),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: '이미지'),
              Tab(text: '챕터'),
              Tab(text: '단어'),
              Tab(text: '문장'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAssetTab(),
                      _buildChapterTab(),
                      _buildWordTab(),
                      _buildSentenceTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '콘텐츠 운영 대시보드',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text('챕터, 단어/문장, 이미지 자산을 한 곳에서 관리합니다.'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '챕터 커버, 단어 카드, 문장 장면 카드를 자동으로 다시 생성할 수 있습니다.',
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _isRegeneratingVisuals
                      ? null
                      : _regenerateLearningVisuals,
                  icon: _isRegeneratingVisuals
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('다시 생성'),
                ),
              ],
            ),
          ),
          if (_visualJob != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _visualJob!.status == 'failed'
                            ? Icons.error_outline_rounded
                            : _visualJob!.isRunning
                                ? Icons.sync_rounded
                                : Icons.check_circle_outline_rounded,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '최근 시각자료 작업 #${_visualJob!.id} · ${_visualJob!.status}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _loadLatestVisualJob(),
                        child: const Text('상태 갱신'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _visualJob!.totalItems == 0
                        ? null
                        : _visualJob!.progressRatio.clamp(0, 1),
                  ),
                  const SizedBox(height: 10),
                  Text(_visualJob!.message.isEmpty
                      ? '상태 메시지 없음'
                      : _visualJob!.message),
                  const SizedBox(height: 6),
                  Text(
                    '진행 ${_visualJob!.completedItems}/${_visualJob!.totalItems} · 챕터 ${_visualJob!.chaptersCount} / 단어 ${_visualJob!.wordsCount} / 문장 ${_visualJob!.sentencesCount}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_visualJob!.errorText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _visualJob!.errorText,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip(Icons.menu_book_rounded, '챕터 ${_chapters.length}'),
              _metricChip(Icons.spellcheck_rounded, '단어 ${_words.length}'),
              _metricChip(Icons.short_text_rounded, '문장 ${_sentences.length}'),
              _metricChip(Icons.image_rounded, '이미지 ${_assets.length}'),
            ],
          )
        ],
      ),
    );
  }

  Widget _metricChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildAssetTab() {
    final filtered = _assets.where((item) {
      final byCategory = _assetCategoryFilter == 'all' ||
          item.category == _assetCategoryFilter;
      final byQuery =
          _matches('${item.label} ${item.keyText} ${item.category}');
      return byCategory && byQuery;
    }).toList();

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _categoryChip('all', '전체'),
              _categoryChip('word', '단어'),
              _categoryChip('sentence', '문장'),
              _categoryChip('chapter', '챕터'),
              _categoryChip('general', '일반'),
            ],
          ),
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text('조건에 맞는 이미지 자산이 없습니다.')),
            ),
          ...filtered.map((item) => Card(
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.imageUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: Colors.grey.shade300,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                  title: Text(
                      '[${item.category}] ${item.label.isEmpty ? '(무라벨)' : item.label}'),
                  subtitle: Text(
                    'key=${item.keyText.isEmpty ? '-' : item.keyText}\nchapter=${item.chapterId ?? '-'} / word=${item.wordId ?? '-'} / sentence=${item.sentenceId ?? '-'}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      final ok =
                          await _confirmDelete('이미지 삭제', '선택한 이미지 자산을 삭제할까요?');
                      if (!ok) return;
                      await _api.deleteMediaAsset(item.id);
                      await _refreshAll();
                    },
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _categoryChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _assetCategoryFilter == value,
      onSelected: (_) => setState(() => _assetCategoryFilter = value),
      showCheckmark: false,
    );
  }

  Widget _buildChapterTab() {
    final filtered = _chapters.where((c) {
      return _matches('${c.id} ${c.title} ${c.contextTag} ${c.difficulty}');
    }).toList();

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text('조건에 맞는 챕터가 없습니다.')),
            ),
          ...filtered.map(
            (c) => Card(
              child: ListTile(
                title: Text('#${c.id} ${c.title}'),
                subtitle: Text('난이도 ${c.difficulty} · 태그 ${c.contextTag}'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _openChapterDialog(initial: c),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        final ok = await _confirmDelete(
                            '챕터 삭제', '챕터를 삭제하면 하위 데이터 영향이 있을 수 있습니다. 계속할까요?');
                        if (!ok) return;
                        await _api.deleteChapter(c.id);
                        await _refreshAll();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordTab() {
    final filtered = _words.where((w) {
      return _matches(
          '${w.id} ${w.koreanWord} ${w.northKoreanWord} ${w.chapterId}');
    }).toList();

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text('조건에 맞는 단어가 없습니다.')),
            ),
          ...filtered.map(
            (w) => Card(
              child: ListTile(
                title: Text('#${w.id} ${w.koreanWord}'),
                subtitle:
                    Text('북한어: ${w.northKoreanWord} · chapter=${w.chapterId}'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _openWordDialog(initial: w),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        final ok =
                            await _confirmDelete('단어 삭제', '선택한 단어를 삭제할까요?');
                        if (!ok) return;
                        await _api.deleteWord(w.id);
                        await _refreshAll();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentenceTab() {
    final filtered = _sentences.where((s) {
      return _matches(
          '${s.id} ${s.koreanSentence} ${s.northKoreanSentence} ${s.chapterId}');
    }).toList();

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text('조건에 맞는 문장이 없습니다.')),
            ),
          ...filtered.map(
            (s) => Card(
              child: ListTile(
                title: Text('#${s.id} ${s.koreanSentence}'),
                subtitle: Text(
                    '북한식: ${s.northKoreanSentence} · chapter=${s.chapterId}'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _openSentenceDialog(initial: s),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        final ok =
                            await _confirmDelete('문장 삭제', '선택한 문장을 삭제할까요?');
                        if (!ok) return;
                        await _api.deleteSentence(s.id);
                        await _refreshAll();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
