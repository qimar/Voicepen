import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_page_route.dart';
import '../../../../core/models/note_model.dart';
import '../../../../core/state/notes_state.dart';
import '../../../../core/services/gemini_service.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

class AiProcessingOverlay extends ConsumerStatefulWidget {
  final String tone;
  final String intensity;
  final String formattedDuration;
  final int durationSeconds;
  final String audioPath;
  final NoteModel? existingNote;
  final VoidCallback? onCancel;
  final ValueChanged<NoteModel> onComplete;

  const AiProcessingOverlay({
    super.key,
    required this.tone,
    required this.intensity,
    required this.formattedDuration,
    required this.durationSeconds,
    required this.audioPath,
    this.existingNote,
    this.onCancel,
    required this.onComplete,
  });

  @override
  ConsumerState<AiProcessingOverlay> createState() => _AiProcessingOverlayState();
}

class _AiProcessingOverlayState extends ConsumerState<AiProcessingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final NotesNotifier _notesNotifier;
  late final String _apiKey;
  int _currentStep = 0; // 0 = audio save, 1 = transcription, 2 = structuring, 3 = done

  @override
  void initState() {
    super.initState();
    _notesNotifier = ref.read(notesProvider.notifier);
    _apiKey = ref.read(notesProvider).byokApiKey;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _runProcessingPipeline();
  }

  Future<void> _runProcessingPipeline() async {
    // Step 0 -> Step 1: Save audio locally verified
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _currentStep = 1);

    final apiKey = _apiKey;
    debugPrint('[AiProcessingOverlay] Pipeline starting. API Key length: ${apiKey.length}, audioPath: ${widget.audioPath}');
    GeminiResult? result;
    GeminiServiceException? failureError;

    if (apiKey.isNotEmpty) {
      final geminiService = GeminiService();
      final customPrompt = ref.read(notesProvider).customTonePrompt;

      // Fast-path: Re-polishing an existing transcript takes ~1s without audio re-upload
      if (widget.existingNote != null &&
          widget.existingNote!.verbatimTranscript.trim().isNotEmpty) {
        debugPrint('[AiProcessingOverlay] Re-polishing existing transcript via fast text pipeline (BYOK)...');
        result = await geminiService.polishText(
          apiKey: apiKey,
          text: widget.existingNote!.verbatimTranscript,
          tone: widget.tone,
          intensity: widget.intensity,
          customInstructions: customPrompt,
          existingTimestamps: widget.existingNote!.timestamps,
        );
      } else if (widget.audioPath.isNotEmpty) {
        debugPrint('[AiProcessingOverlay] Polishing audio file via multimodal pipeline (BYOK)...');
        result = await geminiService.polishAudio(
          apiKey: apiKey,
          audioPath: widget.audioPath,
          tone: widget.tone,
          intensity: widget.intensity,
          customInstructions: customPrompt,
        );
      }
      failureError = geminiService.lastError;
    } else {
      // VoicePen Cloud Pipeline (via Supabase Edge Function & Server-side Gemini Pool)
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        final geminiService = GeminiService();
        final customPrompt = ref.read(notesProvider).customTonePrompt;

        if (widget.existingNote != null &&
            widget.existingNote!.verbatimTranscript.trim().isNotEmpty) {
          debugPrint('[AiProcessingOverlay] Re-polishing existing transcript via VoicePen Cloud...');
          result = await geminiService.polishTextCloud(
            text: widget.existingNote!.verbatimTranscript,
            tone: widget.tone,
            intensity: widget.intensity,
            customInstructions: customPrompt,
            existingTimestamps: widget.existingNote!.timestamps,
          );
        } else if (widget.audioPath.isNotEmpty) {
          debugPrint('[AiProcessingOverlay] Polishing audio file via VoicePen Cloud...');
          result = await geminiService.polishAudioCloud(
            audioPath: widget.audioPath,
            tone: widget.tone,
            intensity: widget.intensity,
            customInstructions: customPrompt,
          );
        }
        failureError = geminiService.lastError;
      } else {
        debugPrint('[AiProcessingOverlay] Skipping AI: No personal key and user is not signed in to VoicePen Cloud.');
        failureError = const GeminiServiceException(
          type: GeminiErrorType.noApiKey,
          userMessage: 'Please sign in or configure your Gemini API key in Settings.',
        );
      }
    }

    if (mounted) setState(() => _currentStep = 2);
    await Future.delayed(const Duration(milliseconds: 500));

    // ── Re-polish failure: show error dialog and bail out without touching the note ──
    if (result == null && widget.existingNote != null && mounted) {
      _showRepolishErrorDialog(failureError);
      return;
    }

    // ── New recording failure: show a brief snackbar then fall through to offline save ──
    if (result == null && widget.existingNote == null && failureError != null && mounted) {
      _showOfflineSnackBar(failureError);
    }

    final isOffline = result == null;
    final now = DateTime.now();

    final NoteModel note;
    if (widget.existingNote != null) {
      String title = result?.title ?? widget.existingNote!.title;
      if (title.length > 40) title = title.substring(0, 40);

      note = widget.existingNote!.copyWith(
        title: title,
        cleanedContent: result?.cleanedContent ?? widget.existingNote!.cleanedContent,
        verbatimTranscript: result?.verbatimTranscript ?? widget.existingNote!.verbatimTranscript,
        timestamps: result?.timestamps ?? widget.existingNote!.timestamps,
        tags: result?.tags ?? widget.existingNote!.tags,
        isPending: isOffline,
        tone: widget.tone,
        intensity: widget.intensity,
      );
      // Update SQLite & Riverpod safely
      await _notesNotifier.updateNote(note);
    } else {
      final noteId = 'memo_${now.millisecondsSinceEpoch}';
      String title = result?.title ?? 'Voice Memo: ${widget.tone}';
      if (title.length > 40) title = title.substring(0, 40);

      int actualDuration = widget.durationSeconds;
      if (actualDuration <= 0 && widget.audioPath.isNotEmpty) {
        try {
          final probe = AudioPlayer();
          final d = await probe.setFilePath(widget.audioPath);
          await probe.dispose();
          if (d != null && d.inSeconds > 0) {
            actualDuration = d.inSeconds;
          }
        } catch (e) {
          debugPrint('[AiProcessingOverlay] Error probing audio duration: $e');
        }
      }
      if (actualDuration <= 0) actualDuration = 1;

      note = NoteModel(
        id: noteId,
        title: title,
        cleanedContent: result?.cleanedContent ?? '''## Offline Voice Note

Captured audio memo preserved securely in device sandbox. Connect to a network or add your Google AI Studio API key in Settings to polish this recording.''',
        verbatimTranscript: result?.verbatimTranscript ??
            'Audio recording saved locally on device. Transcripts will generate upon reconnection.',
        timestamps: result?.timestamps ?? [
          TimestampItem(
            timeSeconds: 0,
            text: 'Voice recording captured locally.',
          ),
        ],
        audioPath: widget.audioPath,
        durationSeconds: actualDuration,
        tone: widget.tone,
        intensity: widget.intensity,
        tags: result?.tags ?? ['Ideas'],
        isPending: isOffline,
        createdAt: now,
      );
      // Persist note to SQLite and Riverpod safely using cached notifier
      await _notesNotifier.addNote(note);
    }

    if (mounted) {
      setState(() => _currentStep = 3);
      await Future.delayed(const Duration(milliseconds: 400));
      widget.onComplete(note);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Error feedback helpers
  // ─────────────────────────────────────────────────────────────

  /// Shows an error dialog when re-polishing an *existing* note fails.
  /// Pops the overlay so the user returns to the unchanged note.
  void _showRepolishErrorDialog(GeminiServiceException? error) {
    if (!mounted) return;

    final type = error?.type ?? GeminiErrorType.unknown;
    final message = error?.userMessage ?? 'Could not re-polish note. Please try again.';
    final bool isKeyIssue =
        type == GeminiErrorType.noApiKey || type == GeminiErrorType.invalidApiKey;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        icon: Icon(
          isKeyIssue ? Icons.key_off_rounded : Icons.error_outline_rounded,
          color: AppColors.error,
          size: 32,
        ),
        title: Text(
          'Re-Polish Failed',
          style: AppTypography.headlineSmall.copyWith(
            color: AppColors.inkPrimary,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          message,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.inkMuted,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (isKeyIssue)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _popOverlay();
                _navigateToSettings();
              },
              child: Text(
                'Open Settings',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _popOverlay();
            },
            child: Text(
              isKeyIssue ? 'Cancel' : 'Got It',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows a brief snackbar on a new-recording failure before the offline note is saved.
  void _showOfflineSnackBar(GeminiServiceException error) {
    if (!mounted) return;

    final bool isKeyIssue =
        error.type == GeminiErrorType.noApiKey || error.type == GeminiErrorType.invalidApiKey;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        backgroundColor: AppColors.warningBg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.warningBorder),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        content: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppColors.warningIcon, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error.userMessage,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.warningText,
                ),
              ),
            ),
          ],
        ),
        action: isKeyIssue
            ? SnackBarAction(
                label: 'Settings',
                textColor: AppColors.primary,
                onPressed: _navigateToSettings,
              )
            : null,
      ),
    );
  }

  /// Pops the overlay without delivering onComplete so callers navigate back naturally.
  void _popOverlay() {
    if (widget.onCancel != null) {
      widget.onCancel!();
    } else if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  /// Navigates to the app settings screen from the overlay context.
  void _navigateToSettings() {
    if (!mounted) return;
    _popOverlay();
    Navigator.of(context).push(
      AppPageRoute(page: const SettingsScreen()),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  double get _progressPercent {
    switch (_currentStep) {
      case 0:
        return 0.35;
      case 1:
        return 0.68;
      case 2:
        return 0.94;
      default:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              // 1. Top Header Segment
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 36), // balancer
                  Text(
                    'Polishing Voice Memo',
                    style: AppTypography.labelLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.peachTint,
                      borderRadius: AppRadii.roundedFull,
                      border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule, size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          widget.formattedDuration,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 2. Central Layered Orb & Headline
              Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Ripple Ring 2
                          Container(
                            width: 130 + (_pulseController.value * 18),
                            height: 130 + (_pulseController.value * 18),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(
                                alpha: 0.08 * (1.0 - _pulseController.value),
                              ),
                            ),
                          ),
                          // Ripple Ring 1
                          Container(
                            width: 105 + (_pulseController.value * 10),
                            height: 105 + (_pulseController.value * 10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(
                                alpha: 0.14 * (1.0 - _pulseController.value),
                              ),
                            ),
                          ),
                          // Core Orb
                          Container(
                            width: 82,
                            height: 82,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [AppColors.primary, AppColors.secondary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: AppShadows.fab,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.edit_note,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Polishing Your Thoughts…',
                    style: GoogleFonts.newsreader(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: AppColors.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Transforming raw voice audio into structured, publication-ready prose.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.inkMuted,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 3. Pipeline Checklist Card matching Stitch
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.roundedLg,
                  border: Border.all(color: AppColors.borderSubtle),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'AI PIPELINE PROGRESS',
                          style: AppTypography.labelSmall.copyWith(
                            letterSpacing: 1.0,
                            color: AppColors.inkMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${(_progressPercent * 100).round()}% Complete',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Multi-phase Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progressPercent,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceContainer,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Step 1: Speech Understanding
                    _buildStepRow(
                      stepNumber: 1,
                      title: '1. Multimodal Speech Understanding',
                      subtitle: 'Gemini Flash acoustic transcription',
                      isDone: _currentStep >= 1,
                      isActive: _currentStep == 0,
                    ),
                    const SizedBox(height: 10),
                    // Step 2: Tone Orchestration
                    _buildStepRow(
                      stepNumber: 2,
                      title: '2. Editorial Tone Orchestration',
                      subtitle: 'Structuring headings & bullet clarity (${widget.tone})',
                      isDone: _currentStep >= 2,
                      isActive: _currentStep == 1,
                    ),
                    const SizedBox(height: 10),
                    // Step 3: Timestamps
                    _buildStepRow(
                      stepNumber: 3,
                      title: '3. Fact-Checking Timestamps',
                      subtitle: 'Audio scrub points synchronizing',
                      isDone: _currentStep >= 3,
                      isActive: _currentStep == 2,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 4. Live AI Status & Tone Preview Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.roundedLg,
                  border: Border.all(color: AppColors.borderSubtle),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'AI ORCHESTRATION',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Tone: ${widget.tone}',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.inkMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _currentStep == 0
                          ? 'Reading local voice recording from device sandbox…'
                          : _currentStep == 1
                              ? 'Contacting Gemini engine to transcribe verbatim audio chunks…'
                              : _currentStep == 2
                                  ? 'Applying "${widget.tone}" style, structuring headings and bullets…'
                                  : 'Polishing completed successfully!',
                      style: GoogleFonts.newsreader(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        color: AppColors.inkPrimary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Intensity: ${widget.intensity}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.inkMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Audio: ${widget.formattedDuration}',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.inkMuted,
                            fontWeight: FontWeight.w500,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Footer Note
              Text(
                'Processing securely on your device. You will be notified when ready.',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.inkSubtle,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required int stepNumber,
    required String title,
    required String subtitle,
    required bool isDone,
    required bool isActive,
  }) {
    Color iconBg;
    Widget iconWidget;

    if (isDone) {
      iconBg = AppColors.successContainer;
      iconWidget = const Icon(Icons.check, size: 14, color: AppColors.onSuccess);
    } else if (isActive) {
      iconBg = AppColors.peachTint;
      iconWidget = const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
      );
    } else {
      iconBg = AppColors.surfaceContainer;
      iconWidget = Text(
        '$stepNumber',
        style: const TextStyle(fontSize: 10, color: AppColors.inkMuted, fontWeight: FontWeight.bold),
      );
    }

    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
          child: Center(child: iconWidget),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDone || isActive ? AppColors.inkPrimary : AppColors.inkMuted,
                ),
              ),
              Text(
                subtitle,
                style: AppTypography.labelSmall.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
        if (isDone)
          Text(
            'Done ✓',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.onSuccess,
              fontWeight: FontWeight.w600,
            ),
          )
        else if (isActive)
          Text(
            'Polishing…',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          Text(
            'Queued',
            style: AppTypography.labelSmall.copyWith(color: AppColors.inkSubtle),
          ),
      ],
    );
  }
}
