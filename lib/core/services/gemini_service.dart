import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/note_model.dart';

/// Error types that can occur during AI processing.
enum GeminiErrorType {
  none,
  noApiKey,
  invalidApiKey,
  rateLimitExceeded,
  networkError,
  serverBusy,
  emptyAudio,
  unknown,
}

class GeminiServiceException {
  final GeminiErrorType type;
  final String userMessage;

  const GeminiServiceException({
    required this.type,
    required this.userMessage,
  });
}

/// Structured result returned by the AI processing pipeline.
class GeminiResult {
  final String title;
  final String cleanedContent;
  final String verbatimTranscript;
  final List<TimestampItem> timestamps;
  final List<String> tags;

  const GeminiResult({
    required this.title,
    required this.cleanedContent,
    required this.verbatimTranscript,
    required this.timestamps,
    required this.tags,
  });
}

/// Robust, direct Google Gemini REST API client.
///
/// Bypasses the Flutter SDK to avoid unhandled inlineData audio exceptions,
/// enforces strict validation, permissive safety thresholds, and direct JSON formatting.
class GeminiService {
  /// Holds details about the last failure, if any.
  GeminiServiceException? lastError;
  // Ordered by priority: high-performance, stable Flash models supporting audio multimodal inference
  static const List<String> _modelsToTry = [
    'gemini-3.5-flash',
    'gemini-3.6-flash',
    'gemini-2.5-flash-lite',
    'gemini-flash-lite-latest',
    'gemini-3.8-flash',
    'gemini-flash-latest',
  ];

