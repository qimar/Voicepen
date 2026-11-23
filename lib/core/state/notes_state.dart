import '../services/cloud_sync_service.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note_model.dart';
import '../mock/mock_notes.dart';
import '../database/notes_database.dart';
import '../services/preferences_service.dart';

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  throw UnimplementedError('Must override in main with initialized instance');
});

final notesDatabaseProvider = Provider<NotesDatabase>((ref) {
  return NotesDatabase();
});

final initialNotesProvider = Provider<List<NoteModel>>((ref) {
  return List.from(MockNotes.sampleNotes);
});

class NotesState {
  final List<NoteModel> notes;
  final String searchQuery;
  final String selectedTag;
  final bool isProUser;
  final String byokApiKey;
  final String customTonePrompt;
  final bool isAudioCloudBackupEnabled;

  const NotesState({
    required this.notes,
    this.searchQuery = '',
    this.selectedTag = 'All',
    this.isProUser = false,
    this.byokApiKey = '',
    this.customTonePrompt = '',
    this.isAudioCloudBackupEnabled = false,
  });

  List<NoteModel> get filteredNotes {
    return notes.where((note) {
      final matchesQuery = searchQuery.isEmpty ||
          note.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          note.cleanedContent.toLowerCase().contains(searchQuery.toLowerCase()) ||
          note.verbatimTranscript.toLowerCase().contains(searchQuery.toLowerCase());

      final matchesTag = selectedTag == 'All' || note.tags.contains(selectedTag);

      return matchesQuery && matchesTag;
    }).toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  List<String> get availableTags {
    final tagSet = <String>{};
    for (final note in notes) {
      for (final t in note.tags) {
        final trimmed = t.trim();
        if (trimmed.isNotEmpty) {
          tagSet.add(trimmed);
        }
      }
    }
    final sortedTags = tagSet.toList()..sort();
    return ['All', ...sortedTags];
  }

  NotesState copyWith({
    List<NoteModel>? notes,
    String? searchQuery,
    String? selectedTag,
    bool? isProUser,
    String? byokApiKey,
    String? customTonePrompt,
    bool? isAudioCloudBackupEnabled,
  }) {
    return NotesState(
      notes: notes ?? this.notes,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTag: selectedTag ?? this.selectedTag,
      isProUser: isProUser ?? this.isProUser,
      byokApiKey: byokApiKey ?? this.byokApiKey,
      customTonePrompt: customTonePrompt ?? this.customTonePrompt,
      isAudioCloudBackupEnabled: isAudioCloudBackupEnabled ?? this.isAudioCloudBackupEnabled,
    );
  }
}

class NotesNotifier extends Notifier<NotesState> {
  late final NotesDatabase _db;
  late final PreferencesService _prefs;
  late final CloudSyncService _cloudSync;

  @override
  NotesState build() {
    _db = ref.watch(notesDatabaseProvider);
    _prefs = ref.watch(preferencesServiceProvider);
    _cloudSync = ref.watch(cloudSyncServiceProvider);
    final initialNotes = ref.watch(initialNotesProvider);

    return NotesState(
      notes: initialNotes,
      isProUser: _prefs.isProUser(),
      byokApiKey: _prefs.getByokApiKey(),
      customTonePrompt: _prefs.getCustomTonePrompt(),
      isAudioCloudBackupEnabled: _prefs.isAudioCloudBackupEnabled(),
    );
  }

  Future<void> reloadFromDatabase() async {
    final notes = await _db.getAllNotes();
    state = state.copyWith(notes: notes);
  }

  /// Triggers full bidirectional sync with Supabase Cloud.
  Future<void> syncWithCloud() async {
    await _cloudSync.syncAll(db: _db, notifier: this);
  }

  Future<void> addNote(NoteModel note) async {
    state = state.copyWith(notes: [note, ...state.notes]);
    await _db.insertNote(note);
    // Background cloud sync
    _cloudSync.syncNoteUp(note);
  }

  Future<void> updateNote(NoteModel note) async {
    state = state.copyWith(
      notes: state.notes.map((n) => n.id == note.id ? note : n).toList(),
    );
    await _db.updateNote(note);
    // Background cloud sync
    _cloudSync.syncNoteUp(note);
  }

  Future<void> deleteNote(String id) async {
    final noteToDelete = state.notes.where((n) => n.id == id).firstOrNull;
    if (noteToDelete != null && noteToDelete.audioPath.isNotEmpty) {
      try {
        final audioFile = File(noteToDelete.audioPath);
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      } catch (_) {}
    }
    state = state.copyWith(
      notes: state.notes.where((n) => n.id != id).toList(),
    );
    await _db.deleteNote(id);
    // Background cloud sync
    _cloudSync.syncNoteDelete(id);
  }

  Future<void> togglePin(String id) async {
    bool? newPinStatus;
    state = state.copyWith(
      notes: state.notes.map((n) {
        if (n.id == id) {
          newPinStatus = !n.isPinned;
          return n.copyWith(isPinned: newPinStatus);
        }
        return n;
      }).toList(),
    );
    if (newPinStatus != null) {
      await _db.updatePinStatus(id, newPinStatus!);
      final updatedNote = state.notes.where((n) => n.id == id).firstOrNull;
      if (updatedNote != null) {
        _cloudSync.syncNoteUp(updatedNote);
      }
    }
  }

  Future<void> updateTitle(String id, String newTitle) async {
    state = state.copyWith(
      notes: state.notes.map((n) {
        if (n.id == id) {
          return n.copyWith(title: newTitle);
        }
        return n;
      }).toList(),
    );
    await _db.updateTitle(id, newTitle);
    final updatedNote = state.notes.where((n) => n.id == id).firstOrNull;
    if (updatedNote != null) {
      _cloudSync.syncNoteUp(updatedNote);
    }
  }

  Future<void> updateNoteTone(String id, String newTone) async {
    state = state.copyWith(
      notes: state.notes.map((n) {
        if (n.id == id) {
          return n.copyWith(tone: newTone);
        }
        return n;
      }).toList(),
    );
    await _db.updateTone(id, newTone);
    final updatedNote = state.notes.where((n) => n.id == id).firstOrNull;
    if (updatedNote != null) {
      _cloudSync.syncNoteUp(updatedNote);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSelectedTag(String tag) {
    state = state.copyWith(selectedTag: tag);
  }

  Future<void> setProUser(bool isPro) async {
    state = state.copyWith(isProUser: isPro);
    await _prefs.setProUser(isPro);
  }

  Future<void> setByokApiKey(String key) async {
    state = state.copyWith(byokApiKey: key);
    await _prefs.setByokApiKey(key);
  }

  Future<void> setCustomTonePrompt(String prompt) async {
    state = state.copyWith(customTonePrompt: prompt);
    await _prefs.setCustomTonePrompt(prompt);
  }

  Future<void> setAudioCloudBackupEnabled(bool enabled) async {
    state = state.copyWith(isAudioCloudBackupEnabled: enabled);
    await _prefs.setAudioCloudBackupEnabled(enabled);
  }

  Future<void> clearAllNotes() async {
    state = state.copyWith(notes: []);
    await _db.clearAllNotes();
  }

  Future<void> resetMockNotes() async {
    state = state.copyWith(notes: List.from(MockNotes.sampleNotes));
    await _db.resetMockNotes();
  }
}

final notesProvider = NotifierProvider<NotesNotifier, NotesState>(NotesNotifier.new);
