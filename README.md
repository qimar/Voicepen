<div align="center">

# VoicePen

### AI Voice Recording & Structured Note Taking Utility

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Google Gemini](https://img.shields.io/badge/AI-Google_Gemini-8E75C2?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev)
[![Riverpod](https://img.shields.io/badge/State-Riverpod-00599C?style=for-the-badge&logo=flutter&logoColor=white)](https://riverpod.dev)
[![SQLite](https://img.shields.io/badge/SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white)](https://sqlite.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

</div>

---

## Overview

VoicePen is a mobile productivity application that transforms unstructured voice recordings into organized, Markdown formatted notes, action items, and summaries. Powered by the Google Gemini API and built with Flutter and Riverpod, it provides real time waveform visualization, offline SQLite caching, and cloud sync integration.

---

## Key Features

* **High Fidelity Audio Recording:** Microphone capture with real time audio waveform visualization and scrubbing.
* **AI Transcription & Structuring:** Streams recorded audio data into Google Gemini to produce structured notes with summaries, key takeaways, and action checklists.
* **Interruption Resilient:** Robust audio session lifecycle management that preserves in progress recordings through incoming calls and lock screen transitions.
* **Offline SQLite Database:** Local storage for immediate note retrieval, category tagging, full text search, and Markdown rendering.
* **Cloud Sync Integration:** Supports cloud sync with daily quota management and Google Drive backup functionality.

---

## Tech Stack

| Component | Technology |
|---|---|
| **Framework** | Flutter 3.x (Android & Cross Platform) |
| **Language** | Dart |
| **AI Engine** | Google Generative AI (Gemini SDK) |
| **State Management** | Riverpod |
| **Audio Capture** | Record, Just Audio |
| **Local Database** | SQLite (sqflite) |
| **Cloud Services** | Google Drive Backup, Supabase Auth |

---

## Architecture

The project uses a feature-first folder organization:

```text
lib/
├── core/                  # Gemini client, audio session drivers, and database helper
└── features/
    ├── notes/             # Note list, note detail, Markdown viewer, and share sheets
    ├── record/            # Waveform painter, microphone stream, and AI overlay
    └── settings/          # AI model preferences, custom prompt rules, and sync
```

---

## Engineering Highlights

### Audio Stream Interruption Handling
Voice recording sessions on mobile are prone to sudden operating system interruptions (such as incoming cellular calls or alarm triggers). VoicePen wraps the microphone stream in an event listener that flushes buffer chunks to local storage before handling OS pauses, preventing audio corruption.

### Streaming AI Markdown Rendering
Gemini API responses stream text tokens asynchronously. VoicePen combines Riverpod state streams with Flutter Markdown widgets to render content progressively without UI freeze.

---

## Getting Started

### Prerequisites
* Flutter SDK (3.24+)
* Google Gemini API Key from Google AI Studio

### Installation

```bash
# Clone the repository
git clone https://github.com/qimar/voicepen.git

# Enter project directory
cd voicepen

# Install dependencies
flutter pub get

# Run on device
flutter run
```

---

## License

Distributed under the MIT License. See `LICENSE` for details.
