class Note {
  final String bookName;
  final int chapter;
  final int verse;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  String get key => '${bookName}_${chapter}_$verse';

  Map<String, dynamic> toJson() => {
    'bookName': bookName,
    'chapter': chapter,
    'verse': verse,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Note.fromJson(Map<String, dynamic> json) {
    final bookName = json['bookName'] as String;
    final chapter = json['chapter'] as int;
    final verse = json['verse'] as int;
    final text = json['text'] as String? ?? '';
    final createdAt = json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now();
    final updatedAt = json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'] as String)
        : createdAt;

    return Note(
      bookName: bookName,
      chapter: chapter,
      verse: verse,
      text: text,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Note copyWith({String? text, DateTime? updatedAt}) {
    return Note(
      bookName: bookName,
      chapter: chapter,
      verse: verse,
      text: text ?? this.text,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
