import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/admob_config.dart';
import '../models/verse.dart';
import '../models/note.dart';
import '../services/bible_service.dart';
import '../services/note_service.dart';
import 'note_editor.dart';
import 'notes_list_screen.dart';

class BibleReader extends StatefulWidget {
  const BibleReader({super.key});

  @override
  State<BibleReader> createState() => _BibleReaderState();
}

class _BibleReaderState extends State<BibleReader> {
  static const String _lastBookKey = 'last_read_book';
  static const String _lastOffsetKey = 'last_read_offset';
  static const String _hideStartupInfoKey = 'hide_startup_info';

  final BibleService _bibleService = BibleService();
  final NoteService _noteService = NoteService.instance;
  late Future<List<Verse>> _bibleFuture;
  List<String> _books = [];
  String? _selectedBook;
  int? _selectedChapter;
  List<Verse> _currentBookVerses = [];
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _chapterHeaderKeys = {};
  final Map<String, GlobalKey> _verseKeys = {};
  Timer? _savePositionTimer;
  Timer? _tipTimer;
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  bool _showLongPressTip = false;
  Map<String, dynamic> _strongsDictionary = {};
  bool _isStrongsDictionaryLoaded = false;
  bool _isLoadingStrongsDictionary = false;
  String? _restoredBook;
  double _restoredOffset = 0;
  double _textScale = 1.0;

  void _loadBannerAd() {
    final adUnitId = AdMobConfig.bannerAdUnitId;
    if (adUnitId.isEmpty) return;

    final banner = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _bannerAd = ad as BannerAd;
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );

