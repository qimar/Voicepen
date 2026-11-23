import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_page_route.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/constants/tone_presets.dart';
import '../../../../core/models/note_model.dart';
import '../../../../core/state/notes_state.dart';
import '../../../../core/services/audio_recorder_service.dart';
import '../../../../core/widgets/waveform_visualizer.dart';
import '../../../../core/widgets/app_bounceable.dart';
import '../widgets/discard_recording_dialog.dart';
import '../widgets/mic_permission_dialog.dart';
import '../widgets/ai_processing_overlay.dart';
import '../widgets/tone_bottom_sheet.dart';
import '../../../notes/presentation/screens/note_detail_screen.dart';
import '../../../monetization/presentation/screens/paywall_screen.dart';

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen>
    with SingleTickerProviderStateMixin {
  final AudioRecorderService _audioRecorderService = AudioRecorderService();
  String? _currentAudioPath;
  bool _isRecording = true;
  bool _isProcessing = false;
  int _elapsedSeconds = 0;
  Timer? _timer;

  String _selectedTone = 'Clear & Concise';
  String _selectedIntensity = 'Medium';

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _initRecording();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  Future<void> _initRecording() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      _currentAudioPath = await _audioRecorderService.startRecording();
      _startTimer();
    } else {
      if (mounted) {
        showDialog(
          context: context,
          barrierColor: AppColors.scrim,
          builder: (_) => MicPermissionDialog(
            onDismiss: () => Navigator.of(context).pop(),
          ),
        );
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRecording) {
        final isPro = ref.read(notesProvider).isProUser;
        // 15-minute free limit enforcement (900 seconds)
        if (!isPro && _elapsedSeconds >= 900) {
          _timer?.cancel();
          _togglePause();
          _showFreeLimitReachedDialog();
          return;
        }

        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  void _showFreeLimitReachedDialog() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.scrim,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFCF9F4),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.borderSubtle, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.inkPrimary.withValues(alpha: 0.18),
                blurRadius: 36,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: AppColors.peachTint,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.timer_off_outlined,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '15-Minute Free Cap',
                style: GoogleFonts.newsreader(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Free voice memos are capped at 15 minutes. You can polish what you have recorded so far, or unlock VoicePen Pro for unlimited recording duration.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.inkMuted,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              AppBounceable(
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    AppPageRoute(page: const PaywallScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppRadii.roundedFull,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Upgrade to Pro',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AppBounceable(
                onTap: () {
                  Navigator.of(ctx).pop();
                  _finishAndPolish();
                },
                child: Container(
                  width: double.infinity,
                  height: 44,
                  alignment: Alignment.center,
                  child: const Text(
                    'Finish & Polish Current Audio',
                    style: TextStyle(
                      color: AppColors.inkMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _audioRecorderService.dispose();
    super.dispose();
  }

  String get _formattedTime {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _togglePause() async {
    HapticFeedback.lightImpact();
    if (_isRecording) {
      await _audioRecorderService.pauseRecording();
      _pulseController.stop();
      setState(() {
        _isRecording = false;
      });
    } else {
      await _audioRecorderService.resumeRecording();
      _pulseController.repeat(reverse: true);
      setState(() {
        _isRecording = true;
      });
    }
  }

  void _showDiscardDialog() {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      barrierColor: AppColors.scrim,
      builder: (_) => DiscardRecordingDialog(
        durationText: _formattedTime,
        onKeep: () => Navigator.of(context).pop(),
        onDiscard: () async {
          await _audioRecorderService.cancelRecording();
          if (mounted) {
            Navigator.of(context).pop(); // dismiss dialog
            Navigator.of(context).pop(); // dismiss record screen
          }
        },
      ),
    );
  }

  Future<void> _openToneCustomizer() async {
    debugPrint('[RecordScreen] Opening Tone Customizer sheet...');
    // If currently recording, pause recording and timer while customization sheet is open
    if (_isRecording) {
      await _audioRecorderService.pauseRecording();
      setState(() {
        _isRecording = false;
      });
      debugPrint('[RecordScreen] Mic paused for Tone sheet.');
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      builder: (_) => ToneBottomSheet(
        currentTone: _selectedTone,
        currentIntensity: _selectedIntensity,
        isRepolishing: false,
        onApply: (tone, intensity) {
          debugPrint('[RecordScreen] Applied tone: $tone | intensity: $intensity');
          setState(() {
            _selectedTone = tone;
            _selectedIntensity = intensity;
          });
        },
      ),
    );
  }

  Future<void> _finishAndPolish() async {
    debugPrint('[RecordScreen] Finish & Polish tapped! Elapsed: $_elapsedSeconds s');
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    try {
      final path = await _audioRecorderService.stopRecording();
      debugPrint('[RecordScreen] Stopped recording. Output file: $path');
      if (path != null) {
        _currentAudioPath = path;
      }
    } catch (e, st) {
      debugPrint('[RecordScreen] Error in stopRecording: $e\n$st');
    }
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });
      debugPrint('[RecordScreen] State changed to _isProcessing = true');
    }
  }

  void _onProcessingComplete(NoteModel newNote) {
    Navigator.of(context).pushReplacement(
      AppPageRoute(page: NoteDetailScreen(note: newNote)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return AiProcessingOverlay(
        tone: _selectedTone,
        intensity: _selectedIntensity,
        formattedDuration: _formattedTime,
        durationSeconds: _elapsedSeconds,
        audioPath: _currentAudioPath ?? '',
        onCancel: () {
          setState(() {
            _isProcessing = false;
          });
        },
        onComplete: _onProcessingComplete,
      );
    }

    final isPro = ref.watch(notesProvider).isProUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 1. Top Header Segment matching Stitch
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppBounceable(
                    onTap: _showDiscardDialog,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.card,
                      ),
                      child: const Center(
                        child: Icon(Icons.close, size: 20, color: AppColors.inkPrimary),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        'New Voice Memo',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Voice to structured notes',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: AppColors.peachTint,
                      borderRadius: AppRadii.roundedFull,
                      border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.8)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          isPro ? 'LIFETIME PRO' : 'FREE TIER',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Select AI Tone Sub-Header & Carousel matching Stitch
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SELECT AI TONE',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.inkMuted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      AppBounceable(
                        onTap: _openToneCustomizer,
                        child: Row(
                          children: [
                            Text(
                              'Customize',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.tune, size: 13, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: TonePresets.all.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final preset = TonePresets.all[index];
                        final isSelected = _selectedTone == preset.label;
                        final isLocked = preset.isProOnly && !ref.watch(notesProvider).isProUser;

                        return AppBounceable(
                          onTap: () {
                            if (isLocked) {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).push(
                                AppPageRoute(page: const PaywallScreen()),
                              );
                              return;
                            }
                            setState(() => _selectedTone = preset.label);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : AppColors.surface,
                              borderRadius: AppRadii.roundedFull,
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.borderSubtle,
                                width: 1,
                              ),
                              boxShadow: isSelected ? AppShadows.card : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  preset.icon,
                                  size: 15,
                                  color: isSelected ? Colors.white : AppColors.inkPrimary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  preset.label,
                                  style: AppTypography.labelMedium.copyWith(
                                    color: isSelected ? Colors.white : AppColors.inkPrimary,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                                if (isLocked) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.lock_outline,
                                    size: 12,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 3. Main Center Canvas: Waveform, Live Transcript, Timer & Mic FAB
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Waveform Amplitude Visualizer
                    WaveformVisualizer(
                      isRecording: _isRecording,
                      height: 52,
                      barCount: 30,
                    ),

                    const SizedBox(height: 18),

                    // Live Streaming Draft Card matching Stitch HTML
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
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _isRecording ? AppColors.primary : AppColors.inkSubtle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isRecording ? 'LIVE AUDIO CAPTURE' : 'PAUSED',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.language, size: 14, color: AppColors.inkMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    'English (Auto)',
                                    style: AppTypography.labelSmall.copyWith(color: AppColors.inkMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.newsreader(
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                                color: AppColors.inkPrimary,
                                height: 1.45,
                              ),
                              children: [
                                TextSpan(
                                  text: _isRecording
                                      ? '"Recording your voice master. Full editorial notes and timestamps will generate upon finishing...'
                                      : '"Audio recording paused. Tap resume to continue speaking or finish to polish...',
                                ),
                                if (_isRecording)
                                  WidgetSpan(
                                    child: Container(
                                      width: 2,
                                      height: 16,
                                      margin: const EdgeInsets.only(left: 3),
                                      color: AppColors.primary,
                                    ),
                                  ),
                                const TextSpan(text: '"'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Recording Timer Display
                    Column(
                      children: [
                        Text(
                          _formattedTime,
                          style: GoogleFonts.inter(
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.0,
                            color: AppColors.inkPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainer,
                                borderRadius: AppRadii.roundedFull,
                                border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.7)),
                              ),
                              child: Text(
                                'Free limit: 15:00',
                                style: AppTypography.labelSmall.copyWith(color: AppColors.inkMuted),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainer,
                                borderRadius: AppRadii.roundedFull,
                                border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.7)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'HD • 48kHz',
                                    style: AppTypography.labelSmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.inkPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Central Record / Pause Trigger with Concentric Pulse Rings
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_isRecording) ...[
                              Container(
                                width: 96 + (_pulseController.value * 24),
                                height: 96 + (_pulseController.value * 24),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.12 * (1.0 - _pulseController.value),
                                  ),
                                ),
                              ),
                              Container(
                                width: 84 + (_pulseController.value * 12),
                                height: 84 + (_pulseController.value * 12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.22 * (1.0 - _pulseController.value),
                                  ),
                                ),
                              ),
                            ],
                            AppBounceable(
                              onTap: _togglePause,
                              scaleFactor: 0.90,
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.background, width: 4),
                                  boxShadow: AppShadows.fab,
                                ),
                                child: Center(
                                  child: Icon(
                                    _isRecording ? Icons.mic : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 34,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 10),
                    Text(
                      _isRecording ? 'Listening... Tap to Pause' : 'Paused • Tap to Resume',
                      style: AppTypography.labelMedium.copyWith(color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Bottom Lower Actions Bar matching Stitch
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 8),
              child: Row(
                children: [
                  // Cancel Button
                  Expanded(
                    flex: 1,
                    child: AppBounceable(
                      onTap: _showDiscardDialog,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadii.roundedFull,
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: AppColors.inkMuted),
                            SizedBox(width: 6),
                            Text(
                              'Cancel',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Finish & Polish Button
                  Expanded(
                    flex: 2,
                    child: AppBounceable(
                      onTap: _finishAndPolish,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: AppRadii.roundedFull,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Finish & Polish',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
