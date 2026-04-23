class Verse {
  final String bookName;
  final int book;
  final int chapter;
  final int verse;
  final String text;

  Verse({
    required this.bookName,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  factory Verse.fromJson(Map<String, dynamic> json) {
    return Verse(
      bookName: json['book_name'] as String,
      book: json['book'] as int,
      chapter: json['chapter'] as int,
      verse: json['verse'] as int,
      text: json['text'] as String,
    );
  }

  String get reference => '$bookName $chapter:$verse';
}
