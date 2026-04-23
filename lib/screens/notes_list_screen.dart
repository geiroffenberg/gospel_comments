import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/note_service.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  final NoteService _noteService = NoteService.instance;
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _noteService.loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9DB),
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              color: const Color(0xFF2F6B33),
              height: 74,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Verse Notes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<void>(
              future: _loadFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notes = _noteService.getAllNotes();
                if (notes.isEmpty) {
                  return const Center(
                    child: Text('No notes yet. Long-press a verse to add one.'),
                  );
                }

                return ListView.separated(
                  itemCount: notes.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return ListTile(
                      tileColor: const Color(0xFFFFF9DB),
                      title: Text('${note.bookName} ${note.chapter}:${note.verse}'),
                      subtitle: Text(
                        note.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        _formatDate(note.updatedAt),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      onTap: () => Navigator.pop<Note>(context, note),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year.$month.$day';
  }
}
