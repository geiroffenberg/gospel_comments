import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/verse.dart';

class BibleService {
  static const String _assetPath = 'assets/web.json';
  List<Verse> _verses = [];
  bool _isLoaded = false;

  Future<List<Verse>> loadBible() async {
    if (_isLoaded) {
      return _verses;
    }

    try {
      final jsonString = await rootBundle.loadString(_assetPath);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      final versesList = jsonData['verses'] as List<dynamic>;

      _verses = versesList
          .map((v) => Verse.fromJson(v as Map<String, dynamic>))
          .toList();

      _isLoaded = true;
      return _verses;
    } catch (e) {
      throw Exception('Failed to load Bible: $e');
    }
  }

  List<Verse> getAllVerses() => _verses;

  List<String> getUniqueBooks() {
    final books = <String>{};
    for (final verse in _verses) {
      books.add(verse.bookName);
    }
    return books.toList();
  }

  List<int> getChaptersForBook(String bookName) {
    final chapters = <int>{};
    for (final verse in _verses) {
      if (verse.bookName == bookName) {
        chapters.add(verse.chapter);
      }
    }
    return chapters.toList()..sort();
  }

  List<Verse> getVersesForChapter(String bookName, int chapter) {
    return _verses
        .where((v) => v.bookName == bookName && v.chapter == chapter)
        .toList();
  }
}