    banner.load();
  }

  void _setTipVisibilityFromNotes() {
    final hasAnyNotes = _noteService.getAllNotes().isNotEmpty;
    if (hasAnyNotes) {
      _tipTimer?.cancel();
      if (_showLongPressTip && mounted) {
        setState(() {
          _showLongPressTip = false;
        });
      }
      return;
    }

    if (!_showLongPressTip && mounted) {
      setState(() {
        _showLongPressTip = true;
      });
    }

    _tipTimer?.cancel();
    _tipTimer = Timer(const Duration(seconds: 7), () {
      if (!mounted) return;
      setState(() {
        _showLongPressTip = false;
      });
    });
  }

  GlobalKey _chapterKey(int chapter) {
    return _chapterHeaderKeys.putIfAbsent(chapter, () => GlobalKey());
  }

  GlobalKey _verseKey(int chapter, int verse) {
    return _verseKeys.putIfAbsent('$chapter:$verse', () => GlobalKey());
  }

  Future<void> _loadStrongsDictionary() async {
    if (_isStrongsDictionaryLoaded || _isLoadingStrongsDictionary) return;

    _isLoadingStrongsDictionary = true;
    try {
      final jsText = await rootBundle.loadString(
        'assets/strongs-greek-dictionary.js',
      );
      final firstBrace = jsText.indexOf('{');
      final lastBrace = jsText.lastIndexOf('}');
      if (firstBrace == -1 || lastBrace == -1 || firstBrace >= lastBrace) {
        return;
      }

      final jsonObject = jsText.substring(firstBrace, lastBrace + 1);
      final parsed = json.decode(jsonObject) as Map<String, dynamic>;
      _strongsDictionary = parsed;
      _isStrongsDictionaryLoaded = true;
    } catch (_) {
      _strongsDictionary = {};
      _isStrongsDictionaryLoaded = false;
    } finally {
      _isLoadingStrongsDictionary = false;
    }
  }

  Future<void> _showStartupInfoIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final hideInfo = prefs.getBool(_hideStartupInfoKey) ?? false;
    if (hideInfo || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      bool doNotShowAgain = false;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Welcome'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This app shows New Testament text with Greek Strong\'s support.',
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Words added by the translators (not in the Greek original) are shown in italics.',
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tap any normal word to view its Greek Strong\'s dictionary entry when available.',
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: doNotShowAgain,
                      onChanged: (value) {
                        setDialogState(() {
                          doNotShowAgain = value ?? false;
                        });
                      },
                      title: const Text('Do not show again'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      if (doNotShowAgain) {
                        await prefs.setBool(_hideStartupInfoKey, true);
                      }
                      if (mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                    child: const Text('Continue'),
                  ),
                ],
              );
            },
          );
        },
      );
    });
  }

  Future<void> _showStrongsEntry(Word word) async {
    if (word.s.isEmpty) return;
    final code = word.s.first;

    if (!_isStrongsDictionaryLoaded) {
      await _loadStrongsDictionary();
    }

    if (!mounted) return;

    final entry = _strongsDictionary[code];
    final entryMap = entry is Map<String, dynamic> ? entry : null;

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${word.w} ($code)'),
          content: SingleChildScrollView(
            child: entryMap == null
                ? Text('No Greek dictionary entry found for $code.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _dictionaryLine('Lemma', entryMap['lemma']),
                      _dictionaryLine('Translit', entryMap['translit']),
                      _dictionaryLine('Strong\'s Def', entryMap['strongs_def']),
                      _dictionaryLine('KJV Def', entryMap['kjv_def']),
                      _dictionaryLine('Derivation', entryMap['derivation']),
                    ].whereType<Widget>().toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget? _dictionaryLine(String label, dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, height: 1.35),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }

  Widget _buildVerseText(Verse verse, TextStyle baseStyle, TextStyle refStyle) {
    final children = <Widget>[
      Text(
        '${verse.chapter}:${verse.verse} ',
        style: refStyle,
      ),
    ];

    for (final word in verse.words) {
      final text = word.p != null ? '${word.w}${word.p} ' : '${word.w} ';
      final style = word.a
          ? baseStyle.copyWith(fontStyle: FontStyle.italic)
          : baseStyle;

      if (word.a || word.s.isEmpty) {
        children.add(Text(text, style: style));
      } else {
        children.add(
          GestureDetector(
            onTap: () => _showStrongsEntry(word),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Text(text, style: style),
            ),
          ),
        );
      }
    }

    if (_noteService.hasNote(verse.bookName, verse.chapter, verse.verse)) {
      children.add(
        const Text(
          '*',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _loadStrongsDictionary();
    _showStartupInfoIfNeeded();
    _scrollController.addListener(_onScrollChanged);
    _noteService.loadNotes().then((_) {
      if (!mounted) return;
      setState(() {});
      _setTipVisibilityFromNotes();
    });
    _bibleFuture = _restoreReadingPosition().then((_) {
      return _bibleService.loadBible();
    }).then((verses) {
      _books = _bibleService.getUniqueBooks();
      if (_selectedBook == null && _books.isNotEmpty) {
        _selectedBook =
            (_restoredBook != null && _books.contains(_restoredBook))
            ? _restoredBook
            : _books.first;
        _loadBook(_selectedBook!);
        if (_restoredOffset > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scrollController.hasClients) {
              _scrollController.jumpTo(
                _restoredOffset.clamp(
                  0,
                  _scrollController.position.maxScrollExtent,
                ),
              );
            }
          });
        }
      }
      return verses;
    });
  }

  Future<void> _restoreReadingPosition() async {
    final prefs = await SharedPreferences.getInstance();
    _restoredBook = prefs.getString(_lastBookKey);
    _restoredOffset = prefs.getDouble(_lastOffsetKey) ?? 0;
  }

  void _onScrollChanged() {
    _savePositionTimer?.cancel();
    _savePositionTimer = Timer(const Duration(milliseconds: 400), () {
      _saveReadingPosition();
    });
  }

  Future<void> _saveReadingPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedBook = _selectedBook;
    if (selectedBook != null && selectedBook.isNotEmpty) {
      await prefs.setString(_lastBookKey, selectedBook);
    }
    if (_scrollController.hasClients) {
      await prefs.setDouble(_lastOffsetKey, _scrollController.offset);
    }
  }

  void _loadBook(String book) {
    setState(() {
      _selectedBook = book;
      _chapterHeaderKeys.clear();
      _verseKeys.clear();
      _currentBookVerses = _bibleService
          .getAllVerses()
          .where((v) => v.bookName == book)
          .toList();
      final chapters = _bibleService.getChaptersForBook(book);
      _selectedChapter = chapters.isNotEmpty ? chapters.first : null;
    });
  }

  void _jumpToChapter(int chapter) {
    final key = _chapterKey(chapter);
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _jumpToVerse(String bookName, int chapter, int verse) {
    if (_selectedBook != bookName) {
      _loadBook(bookName);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animateToVerse(chapter, verse);
      });
      return;
    }
    _animateToVerse(chapter, verse);
  }

  void _animateToVerse(int chapter, int verse) {
    final key = _verseKey(chapter, verse);
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showNoteEditor(Verse verse) async {
    final existingNote = await _noteService.getNote(
      verse.bookName,
      verse.chapter,
      verse.verse,
    );

    if (mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NoteEditor(
            bookName: verse.bookName,
            chapter: verse.chapter,
            verse: verse.verse,
            verseText: verse.plainText,
            existingNote: existingNote,
          ),
          fullscreenDialog: true,
        ),
      );

      if (result == true && mounted) {
        setState(() {});
        _setTipVisibilityFromNotes();
      }
    }
  }

  void _toggleTextSize() {
    setState(() {
      if (_textScale < 1.1) {
        _textScale = 1.2;
      } else if (_textScale < 1.25) {
        _textScale = 1.35;
      } else {
        _textScale = 1.0;
      }
    });
  }

  Future<void> _openNotes() async {
    final selectedNote = await Navigator.push<Note>(
      context,
      MaterialPageRoute(builder: (_) => const NotesListScreen()),
    );

    if (selectedNote != null && mounted) {
      _jumpToVerse(
        selectedNote.bookName,
        selectedNote.chapter,
        selectedNote.verse,
      );
    }
  }

  void _showSearchPane() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFF9DB),
      builder: (context) {
        final allVerses = _bibleService.getAllVerses();
        String query = '';
        List<Verse> results = [];

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    color: const Color(0xFF2F6B33),
                    child: const Text(
                      'Search',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: 'Search verses',
                            hintText: 'Type any word or phrase',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              query = value.trim().toLowerCase();
                              if (query.isEmpty) {
                                results = [];
                              } else {
                                results = allVerses
                                    .where(
                                      (v) =>
                                          v.plainText.toLowerCase().contains(
                                            query,
                                          ),
                                    )
                                    .take(100)
                                    .toList();
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        if (query.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'Start typing to search the New Testament.',
                            ),
                          )
                        else if (results.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text('No verses found.'),
                          )
                        else
                          SizedBox(
                            height: 380,
                            child: ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (context, index) {
                                final verse = results[index];
                                return ListTile(
                                  title: Text(
                                    '${verse.bookName} ${verse.chapter}:${verse.verse}',
                                  ),
                                  subtitle: Text(
                                    verse.plainText,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _jumpToVerse(
                                      verse.bookName,
                                      verse.chapter,
                                      verse.verse,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showInfoPane() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFFF9DB),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: const Color(0xFF2F6B33),
                child: const Text(
                  'About This App',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'About App',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'This app is built for reading and verse-by-verse notation.',
                          style: TextStyle(
                            fontSize: 17,
                            height: 1.35,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Translation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'This app uses the New Testament KJV text with Greek Strong\'s '
                          'references in the source data. Helper words may appear in italics. '
                          'Tap a word to open its Greek Strong\'s definition and related details.',
                          style: TextStyle(
                            fontSize: 17,
                            height: 1.35,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Instructions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '- Long-press a verse to add or edit a note.\n'
                          '- Use Notes to browse all saved notes.\n'
                          '- Use Search to find words or phrases.\n'
                          '- Tap a word to view its Greek Strong\'s definition.\n'
                          '- Use Text to enlarge reading size.',
                          style: TextStyle(
                            fontSize: 17,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _topActionButton({
    required Widget child,
    required String tooltip,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF2F6B33),
              border: Border(
                right: showDivider
                    ? const BorderSide(color: Colors.white24, width: 1)
                    : BorderSide.none,
              ),
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _savePositionTimer?.cancel();
    _tipTimer?.cancel();
    _saveReadingPosition();
    _bannerAd?.dispose();
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Verse>>(
      future: _bibleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('New Testament Reader')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('New Testament Reader')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('New Testament Reader')),
            body: const Center(child: Text('No verses found')),
          );
        }

        final chapters = _selectedBook == null
            ? <int>[]
            : _bibleService.getChaptersForBook(_selectedBook!);

        return Scaffold(
          body: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    _topActionButton(
                      tooltip: 'Notes',
                      onTap: _openNotes,
                      child: const Icon(
                        Icons.sticky_note_2_outlined,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    _topActionButton(
                      tooltip: 'Search',
                      onTap: _showSearchPane,
                      child: const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    _topActionButton(
                      tooltip: 'Text size',
                      onTap: _toggleTextSize,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'A',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'A',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 30,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _topActionButton(
                      tooltip: 'Info',
                      onTap: _showInfoPane,
                      showDivider: false,
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ],
                ),
              ),
              // Book Selection
              Container(
                color: const Color(0xFFFFF9DB),
                height: 56,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedBook,
                          dropdownColor: const Color(0xFFFFF9DB),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          items: _books
                              .map(
                                (book) => DropdownMenuItem(
                                  value: book,
                                  child: Text(
                                    book,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (book) {
                            if (book != null) {
                              _loadBook(book);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                final firstChapter = _selectedChapter;
                                if (firstChapter != null) {
                                  _jumpToChapter(firstChapter);
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _selectedChapter,
                          dropdownColor: const Color(0xFFFFF9DB),
                          hint: const Text(
                            'Chapter',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          items: chapters
                              .map(
                                (chapter) => DropdownMenuItem<int>(
                                  value: chapter,
                                  child: Text(
                                    'Chapter $chapter',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (chapter) {
                            if (chapter == null) return;
                            setState(() {
                              _selectedChapter = chapter;
                            });
                            _jumpToChapter(chapter);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Bible Text - Continuous scroll
              if (_showLongPressTip)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Colors.blue.withValues(alpha: 0.05),
                  child: Text(
                    'Tip: Long-press a verse to add or edit a note.',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              Expanded(
                child: _currentBookVerses.isEmpty
                    ? const Center(child: Text('No verses found'))
                    : ListView.builder(
                        controller: _scrollController,
                        cacheExtent: 999999,
                        padding: const EdgeInsets.all(16),
                        itemCount: _currentBookVerses.length,
                        itemBuilder: (context, index) {
                          final verse = _currentBookVerses[index];
                          final prevVerse = index > 0
                              ? _currentBookVerses[index - 1]
                              : null;
                          final isNewChapter =
                              prevVerse == null ||
                              prevVerse.chapter != verse.chapter;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Chapter Header
                              if (isNewChapter) ...[
                                Container(
                                  key: _chapterKey(verse.chapter),
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      top: 16,
                                      bottom: 0,
                                    ),
                                    child: Text(
                                      'Chapter ${verse.chapter}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[700],
                                            fontSize:
                                                (Theme.of(context)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.fontSize ??
                                                    16) *
                                                _textScale,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                              // Verse
                              GestureDetector(
                                key: _verseKey(verse.chapter, verse.verse),
                                onLongPress: () => _showNoteEditor(verse),
                                child: Padding(
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color:
                                          _noteService.hasNote(
                                            verse.bookName,
                                            verse.chapter,
                                            verse.verse,
                                          )
                                          ? Colors.yellow[50]
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(4),
                                      border:
                                          _noteService.hasNote(
                                            verse.bookName,
                                            verse.chapter,
                                            verse.verse,
                                          )
                                          ? Border.all(
                                              color: Colors.yellow[200]!,
                                              width: 1,
                                            )
                                          : null,
                                    ),
                                    padding:
                                        _noteService.hasNote(
                                          verse.bookName,
                                          verse.chapter,
                                          verse.verse,
                                        )
                                        ? const EdgeInsets.all(8)
                                        : EdgeInsets.zero,
                                    child: _buildVerseText(
                                      verse,
                                      TextStyle(
                                        color: Colors.black,
                                        fontSize:
                                            ((Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.fontSize ??
                                                16) *
                                            _textScale),
                                      ),
                                      TextStyle(
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.bold,
                                        fontSize:
                                            ((Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.fontSize ??
                                                16) *
                                            _textScale),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              if (_isBannerAdReady && _bannerAd != null)
                SafeArea(
                  top: false,
                  child: SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}


