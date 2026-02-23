import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';

class AdminConsolePage extends StatefulWidget {
  const AdminConsolePage({super.key});

  @override
  State<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends State<AdminConsolePage> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  List<Chapter> _chapters = const [];
  List<Word> _words = const [];
  List<AppSentence> _sentences = const [];
  List<MediaAssetItem> _assets = const [];

  @override
  void initState() {
    super.initState();
    _refreshAll();
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
                      const InputDecoration(labelText: '카테고리 태그 (context_tag)'),
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
                      onChanged: (v) => category = v ?? 'word',
                      decoration: const InputDecoration(labelText: '카테고리'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: labelCtrl,
                      decoration: const InputDecoration(labelText: '라벨(선택)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: keyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'key_text(자동매핑용: 단어/문장 원문)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      value: chapterId,
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('챕터 연결 없음')),
                        ..._chapters.map(
                          (c) => DropdownMenuItem<int?>(
                            value: c.id,
                            child: Text('#${c.id} ${c.title}'),
                          ),
                        ),
                      ],
                      onChanged: (v) => chapterId = v,
                      decoration: const InputDecoration(labelText: '챕터 연결'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      value: wordId,
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('단어 연결 없음')),
                        ..._words.map(
                          (w) => DropdownMenuItem<int?>(
                            value: w.id,
                            child: Text('#${w.id} ${w.koreanWord}'),
                          ),
                        ),
                      ],
                      onChanged: (v) => wordId = v,
                      decoration: const InputDecoration(labelText: '단어 연결'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      value: sentenceId,
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('문장 연결 없음')),
                        ..._sentences.map(
                          (s) => DropdownMenuItem<int?>(
                            value: s.id,
                            child: Text('#${s.id} ${s.koreanSentence}'),
                          ),
                        ),
                      ],
                      onChanged: (v) => sentenceId = v,
                      decoration: const InputDecoration(labelText: '문장 연결'),
                    ),
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
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('시나브로 관리자'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '이미지'),
              Tab(text: '챕터'),
              Tab(text: '단어'),
              Tab(text: '문장'),
            ],
          ),
          actions: [
            IconButton(
                onPressed: _refreshAll,
                icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final tab = DefaultTabController.of(context).index;
            return FloatingActionButton.extended(
              onPressed: () {
                if (tab == 0) {
                  _openAssetDialog();
                } else if (tab == 1) {
                  _openChapterDialog();
                } else if (tab == 2) {
                  _openWordDialog();
                } else {
                  _openSentenceDialog();
                }
              },
              label: const Text('추가'),
              icon: const Icon(Icons.add),
            );
          },
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildAssetTab(),
                  _buildChapterTab(),
                  _buildWordTab(),
                  _buildSentenceTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildAssetTab() {
    if (_assets.isEmpty) return const Center(child: Text('이미지 자산이 없습니다.'));
    return ListView.separated(
      itemCount: _assets.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _assets[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              item.imageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 48,
                height: 48,
                color: Colors.grey.shade300,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          title: Text(
              '[${item.category}] ${item.label.isEmpty ? '(무라벨)' : item.label}'),
          subtitle: Text(
            'key=${item.keyText} / chapter=${item.chapterId ?? '-'} / word=${item.wordId ?? '-'} / sentence=${item.sentenceId ?? '-'}',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              await _api.deleteMediaAsset(item.id);
              await _refreshAll();
            },
          ),
        );
      },
    );
  }

  Widget _buildChapterTab() {
    if (_chapters.isEmpty) return const Center(child: Text('챕터가 없습니다.'));
    return ListView.separated(
      itemCount: _chapters.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final c = _chapters[index];
        return ListTile(
          title: Text('#${c.id} ${c.title}'),
          subtitle: Text('difficulty=${c.difficulty}, context=${c.contextTag}'),
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
                  await _api.deleteChapter(c.id);
                  await _refreshAll();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWordTab() {
    if (_words.isEmpty) return const Center(child: Text('단어가 없습니다.'));
    return ListView.separated(
      itemCount: _words.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final w = _words[index];
        return ListTile(
          title: Text('#${w.id} ${w.koreanWord}'),
          subtitle: Text('북한어: ${w.northKoreanWord} / chapter=${w.chapterId}'),
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
                  await _api.deleteWord(w.id);
                  await _refreshAll();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSentenceTab() {
    if (_sentences.isEmpty) return const Center(child: Text('문장이 없습니다.'));
    return ListView.separated(
      itemCount: _sentences.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final s = _sentences[index];
        return ListTile(
          title: Text('#${s.id} ${s.koreanSentence}'),
          subtitle:
              Text('북한식: ${s.northKoreanSentence} / chapter=${s.chapterId}'),
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
                  await _api.deleteSentence(s.id);
                  await _refreshAll();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