  static const List<Map<String, String>> _safetySettings = [
    {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_ONLY_HIGH'},
    {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_ONLY_HIGH'},
    {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_ONLY_HIGH'},
    {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_ONLY_HIGH'},
  ];

  /// Resolves the audio MIME type for Gemini from a file path.
  static String getMimeTypeForPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp3':
        return 'audio/mp3';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
      default:
        return 'audio/mp4';
    }
  }

  /// Validates an API key against Google AI Studio.
  /// Supports both modern authorization keys ("AQ...") and legacy keys ("AIza...").
  /// Returns null if valid, or a descriptive error message if invalid.
  Future<String?> validateApiKey(String apiKey) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      return 'Please enter a valid API key.';
    }

    if (cleanKey.length < 25) {
      return 'API key is too short. Google AI Studio keys start with "AQ." (new) or "AIza" (legacy).';
    }

    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models',
      );
      final res = await http.get(
        uri,
        headers: {
          'x-goog-api-key': cleanKey,
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return null; // Key is valid and active!
      } else if (res.statusCode == 400 || res.statusCode == 401) {
        return 'Invalid API key (HTTP ${res.statusCode}). Please verify your key at aistudio.google.com.';
      } else if (res.statusCode == 403) {
        return 'Access denied (HTTP 403). Make sure the Generative Language API is enabled for this project.';
      } else if (res.statusCode == 429) {
        return 'Rate limit reached (HTTP 429). Please wait a moment before trying again.';
      } else {
        return 'Verification returned HTTP ${res.statusCode}. Check internet connectivity.';
      }
    } on SocketException {
      return 'Network connection failed. Please check your internet connection.';
    } catch (e) {
      return 'Connection timed out. Please check your internet connection.';
    }
  }

  /// Processes raw audio via Gemini multimodal inference into a structured note.
  Future<GeminiResult?> polishAudio({
    required String apiKey,
    required String audioPath,
    required String tone,
    required String intensity,
    String? customInstructions,
  }) async {
    lastError = null;
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      debugPrint('[GeminiService] Audio polish aborted: Empty API key.');
      lastError = const GeminiServiceException(
        type: GeminiErrorType.noApiKey,
        userMessage: 'Please add your Google AI Studio API key in Settings.',
      );
      return null;
    }

    final file = File(audioPath);
    if (!await file.exists()) {
      debugPrint('[GeminiService] Audio polish aborted: File does not exist at $audioPath');
      lastError = const GeminiServiceException(
        type: GeminiErrorType.emptyAudio,
        userMessage: 'Audio file not found on device.',
      );
      return null;
    }

    final audioBytes = await file.readAsBytes();
    if (audioBytes.isEmpty) {
      debugPrint('[GeminiService] Audio polish aborted: File is empty (0 bytes).');
      lastError = const GeminiServiceException(
        type: GeminiErrorType.emptyAudio,
        userMessage: 'Audio recording is empty (0 bytes). Please re-record.',
      );
      return null;
    }

    final mimeType = getMimeTypeForPath(audioPath);
    final audioBase64 = base64Encode(audioBytes);

    final customGuidance = (tone == 'Custom Tone' &&
            customInstructions != null &&
            customInstructions.trim().isNotEmpty)
        ? '\nSpecial Custom User Instructions:\n${customInstructions.trim()}\n'
        : '';

    final promptText = '''
You are VoicePen, an editorial AI assistant that transforms spoken voice memos into structured, elegant notes.
Tone: $tone
Intensity: $intensity
$customGuidance

Analyze the attached audio and return ONLY a valid JSON object matching this schema:
{
  "title": "Punchy editorial title (5-8 words max)",
  "cleaned_content": "Polished note in rich Markdown matching '$tone' tone. Must start with a '## Executive Summary' section summarizing the recording in 2-3 sentences, followed by '## Key Takeaways' and '## Action Items' (if applicable) with clean bullet points.",
  "verbatim_transcript": "Accurate, word-for-word transcript of everything spoken in the audio.",
  "tags": ["Tag1", "Tag2"],
  "timestamps": [
    { "time_seconds": 0, "text": "First key thought." }
  ]
}
Return ONLY valid JSON. No markdown code fences, no extra text.
''';

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': audioBase64,
              },
            },
            {'text': promptText},
          ],
        },
      ],
      'safetySettings': _safetySettings,
      'generationConfig': {
        'temperature': 0.3,
        'responseMimeType': 'application/json',
      },
    });

    for (final model in _modelsToTry) {
      try {
        final stopwatch = Stopwatch()..start();
        final endpoint =
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';

        debugPrint('[GeminiService] Sending audio (${audioBytes.length} bytes, $mimeType) to $model...');

        final response = await http
            .post(
              Uri.parse(endpoint),
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': cleanKey,
              },
              body: requestBody,
            )
            .timeout(const Duration(seconds: 40));

        stopwatch.stop();
        debugPrint(
            '[GeminiService] HTTP ${response.statusCode} from $model in ${stopwatch.elapsedMilliseconds}ms');

        if (response.statusCode == 200) {
          final result = _parseResponse(response.body, tone);
          if (result != null) {
            lastError = null;
            debugPrint('[GeminiService] ✓ Note polished successfully: "${result.title}"');
            return result;
          }
        } else if (response.statusCode == 400 ||
            response.statusCode == 401 ||
            response.statusCode == 403) {
          debugPrint('[GeminiService] Auth/Client error ${response.statusCode}: ${response.body}');
          lastError = const GeminiServiceException(
            type: GeminiErrorType.invalidApiKey,
            userMessage: 'Google rejected your API key. Please check your key in Settings.',
          );
          return null; // Don't retry on auth errors
        } else if (response.statusCode == 429) {
          debugPrint('[GeminiService] Rate limit hit (429): ${response.body}');
          lastError = const GeminiServiceException(
            type: GeminiErrorType.rateLimitExceeded,
            userMessage: 'Google AI rate limit reached (15 RPM). Please wait 30 seconds before retrying.',
          );
          continue;
        } else if (response.statusCode >= 500 || response.statusCode == 404) {
          debugPrint('[GeminiService] Model $model returned ${response.statusCode}. Trying next model...');
          lastError = const GeminiServiceException(
            type: GeminiErrorType.serverBusy,
            userMessage: 'Google AI is currently experiencing high demand. Please try again shortly.',
          );
          continue;
        }
      } on SocketException {
        debugPrint('[GeminiService] SocketException connecting to $model');
        lastError = const GeminiServiceException(
          type: GeminiErrorType.networkError,
          userMessage: 'No internet connection. Audio is saved locally on your phone.',
        );
        break; // No internet - skip further attempts
      } catch (e) {
        debugPrint('[GeminiService] Request failed for model $model: $e');
        if (e.toString().contains('Failed host lookup') || e.toString().contains('SocketException')) {
          lastError = const GeminiServiceException(
            type: GeminiErrorType.networkError,
            userMessage: 'No internet connection. Audio is saved locally on your phone.',
          );
          break;
        }
      }
    }

    lastError ??= const GeminiServiceException(
      type: GeminiErrorType.unknown,
      userMessage: 'Could not process audio. Your recording is preserved locally.',
    );
    return null;
  }

  /// Re-polishes an existing transcript or text memo without re-uploading audio.
  /// Typically completes in 1-2 seconds.
  Future<GeminiResult?> polishText({
    required String apiKey,
    required String text,
    required String tone,
    required String intensity,
    String? customInstructions,
    List<TimestampItem>? existingTimestamps,
  }) async {
    lastError = null;
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      debugPrint('[GeminiService] polishText aborted: Empty key.');
      lastError = const GeminiServiceException(
        type: GeminiErrorType.noApiKey,
        userMessage: 'Please add your Google AI Studio API key in Settings.',
      );
      return null;
    }

    if (text.trim().isEmpty) {
      debugPrint('[GeminiService] polishText aborted: Empty text.');
      lastError = const GeminiServiceException(
        type: GeminiErrorType.emptyAudio,
        userMessage: 'Note transcript is empty.',
      );
      return null;
    }

    final customGuidance = (tone == 'Custom Tone' &&
            customInstructions != null &&
            customInstructions.trim().isNotEmpty)
        ? '\nSpecial Custom User Instructions:\n${customInstructions.trim()}\n'
        : '';

    final promptText = '''
You are VoicePen, an editorial AI assistant that transforms spoken transcripts into structured, elegant notes.
Tone: $tone
Intensity: $intensity
$customGuidance

Refactor the following transcript into a polished note:
---
${text.trim()}
---

Return ONLY a valid JSON object matching this schema:
{
  "title": "Punchy editorial title (5-8 words max)",
  "cleaned_content": "Polished note in rich Markdown matching '$tone' tone. Must start with a '## Executive Summary' section summarizing the recording in 2-3 sentences, followed by '## Key Takeaways' and '## Action Items' (if applicable) with clean bullet points.",
  "tags": ["Tag1", "Tag2"]
}
Return ONLY valid JSON. No markdown code fences, no extra text.
''';

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': promptText},
          ],
        },
      ],
      'safetySettings': _safetySettings,
      'generationConfig': {
        'temperature': 0.3,
        'responseMimeType': 'application/json',
      },
    });

    for (final model in _modelsToTry) {
      try {
        final stopwatch = Stopwatch()..start();
        final endpoint =
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';

        final response = await http
            .post(
              Uri.parse(endpoint),
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': cleanKey,
              },
              body: requestBody,
            )
            .timeout(const Duration(seconds: 12));
        stopwatch.stop();

        debugPrint(
            '[GeminiService] polishText HTTP ${response.statusCode} from $model in ${stopwatch.elapsedMilliseconds}ms');

        if (response.statusCode == 200) {
          final data = _extractJson(response.body);
          if (data != null) {
            lastError = null;
            final title = data['title'] as String? ?? 'Voice Memo: $tone';
            debugPrint('[GeminiService] ✓ Note re-polished successfully via $model: "$title"');
            final cleanedContent = data['cleaned_content'] as String? ?? text;
            final rawTags = data['tags'] as List<dynamic>? ?? [];
            final tags = rawTags.map((t) => t.toString()).toList();
            if (tags.isEmpty) tags.add('Ideas');

            return GeminiResult(
              title: title,
              cleanedContent: cleanedContent,
              verbatimTranscript: text,
              timestamps: existingTimestamps ??
                  [TimestampItem(timeSeconds: 0, text: text)],
              tags: tags,
            );
          }
        } else if (response.statusCode == 400 ||
            response.statusCode == 401 ||
            response.statusCode == 403) {
          debugPrint('[GeminiService] polishText Auth/Client error ${response.statusCode}: ${response.body}');
          lastError = const GeminiServiceException(
            type: GeminiErrorType.invalidApiKey,
            userMessage: 'Google rejected your API key. Please check your key in Settings.',
          );
          return null; // Stop immediately on bad auth
        } else if (response.statusCode == 429) {
          debugPrint('[GeminiService] polishText 429 hit');
          lastError = const GeminiServiceException(
            type: GeminiErrorType.rateLimitExceeded,
            userMessage: 'Rate limit reached (15 RPM). Please wait 30 seconds before re-polishing.',
          );
          continue;
        } else {
          debugPrint('[GeminiService] polishText model $model returned ${response.statusCode}. Trying next model...');
          lastError = const GeminiServiceException(
            type: GeminiErrorType.serverBusy,
            userMessage: 'Google AI is currently busy. Please try re-polishing shortly.',
          );
          continue;
        }
      } on SocketException {
        lastError = const GeminiServiceException(
          type: GeminiErrorType.networkError,
          userMessage: 'Connection failed. Please check your internet connection.',
        );
        break;
      } catch (e) {
        debugPrint('[GeminiService] polishText failed for $model: $e');
        if (e.toString().contains('Failed host lookup') || e.toString().contains('SocketException')) {
          lastError = const GeminiServiceException(
            type: GeminiErrorType.networkError,
            userMessage: 'Connection failed. Please check your internet connection.',
          );
          break;
        }
      }
    }

    lastError ??= const GeminiServiceException(
      type: GeminiErrorType.unknown,
      userMessage: 'Could not re-polish note. Please try again.',
    );
    return null;
  }

  /// Parses the raw Gemini response body and handles structured candidates.
  GeminiResult? _parseResponse(String body, String tone) {
    try {
      final data = _extractJson(body);
      if (data == null) return null;

      final title = data['title'] as String? ?? 'Voice Memo: $tone';
      final cleanedContent = data['cleaned_content'] as String? ?? '';
      final verbatimTranscript = data['verbatim_transcript'] as String? ?? '';

      final rawTags = data['tags'] as List<dynamic>? ?? [];
      final tags = rawTags.map((t) => t.toString()).toList();
      if (tags.isEmpty) tags.add('Ideas');

      final rawTimestamps = data['timestamps'] as List<dynamic>? ?? [];
      final timestamps = rawTimestamps.map((item) {
        final m = item as Map<String, dynamic>;
        return TimestampItem(
          timeSeconds: (m['time_seconds'] as num?)?.toInt() ?? 0,
          text: m['text'] as String? ?? '',
        );
      }).toList();

      if (timestamps.isEmpty) {
        timestamps.add(TimestampItem(
          timeSeconds: 0,
          text: verbatimTranscript.isNotEmpty
              ? verbatimTranscript
              : 'Voice recording captured.',
        ));
      }

      return GeminiResult(
        title: title,
        cleanedContent: cleanedContent,
        verbatimTranscript: verbatimTranscript,
        timestamps: timestamps,
        tags: tags,
      );
    } catch (e) {
      debugPrint('[GeminiService] Failed to parse response: $e');
      return null;
    }
  }

  /// Safely extracts and decodes a JSON object from Gemini's response body.
  Map<String, dynamic>? _extractJson(String responseBody) {
    try {
      final responseJson = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = responseJson['candidates'] as List<dynamic>? ?? [];
      if (candidates.isEmpty) {
        debugPrint('[GeminiService] No candidates in response: $responseBody');
        return null;
      }

      final candidate = candidates[0] as Map<String, dynamic>;
      final content = candidate['content'] as Map<String, dynamic>? ?? {};
      final parts = content['parts'] as List<dynamic>? ?? [];
      if (parts.isEmpty) {
        debugPrint('[GeminiService] No parts in candidate content.');
        return null;
      }

      String text = '';
      for (final part in parts) {
        if (part is Map<String, dynamic>) {
          if (part['thought'] == true) continue;
          final partText = (part['text'] as String? ?? '').trim();
          if (partText.isNotEmpty) {
            text = partText;
            if (text.contains('{')) break;
          }
        }
      }

      if (text.isEmpty && parts.isNotEmpty) {
        final last = parts.last;
        if (last is Map<String, dynamic>) {
          text = (last['text'] as String? ?? '').trim();
        }
      }

      if (text.isEmpty) return null;

      String jsonStr = text;
      final startIdx = jsonStr.indexOf('{');
      final endIdx = jsonStr.lastIndexOf('}');
      if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
        jsonStr = jsonStr.substring(startIdx, endIdx + 1);
      }

      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[GeminiService] JSON extraction error: $e');
      return null;
    }
  }

  /// Calls the VoicePen Cloud 'polish' Edge Function to transcribe & polish audio
  /// using the server-managed Gemini key pool.
  Future<GeminiResult?> polishAudioCloud({
    required String audioPath,
    required String tone,
    required String intensity,
    String? customInstructions,
  }) async {
    lastError = null;
    final file = File(audioPath);
    if (!await file.exists()) {
      debugPrint('[GeminiService] Audio file does not exist: $audioPath');
      lastError = const GeminiServiceException(
        type: GeminiErrorType.emptyAudio,
        userMessage: 'Audio file not found on device.',
      );
      return null;
    }

    final audioBytes = await file.readAsBytes();
    if (audioBytes.isEmpty) {
      debugPrint('[GeminiService] Audio file is empty (0 bytes).');
      lastError = const GeminiServiceException(
        type: GeminiErrorType.emptyAudio,
        userMessage: 'Audio recording is empty (0 bytes). Please re-record.',
      );
      return null;
    }

    final mimeType = getMimeTypeForPath(audioPath);
    final audioBase64 = base64Encode(audioBytes);

    try {
      debugPrint('[GeminiService] Calling VoicePen Cloud polish Edge Function (audio mode)...');
      final res = await Supabase.instance.client.functions.invoke(
        'polish',
        body: {
          'mode': 'audio',
          'audioBase64': audioBase64,
          'mimeType': mimeType,
          'tone': tone,
          'format': 'Executive Summary',
          'language': 'auto',
        },
      );

      if (res.status == 200 && res.data != null) {
        final data = res.data is Map<String, dynamic>
            ? res.data as Map<String, dynamic>
            : jsonDecode(res.data.toString()) as Map<String, dynamic>;

        final title = data['title'] as String? ?? 'Voice Note';
        final summary = data['summary'] as String? ?? '';
        final contentStr = data['content'] as String? ?? '';
        final transcript = data['verbatim_transcript'] as String? ?? '';
        final rawTags = data['tags'] as List? ?? ['Ideas'];
        final tags = rawTags.map((t) => t.toString()).toList();

        final formattedContent = summary.isNotEmpty && !contentStr.contains('## Executive Summary')
            ? '## Executive Summary\n$summary\n\n$contentStr'
            : contentStr;

        debugPrint('[GeminiService] VoicePen Cloud audio polish succeeded: $title');
        return GeminiResult(
          title: title,
          cleanedContent: formattedContent,
          verbatimTranscript: transcript.isNotEmpty ? transcript : 'Spoken recording transcribed by VoicePen Cloud.',
          timestamps: const [
            TimestampItem(timeSeconds: 0, text: 'Beginning of recording'),
          ],
          tags: tags,
        );
      } else {
        final errText = res.data?['error']?.toString() ?? 'VoicePen Cloud returned status ${res.status}';
        debugPrint('[GeminiService] VoicePen Cloud error: $errText');
        lastError = GeminiServiceException(
          type: res.status == 429 ? GeminiErrorType.rateLimitExceeded : GeminiErrorType.serverBusy,
          userMessage: errText,
        );
        return null;
      }
    } catch (e) {
      debugPrint('[GeminiService] Cloud function invocation exception: $e');
      lastError = GeminiServiceException(
        type: GeminiErrorType.networkError,
        userMessage: 'Cloud connection issue: ${e.toString()}',
      );
      return null;
    }
  }

  /// Calls the VoicePen Cloud 'polish' Edge Function to re-polish existing text.
  Future<GeminiResult?> polishTextCloud({
    required String text,
    required String tone,
    required String intensity,
    String? customInstructions,
    List<TimestampItem>? existingTimestamps,
  }) async {
    lastError = null;
    try {
      debugPrint('[GeminiService] Calling VoicePen Cloud polish Edge Function (text mode)...');
      final res = await Supabase.instance.client.functions.invoke(
        'polish',
        body: {
          'mode': 'text',
          'rawText': text,
          'tone': tone,
          'format': 'Executive Summary',
          'language': 'auto',
        },
      );

      if (res.status == 200 && res.data != null) {
        final data = res.data is Map<String, dynamic>
            ? res.data as Map<String, dynamic>
            : jsonDecode(res.data.toString()) as Map<String, dynamic>;

        final title = data['title'] as String? ?? 'Voice Note';
        final summary = data['summary'] as String? ?? '';
        final contentStr = data['content'] as String? ?? '';
        final transcript = data['verbatim_transcript'] as String? ?? text;
        final rawTags = data['tags'] as List? ?? ['Ideas'];
        final tags = rawTags.map((t) => t.toString()).toList();

        final formattedContent = summary.isNotEmpty && !contentStr.contains('## Executive Summary')
            ? '## Executive Summary\n$summary\n\n$contentStr'
            : contentStr;

        debugPrint('[GeminiService] VoicePen Cloud text polish succeeded: $title');
        return GeminiResult(
          title: title,
          cleanedContent: formattedContent,
          verbatimTranscript: transcript,
          timestamps: existingTimestamps ?? const [
            TimestampItem(timeSeconds: 0, text: 'Beginning of recording'),
          ],
          tags: tags,
        );
      } else {
        final errText = res.data?['error']?.toString() ?? 'VoicePen Cloud returned status ${res.status}';
        debugPrint('[GeminiService] VoicePen Cloud text error: $errText');
        lastError = GeminiServiceException(
          type: res.status == 429 ? GeminiErrorType.rateLimitExceeded : GeminiErrorType.serverBusy,
          userMessage: errText,
        );
        return null;
      }
    } catch (e) {
      debugPrint('[GeminiService] Cloud function invocation exception: $e');
      lastError = GeminiServiceException(
        type: GeminiErrorType.networkError,
        userMessage: 'Cloud connection issue: ${e.toString()}',
      );
      return null;
    }
  }
}
