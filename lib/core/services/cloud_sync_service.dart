import 'google_drive_backup_service.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/note_model.dart';
import '../database/notes_database.dart';
import '../state/notes_state.dart';

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, bool>(SyncStatusNotifier.new);

class SyncStatusNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setSyncing(bool syncing) => state = syncing;
}

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  return CloudSyncService(ref);
});

/// Handles bidirectional cloud synchronization between SQLite and Supabase.
/// Implements Last-Write-Wins (LWW) conflict resolution and soft-delete tombstones.
class CloudSyncService {
  final Ref _ref;
  CloudSyncService(this._ref);

  bool get isSyncing => _ref.read(syncStatusProvider);

  /// Synchronizes a single note up to the cloud (insert or update).
  Future<void> syncNoteUp(NoteModel note) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final user = Supabase.instance.client.auth.currentUser;
      if (session == null || user == null) {
        return; // User is not logged in; local SQLite remains source of truth
      }

      debugPrint('[CloudSyncService] Syncing note ${note.id} up to cloud...');
      String storagePath = note.audioPath;
      if (_ref.read(notesProvider).isAudioCloudBackupEnabled && note.audioPath.isNotEmpty) {
        final driveService = _ref.read(googleDriveBackupServiceProvider);
        if (driveService.isSignedIn) {
          final driveFileId = await driveService.uploadAudioFile(
            localPath: note.audioPath,
            noteTitle: note.title,
            noteId: note.id,
          );
          if (driveFileId != null) {
            storagePath = 'gdrive:$driveFileId';
          }
        }
      }

      final payload = {
        'id': note.id,
        'user_id': user.id,
        'title': note.title,
        'content': note.cleanedContent,
        'raw_transcript': note.verbatimTranscript,
        'timestamps_json': jsonEncode(note.timestamps.map((t) => t.toMap()).toList()),
        'audio_storage_path': storagePath,
        'tags': note.tags,
        'category': note.tone,
        'duration_seconds': note.durationSeconds,
        'is_pinned': note.isPinned,
        'is_deleted': false,
        'client_created_at': note.createdAt.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await Supabase.instance.client.from('notes').upsert(payload);
      debugPrint('[CloudSyncService] Note ${note.id} synced up successfully.');
    } catch (e) {
      debugPrint('[CloudSyncService] Error syncing note up: $e');
    }
  }

  /// Soft-deletes a note in the cloud by setting tombstone (is_deleted = true).
  Future<void> syncNoteDelete(String noteId) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final user = Supabase.instance.client.auth.currentUser;
      if (session == null || user == null) return;

      debugPrint('[CloudSyncService] Tombstoning note $noteId in cloud...');
      await Supabase.instance.client
          .from('notes')
          .update({
            'is_deleted': true,
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', noteId)
          .eq('user_id', user.id);
      debugPrint('[CloudSyncService] Note $noteId tombstoned in cloud.');
    } catch (e) {
      debugPrint('[CloudSyncService] Error tombstoning note: $e');
    }
  }

  /// Performs full bidirectional sync between local SQLite and Supabase.
  Future<void> syncAll({
    required NotesDatabase db,
    required NotesNotifier notifier,
  }) async {
    if (isSyncing) return;
    final session = Supabase.instance.client.auth.currentSession;
    final user = Supabase.instance.client.auth.currentUser;
    if (session == null || user == null) return;

    _ref.read(syncStatusProvider.notifier).setSyncing(true);
    try {
      debugPrint('[CloudSyncService] Starting full bidirectional sync for user ${user.id}...');

      // 1. Fetch remote notes
      final response = await Supabase.instance.client
          .from('notes')
          .select()
          .eq('user_id', user.id);

      final remoteRows = List<Map<String, dynamic>>.from(response);

      // 2. Fetch local notes
      final localNotes = await db.getAllNotes();
      final localMap = {for (final n in localNotes) n.id: n};
      final processedRemoteIds = <String>{};

      // 3. Process remote rows
      for (final row in remoteRows) {
        final remoteId = row['id']?.toString() ?? '';
        if (remoteId.isEmpty) continue;
        processedRemoteIds.add(remoteId);

        final isDeleted = (row['is_deleted'] as bool?) ?? false;

        if (isDeleted) {
          // If deleted remotely, remove from local SQLite
          if (localMap.containsKey(remoteId)) {
            await db.deleteNote(remoteId);
          }
          continue;
        }

        // Parse timestamps
        List<TimestampItem> parsedTimestamps = [];
        if (row['timestamps_json'] != null) {
          try {
            final decoded = jsonDecode(row['timestamps_json'].toString()) as List<dynamic>;
            parsedTimestamps = decoded
                .map((item) => TimestampItem.fromMap(item as Map<String, dynamic>))
                .toList();
          } catch (_) {}
        }

        // Parse tags
        List<String> parsedTags = [];
        if (row['tags'] is List) {
          parsedTags = (row['tags'] as List).map((t) => t.toString()).toList();
        } else if (row['tags'] is String && (row['tags'] as String).isNotEmpty) {
          parsedTags = (row['tags'] as String).split(',').map((t) => t.trim()).toList();
        }

        final remoteUpdatedAt = DateTime.tryParse(row['updated_at']?.toString() ?? '') ?? DateTime.now();
        final remoteCreatedAt = DateTime.tryParse(row['client_created_at']?.toString() ?? '') ?? remoteUpdatedAt;

        final remoteNote = NoteModel(
          id: remoteId,
          title: (row['title'] as String?)?.isNotEmpty == true ? row['title'] as String : 'Untitled Memo',
          cleanedContent: (row['content'] as String?) ?? '',
          verbatimTranscript: (row['raw_transcript'] as String?) ?? '',
          timestamps: parsedTimestamps,
          audioPath: (row['audio_storage_path'] as String?) ?? '',
          durationSeconds: (row['duration_seconds'] as int?) ?? 0,
          tone: (row['category'] as String?) ?? 'Clear & Simple',
          intensity: 'Medium',
          tags: parsedTags,
          isPending: false,
          isPinned: (row['is_pinned'] as bool?) ?? false,
          createdAt: remoteCreatedAt,
        );

        if (!localMap.containsKey(remoteId)) {
          // Remote note doesn't exist locally: pull into SQLite
          await db.insertNote(remoteNote);
        } else {
          // Remote note exists locally: Last-Write-Wins comparison
          final localNote = localMap[remoteId]!;
          if (remoteUpdatedAt.isAfter(localNote.createdAt)) {
            await db.updateNote(remoteNote);
          } else {
            // Local is newer: push local note up
            await syncNoteUp(localNote);
          }
        }
      }

      // 4. For local notes that haven't been pushed to cloud yet
      for (final local in localNotes) {
        if (!processedRemoteIds.contains(local.id)) {
          await syncNoteUp(local);
        }
      }

      // 5. Reload Riverpod state from updated SQLite database
      await notifier.reloadFromDatabase();
      debugPrint('[CloudSyncService] Full sync completed successfully.');
    } catch (e) {
      debugPrint('[CloudSyncService] Sync error: $e');
    } finally {
      _ref.read(syncStatusProvider.notifier).setSyncing(false);
    }
  }
}
