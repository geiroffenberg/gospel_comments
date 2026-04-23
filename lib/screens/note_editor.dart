import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/note_service.dart';

class NoteEditor extends StatefulWidget {
  final String bookName;
  final int chapter;
  final int verse;
  final String verseText;
  final Note? existingNote;

  const NoteEditor({
    super.key,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.verseText,
    this.existingNote,
  });

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  final NoteService _noteService = NoteService.instance;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    final existingText = widget.existingNote?.text.trim() ?? '';
    final header = _dateSignature;
    final initialText = existingText.isEmpty
        ? header
        : existingText.endsWith(header.trim())
            ? existingText
            : '$existingText\n\n$header';

    _controller = TextEditingController(text: initialText);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _saveNote() async {
    if (_controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note cannot be empty')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await _noteService.saveNote(
      widget.bookName,
      widget.chapter,
      widget.verse,
      _controller.text.trim(),
    );

    if (mounted) {
      navigator.pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Note saved')),
      );
    }
  }

  void _deleteNote() async {
    if (widget.existingNote == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This will delete the note for this verse.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              await _noteService.deleteNote(
                widget.bookName,
                widget.chapter,
                widget.verse,
              );
              if (mounted) {
                navigator.pop();
                navigator.pop(true);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Note deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String get _dateSignature {
    final date = DateTime.now();
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year.$month.$day: ';
  }

  @override
  Widget build(BuildContext context) {
    final existingNote = widget.existingNote;
    final lastEdited = existingNote?.updatedAt;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9DB),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue[700],
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.bookName} ${widget.chapter}:${widget.verse}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.verseText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  if (lastEdited != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Last edited: ${_formatDate(lastEdited)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existingNote == null ? 'Add note:' : 'Edit note:',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Write your note here...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFFFFDF0),
                        ),
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9DB),
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (existingNote != null)
                    TextButton.icon(
                      onPressed: _deleteNote,
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveNote,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
