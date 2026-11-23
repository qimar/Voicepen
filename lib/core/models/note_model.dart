import 'dart:convert';

/// A paragraph-level timestamp entry for audio scrubbing Fact-Checking.
class TimestampItem {
  final int timeSeconds;
  final String text;

  const TimestampItem({
    required this.timeSeconds,
    required this.text,
  });

  String get formattedTime {
    final minutes = (timeSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (timeSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Map<String, dynamic> toMap() => {
        'time_seconds': timeSeconds,
        'text': text,
      };

  factory TimestampItem.fromMap(Map<String, dynamic> map) => TimestampItem(
        timeSeconds: map['time_seconds'] as int? ?? 0,
        text: map['text'] as String? ?? '',
      );
}

/// Core Note entity for VoicePen.
/// Hand-written serialization (zero build_runner / zero code-gen).
class NoteModel {
  final String id;
  final String title;
  final String cleanedContent;
  final String verbatimTranscript;
  final List<TimestampItem> timestamps;
  final String audioPath;
  final int durationSeconds;
  final String tone;
  final String intensity;
  final List<String> tags;
  final bool isPending;
  final bool isPinned;
  final DateTime createdAt;

  const NoteModel({
    required this.id,
    required this.title,
    required this.cleanedContent,
    required this.verbatimTranscript,
    required this.timestamps,
    required this.audioPath,
    required this.durationSeconds,
    required this.tone,
    required this.intensity,
    required this.tags,
    this.isPending = false,
    this.isPinned = false,
    required this.createdAt,
  });

  String get formattedDuration {
    final minutes = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  NoteModel copyWith({
    String? id,
    String? title,
    String? cleanedContent,
    String? verbatimTranscript,
    List<TimestampItem>? timestamps,
    String? audioPath,
    int? durationSeconds,
    String? tone,
    String? intensity,
    List<String>? tags,
    bool? isPending,
    bool? isPinned,
    DateTime? createdAt,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      cleanedContent: cleanedContent ?? this.cleanedContent,
      verbatimTranscript: verbatimTranscript ?? this.verbatimTranscript,
      timestamps: timestamps ?? this.timestamps,
      audioPath: audioPath ?? this.audioPath,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      tone: tone ?? this.tone,
      intensity: intensity ?? this.intensity,
      tags: tags ?? this.tags,
      isPending: isPending ?? this.isPending,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'cleaned_content': cleanedContent,
      'verbatim_transcript': verbatimTranscript,
      'timestamps_json': jsonEncode(timestamps.map((t) => t.toMap()).toList()),
      'audio_path': audioPath,
      'duration_seconds': durationSeconds,
      'tone': tone,
      'intensity': intensity,
      'tags': tags.join(','),
      'is_pending': isPending ? 1 : 0,
      'is_pinned': isPinned ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    List<TimestampItem> parsedTimestamps = [];
    if (map['timestamps_json'] != null) {
      try {
        final decoded = jsonDecode(map['timestamps_json'] as String) as List<dynamic>;
        parsedTimestamps = decoded
            .map((item) => TimestampItem.fromMap(item as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    final rawTags = map['tags'] as String? ?? '';
    final tagList = rawTags.isEmpty
        ? <String>[]
        : rawTags.split(',').map((t) => t.trim()).toList();

    return NoteModel(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Untitled Memo',
      cleanedContent: map['cleaned_content'] as String? ?? '',
      verbatimTranscript: map['verbatim_transcript'] as String? ?? '',
      timestamps: parsedTimestamps,
      audioPath: map['audio_path'] as String? ?? '',
      durationSeconds: map['duration_seconds'] as int? ?? 0,
      tone: map['tone'] as String? ?? 'Clear & Simple',
      intensity: map['intensity'] as String? ?? 'Medium',
      tags: tagList,
      isPending: (map['is_pending'] as int? ?? 0) == 1,
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
