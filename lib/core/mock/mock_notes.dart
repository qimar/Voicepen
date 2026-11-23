import '../models/note_model.dart';

abstract class MockNotes {
  static final List<NoteModel> sampleNotes = [
    NoteModel(
      id: 'note_1',
      title: 'Product Strategy: The Offline Voice Advantage',
      tone: 'Executive Memo',
      intensity: 'Medium',
      durationSeconds: 134,
      isPinned: true,
      tags: ['Work', 'Ideas'],
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      audioPath: '',
      timestamps: const [
        TimestampItem(
          timeSeconds: 0,
          text:
              "We need to fundamentally reconsider how cloud voice utilities handle network intermittency. Most competitors abort audio ingest on elevator trips or subway rides, causing catastrophic memo loss.",
        ),
        TimestampItem(
          timeSeconds: 45,
          text:
              "The solution is a strict save-first architecture. The local disk sandbox must commit the AAC binary stream immediately before triggering remote inference.",
        ),
        TimestampItem(
          timeSeconds: 92,
          text:
              "Users also need paragraph-level jump timestamps so they can fact-check AI summaries against raw recordings in seconds.",
        ),
      ],
      verbatimTranscript:
          "We need to fundamentally reconsider how cloud voice utilities handle network intermittency. Most competitors abort audio ingest on elevator trips or subway rides, causing catastrophic memo loss.\n\nThe solution is a strict save-first architecture. The local disk sandbox must commit the AAC binary stream immediately before triggering remote inference.\n\nUsers also need paragraph-level jump timestamps so they can fact-check AI summaries against raw recordings in seconds.",
      cleanedContent: '''## Executive Summary

VoicePen solves the two most critical vulnerabilities in current voice dictation apps: **loss of audio during network dropouts** and **inability to fact-check generated notes**.

### Key Strategic Pillars

* **Local-First Audio Sandbox:** Every recording is persisted to device storage before any remote API connection is initialized.
* **Dual-Engine Fact Checking:** Polished editorial text is paired with verbatim audio timestamps for instant verification.
* **\$0 Operational Infrastructure:** Direct multimodal processing eliminates expensive transcription microservices.

### Immediate Action Items

1. Verify `.m4a` file locking on Android 14 foreground interruptions.
2. Standardize paragraph timestamp seeks within the embedded player.
3. Finalize Google AI Studio multimodal ingestion schemas.
''',
    ),
    NoteModel(
      id: 'note_2',
      title: 'Reflections on Creative Cadence & Deep Work',
      tone: 'Story / Journal',
      intensity: 'High',
      durationSeconds: 218,
      tags: ['Ideas'],
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      audioPath: '',
      timestamps: const [
        TimestampItem(
          timeSeconds: 0,
          text:
              "I went for an early morning walk through the park and noticed how much clearer my thoughts feel before looking at any email or social media notifications.",
        ),
        TimestampItem(
          timeSeconds: 78,
          text:
              "Talking out loud forces a rhythm that typing doesn't. When your hands aren't stuck on a keyboard, your brain connects disparate concepts more organically.",
        ),
      ],
      verbatimTranscript:
          "I went for an early morning walk through the park and noticed how much clearer my thoughts feel before looking at any email or social media notifications.\n\nTalking out loud forces a rhythm that typing doesn't. When your hands aren't stuck on a keyboard, your brain connects disparate concepts more organically.",
      cleanedContent: '''### Morning Reflections

The mind works differently when uncoupled from the physical restriction of a keyboard. When walking, thoughts flow without the self-censorship that often stalls writing on a blank screen.

* **Early Morning Solitude:** Guarding the first two hours of the day from notifications produces a disproportionate boost in deep creative clarity.
* **Pacing & Cadence:** Speaking ideas aloud surfaces natural transitions and emotional weight that sterile text editors obscure.
''',
    ),
    NoteModel(
      id: 'note_3',
      title: 'Q3 Android Release Checklist & Milestones',
      tone: 'Bullet Summary',
      intensity: 'Low',
      durationSeconds: 82,
      tags: ['Work', 'Meetings'],
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      audioPath: '',
      timestamps: const [
        TimestampItem(
          timeSeconds: 0,
          text:
              "Alright, quick rundown for the upcoming release: we need to test microphone permission fallbacks, verify local storage cleanup in Settings, and ensure the lifetime purchase dialog properly saves the Pro status.",
        ),
      ],
      verbatimTranscript:
          "Alright, quick rundown for the upcoming release: we need to test microphone permission fallbacks, verify local storage cleanup in Settings, and ensure the lifetime purchase dialog properly saves the Pro status.",
      cleanedContent: '''* **Microphone Permissions:** Validate custom alert dialog when permission is denied (`openAppSettings()` fallback).
* **Storage Manager:** Confirm "Clear Audio Cache" deletes `.m4a` files without altering SQLite text records.
* **Pro Unlock:** Ensure one-time lifetime pass persistence across app restarts.
* **Share Sheet:** Confirm Markdown and Plain Text clipboard copies are formatted cleanly.
''',
    ),
    NoteModel(
      id: 'note_offline',
      title: 'Offline Strategy Brainstorm',
      tone: 'Clear & Simple',
      intensity: 'Medium',
      durationSeconds: 134,
      isPending: true,
      tags: ['Work'],
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      audioPath: '',
      timestamps: const [],
      verbatimTranscript:
          "Audio recording is safely stored locally. Connect to the internet to generate your verbatim transcript and polished editorial note.",
      cleanedContent:
          "Your voice memo was captured while offline. Connect to the internet and tap **Retry AI Polish** to generate structured writing.",
    ),
  ];
}
