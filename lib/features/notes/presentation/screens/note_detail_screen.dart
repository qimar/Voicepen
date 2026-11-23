import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/models/note_model.dart';
import '../../../../core/state/notes_state.dart';
import '../../../../core/widgets/docked_audio_player.dart';
import '../../../../core/widgets/app_bounceable.dart';
import '../../../../core/theme/app_page_route.dart';
import '../../../record/presentation/widgets/ai_processing_overlay.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../widgets/note_options_sheet.dart';

class NoteDetailScreen extends ConsumerStatefulWidget {
  final NoteModel note;
  final bool autoStartRepolish;
  final bool autoStartEdit;

  const NoteDetailScreen({
    super.key,
    required this.note,
    this.autoStartRepolish = false,
    this.autoStartEdit = false,
  });

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  int _selectedTabIndex = 0; // 0 = Polished, 1 = Raw
  int _currentAudioSecond = 0;
  final GlobalKey<DockedAudioPlayerState> _playerKey = GlobalKey<DockedAudioPlayerState>();

  late NoteModel _currentNote;
  bool _audioFileExists = true; // assume true until checked
  bool _isRepolishing = false;
  bool _isDeleting = false;
  bool _isEditing = false;
  late final TextEditingController _contentEditController;
  late final TextEditingController _titleEditController;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
    _contentEditController = TextEditingController(text: _currentNote.cleanedContent);
    _titleEditController = TextEditingController(text: _currentNote.title);

    if (widget.autoStartEdit) {
      _isEditing = true;
      _selectedTabIndex = 0;
    }

    // If note is pending offline, start on Raw Audio & Playback tab as in Stitch
    if (_currentNote.isPending) {
      _selectedTabIndex = 1;
      _checkAudioFileExists();
    }
    if (widget.autoStartRepolish) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startRepolishWithTone(_currentNote.tone, _currentNote.intensity);
      });
    }
  }

  @override
  void dispose() {
    _contentEditController.dispose();
    _titleEditController.dispose();
    super.dispose();
  }

  Future<void> _checkAudioFileExists() async {
    if (_currentNote.audioPath.isEmpty) {
      if (mounted) setState(() => _audioFileExists = false);
      return;
    }
    final exists = await File(_currentNote.audioPath).exists();
    if (mounted) setState(() => _audioFileExists = exists);
  }

  void _seekToSecond(int seconds) {
    setState(() {
      _currentAudioSecond = seconds;
    });
    _playerKey.currentState?.seekTo(seconds);
    HapticFeedback.lightImpact();
  }

  void _openNoteOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      builder: (_) => NoteOptionsSheet(
        note: _currentNote,
        onDeleteRequested: _handleDeleteNote,
        onTagsUpdated: (newTags) {
          setState(() {
            _currentNote = _currentNote.copyWith(tags: newTags);
          });
        },
        onRepolishRequested: (tone, intensity) {
          _startRepolishWithTone(tone, intensity);
        },
      ),
    );
  }

  Future<void> _handleSaveEditing() async {
    HapticFeedback.mediumImpact();
    final newContent = _contentEditController.text.trim();
    if (newContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note content cannot be empty.'),
          backgroundColor: AppColors.inkPrimary,
          behavior: SnackBarBehavior.floating,
          shape: StadiumBorder(),
        ),
      );
      return;
    }

    var newTitle = _titleEditController.text.trim();
    if (newTitle.isEmpty) newTitle = _currentNote.title;
    if (newTitle.length > 40) newTitle = newTitle.substring(0, 40);

    final updated = _currentNote.copyWith(cleanedContent: newContent, title: newTitle);
    setState(() {
      _currentNote = updated;
      _isEditing = false;
    });

    await ref.read(notesProvider.notifier).updateNote(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Note content updated successfully!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: StadiumBorder(),
        ),
      );
    }
  }

  void _handleCancelEditing() {
    final contentDirty = _contentEditController.text.trim() != _currentNote.cleanedContent.trim();
    final titleDirty = _titleEditController.text.trim() != _currentNote.title.trim();
    if (contentDirty || titleDirty) {
      showDialog(
        context: context,
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
                      Icons.edit_off_outlined,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Discard Unsaved Changes?',
                  style: GoogleFonts.newsreader(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'You have unsaved edits in this note. Are you sure you want to discard them?',
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
                    setState(() {
                      _contentEditController.text = _currentNote.cleanedContent;
                      _titleEditController.text = _currentNote.title;
                      _isEditing = false;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: AppRadii.roundedFull,
                    ),
                    child: const Center(
                      child: Text(
                        'Discard Changes',
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
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    width: double.infinity,
                    height: 44,
                    alignment: Alignment.center,
                    child: const Text(
                      'Keep Editing',
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
    } else {
      setState(() => _isEditing = false);
    }
  }



  void _startRepolish() {
    HapticFeedback.mediumImpact();
    final apiKey = ref.read(notesProvider).byokApiKey;
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add your Gemini API key in Settings first.'),
          backgroundColor: AppColors.inkPrimary,
          behavior: SnackBarBehavior.floating,
          shape: StadiumBorder(),
        ),
      );
      return;
    }
    setState(() {
      _isRepolishing = true;
    });
  }

  void _startRepolishWithTone(String tone, String intensity) {
    debugPrint('[NoteDetailScreen] _startRepolishWithTone called with tone: $tone, intensity: $intensity');
    HapticFeedback.mediumImpact();
    final apiKey = ref.read(notesProvider).byokApiKey;
    if (apiKey.isEmpty) {
      debugPrint('[NoteDetailScreen] No API key set in Settings! Cannot repolish.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please add your Gemini API key in Settings first.'),
          backgroundColor: AppColors.inkPrimary,
          behavior: SnackBarBehavior.floating,
          shape: const StadiumBorder(),
          action: SnackBarAction(
            label: 'Settings',
            textColor: AppColors.primaryLight,
            onPressed: () {
              Navigator.of(context).push(
                AppPageRoute(page: const SettingsScreen()),
              );
            },
          ),
        ),
      );
      return;
    }
    debugPrint('[NoteDetailScreen] Starting repolish overlay with apiKey: ${apiKey.substring(0, 4)}...');
    ref.read(notesProvider.notifier).updateNoteTone(_currentNote.id, tone);
    setState(() {
      _currentNote = _currentNote.copyWith(tone: tone, intensity: intensity);
      _isRepolishing = true;
    });
  }

  Future<void> _handleDeleteNote() async {
    setState(() => _isDeleting = true);
    final notesNotifier = ref.read(notesProvider.notifier);
    await Future.delayed(const Duration(milliseconds: 350));
    await notesNotifier.deleteNote(_currentNote.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDeleting) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 38,
                height: 38,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.error),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Deleting voice memo...',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.inkPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Removing audio and note data safely',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isRepolishing) {
      return AiProcessingOverlay(
        tone: _currentNote.tone,
        intensity: _currentNote.intensity,
        formattedDuration: _currentNote.formattedDuration,
        durationSeconds: _currentNote.durationSeconds,
        audioPath: _currentNote.audioPath,
        existingNote: _currentNote,
        onCancel: () {
          setState(() {
            _isRepolishing = false;
          });
        },
        onComplete: (polishedNote) {
          setState(() {
            _currentNote = polishedNote;
            _contentEditController.text = polishedNote.cleanedContent;
            _isRepolishing = false;
            _selectedTabIndex = 0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Voice memo polished successfully!'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: StadiumBorder(),
            ),
          );
        },
      );
    }

    final formattedDate = DateFormat('MMM d, h:mm a').format(_currentNote.createdAt);

    return PopScope(
      canPop: !_isEditing,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleCancelEditing();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // 1. App Bar
                  if (_isEditing)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppBounceable(
                            onTap: _handleCancelEditing,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: AppRadii.roundedFull,
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.close, size: 16, color: AppColors.inkMuted),
                                  SizedBox(width: 4),
                                  Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: TextField(
                                controller: _titleEditController,
                                maxLength: 40,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.newsreader(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.inkPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Note title…',
                                  hintStyle: GoogleFonts.newsreader(
                                    fontSize: 16,
                                    color: AppColors.inkSubtle,
                                  ),
                                  border: InputBorder.none,
                                  counterText: '',
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                          AppBounceable(
                            onTap: _handleSaveEditing,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: AppRadii.roundedFull,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.check, size: 16, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Save',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          // Back Button
                          AppBounceable(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                                boxShadow: AppShadows.card,
                              ),
                              child: const Center(
                                child: Icon(Icons.arrow_back, size: 20, color: AppColors.inkPrimary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Title & Date
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentNote.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.newsreader(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.inkPrimary,
                                  ),
                                ),
                                Text(
                                  formattedDate,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.inkMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Quick Edit Icon button
                          AppBounceable(
                            onTap: () {
                              setState(() {
                                _selectedTabIndex = 0;
                                _isEditing = true;
                                _contentEditController.text = _currentNote.cleanedContent;
                                _titleEditController.text = _currentNote.title;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.6)),
                              ),
                              child: const Icon(Icons.edit_outlined, size: 17, color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Actions: More Options
                          AppBounceable(
                            onTap: _openNoteOptions,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.more_vert, size: 20, color: AppColors.inkMuted),
                            ),
                          ),
                        ],
                      ),
                    ),

                // 2. Metadata Badges Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Tone Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadii.roundedFull,
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.business_center_outlined, size: 13, color: AppColors.inkPrimary),
                              const SizedBox(width: 5),
                              Text(
                                _currentNote.tone,
                                style: AppTypography.labelMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkPrimary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Duration Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadii.roundedFull,
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule, size: 13, color: AppColors.inkPrimary),
                              const SizedBox(width: 5),
                              Text(
                                _currentNote.formattedDuration,
                                style: AppTypography.labelMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkPrimary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Quality/Model Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadii.roundedFull,
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.graphic_eq, size: 13, color: AppColors.inkMuted),
                              const SizedBox(width: 5),
                              Text(
                                'Sandboxed Audio',
                                style: AppTypography.labelMedium.copyWith(
                                  color: AppColors.inkMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // 3. Segmented Dual Tab Switcher with Tactile Feedback
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: AppRadii.roundedFull,
                      border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Tab 1: Polished Note
                        Expanded(
                          child: AppBounceable(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() => _selectedTabIndex = 0);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _selectedTabIndex == 0 ? AppColors.primary : Colors.transparent,
                                borderRadius: AppRadii.roundedFull,
                                boxShadow: _selectedTabIndex == 0 ? AppShadows.card : null,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome,
                                        size: 15,
                                        color: _selectedTabIndex == 0 ? Colors.white : AppColors.inkMuted,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Polished Note',
                                        style: AppTypography.labelMedium.copyWith(
                                          fontWeight: _selectedTabIndex == 0 ? FontWeight.w700 : FontWeight.w500,
                                          color: _selectedTabIndex == 0 ? Colors.white : AppColors.inkMuted,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      if (_currentNote.isPending) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: AppColors.warningBg,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Pending',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.warningText,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Tab 2: Raw Transcript
                        Expanded(
                          child: AppBounceable(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() => _selectedTabIndex = 1);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _selectedTabIndex == 1 ? AppColors.primary : Colors.transparent,
                                borderRadius: AppRadii.roundedFull,
                                boxShadow: _selectedTabIndex == 1 ? AppShadows.card : null,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.mic,
                                        size: 15,
                                        color: _selectedTabIndex == 1 ? Colors.white : AppColors.inkMuted,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _currentNote.isPending ? 'Raw Audio' : 'Raw Transcript',
                                        style: AppTypography.labelMedium.copyWith(
                                          fontWeight: _selectedTabIndex == 1 ? FontWeight.w700 : FontWeight.w500,
                                          color: _selectedTabIndex == 1 ? Colors.white : AppColors.inkMuted,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. Tab Body Content
                Expanded(
                  child: _selectedTabIndex == 0
                      ? _buildPolishedTab()
                      : _buildVerbatimTab(),
                ),
              ],
            ),

            // 5. Pinned Sleek Docked Audio Player at Bottom (hidden during editing)
            if (!_isEditing)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: DockedAudioPlayer(
                  key: _playerKey,
                  totalDurationSeconds: _currentNote.durationSeconds,
                  audioPath: _currentNote.audioPath,
                  onSeek: (sec) {
                    setState(() => _currentAudioSecond = sec);
                  },
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  String _extractExecutiveSummary(String content) {
    if (content.trim().isEmpty) return 'No notes recorded yet.';

    final summaryRegex = RegExp(
      r'(?:##?\s*(?:Summary|TL;?DR|Key Takeaways|Executive Summary)[^\n]*\n+)([\s\S]*?)(?=\n+##?|\Z)',
      caseSensitive: false,
    );
    final match = summaryRegex.firstMatch(content);
    if (match != null) {
      final extracted = match.group(1)?.trim() ?? '';
      if (extracted.isNotEmpty) {
        return extracted
            .replaceAll(RegExp(r'#+\s*'), '')
            .replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m.group(1) ?? '')
            .replaceAll(r'\$', '')
            .trim();
      }
    }

    final cleanLines = content
        .split('\n')
        .where((line) => !line.trim().startsWith('#') && line.trim().isNotEmpty)
        .join(' ')
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1')
        .replaceAll(r'\$', '')
        .trim();

    if (cleanLines.isEmpty) return 'Voice memo captured and preserved.';

    final sentences = RegExp(r'[^.!?]+[.!?]')
        .allMatches(cleanLines)
        .map((m) => m.group(0)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    if (sentences.length >= 2) {
      return '${sentences[0]} ${sentences[1]}';
    } else if (sentences.isNotEmpty) {
      return sentences.first;
    }
    return cleanLines.length > 180 ? '${cleanLines.substring(0, 180)}...' : cleanLines;
  }

  Widget _buildExecutiveSummaryCard() {
    final summary = _extractExecutiveSummary(_currentNote.cleanedContent);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F4),
        borderRadius: AppRadii.roundedLg,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.peachTint,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'EXECUTIVE SUMMARY',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadii.roundedFull,
                ),
                child: Text(
                  'TL;DR',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summary,
            style: GoogleFonts.newsreader(
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              height: 1.45,
              color: AppColors.inkPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolishedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Executive Summary & TL;DR Card (Always visible at top of polished tab when not editing)
          if (!_isEditing) _buildExecutiveSummaryCard(),

          // Offline Banner (if note is pending)
          if (_currentNote.isPending) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: AppRadii.roundedLg,
                border: Border.all(color: AppColors.warningBorder, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _audioFileExists
                              ? AppColors.peachTint
                              : AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _audioFileExists ? Icons.cloud_off : Icons.delete_outline,
                          size: 20,
                          color: _audioFileExists ? AppColors.primary : AppColors.error,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _audioFileExists
                                  ? 'Audio Saved Locally • Offline'
                                  : 'Audio File Deleted',
                              style: AppTypography.labelLarge.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _audioFileExists
                                    ? AppColors.warningText
                                    : AppColors.error,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _audioFileExists
                                  ? 'Your ${_currentNote.formattedDuration} recording is safe on your phone.'
                                  : 'The audio was cleared from cache. Re-record to polish this note.',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_audioFileExists)
                    AppBounceable(
                      onTap: _startRepolish,
                      child: Container(
                        width: double.infinity,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: AppRadii.roundedFull,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh, size: 18, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Retry AI Polish',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: AppRadii.roundedFull,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mic, size: 18, color: AppColors.inkMuted),
                          const SizedBox(width: 6),
                          Text(
                            'Re-record to Polish',
                            style: TextStyle(
                              color: AppColors.inkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],


          // Editorial Note Canvas (or Editor when in edit mode)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.roundedLg,
              border: Border.all(
                color: _isEditing ? AppColors.primary.withValues(alpha: 0.7) : AppColors.borderSubtle,
                width: _isEditing ? 1.5 : 1,
              ),
              boxShadow: _isEditing
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : AppShadows.card,
            ),
            child: _isEditing
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.edit_note, size: 17, color: AppColors.primary),
                              SizedBox(width: 6),
                              Text(
                                'EDITING NOTE CONTENT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Markdown',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.inkMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _contentEditController,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        autofocus: true,
                        style: GoogleFonts.newsreader(
                          fontSize: 17,
                          height: 1.6,
                          color: AppColors.inkPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Type or edit note content in markdown...',
                          hintStyle: TextStyle(color: AppColors.inkSubtle, fontSize: 15),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  )
                : MarkdownBody(
                    data: _currentNote.cleanedContent,
                    styleSheet: MarkdownStyleSheet(
                      p: AppTypography.bodyLarge.copyWith(
                        height: 1.62,
                        color: AppColors.inkPrimary,
                      ),
                      h1: GoogleFonts.newsreader(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: AppColors.inkPrimary,
                      ),
                      h2: GoogleFonts.newsreader(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: AppColors.inkPrimary,
                      ),
                      h3: GoogleFonts.newsreader(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkPrimary,
                      ),
                      listBullet: AppTypography.bodyLarge.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        border: const Border(left: BorderSide(color: AppColors.primary, width: 3.5)),
                        color: AppColors.primaryTint.withValues(alpha: 0.45),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      blockquotePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerbatimTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Audio Overview Card with Mini Waveform
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.roundedMd,
              border: Border.all(color: AppColors.borderSubtle),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: AppColors.peachTint,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.graphic_eq, size: 14, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Verbatim Audio Map',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.inkPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_currentNote.timestamps.length} synchronized chunks',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Section Header
          Text(
            'Synchronized Verbatim Transcript',
            style: GoogleFonts.newsreader(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.inkPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Tap any timestamp to jump audio playback instantly',
            style: AppTypography.labelMedium.copyWith(color: AppColors.inkMuted),
          ),

          const SizedBox(height: 14),

          // Paragraph Chunks
          if (_currentNote.timestamps.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.roundedMd,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Text(
                _currentNote.verbatimTranscript,
                style: AppTypography.bodyLarge.copyWith(height: 1.6),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _currentNote.timestamps.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final chunk = _currentNote.timestamps[index];
                final isActive = _currentAudioSecond >= chunk.timeSeconds &&
                    (index == _currentNote.timestamps.length - 1 ||
                        _currentAudioSecond < _currentNote.timestamps[index + 1].timeSeconds);

                return AppBounceable(
                  behavior: HitTestBehavior.opaque,
                  scaleFactor: 0.98,
                  onTap: () => _seekToSecond(chunk.timeSeconds),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFFAF2EE) : AppColors.surface,
                      borderRadius: AppRadii.roundedMd,
                      border: Border.all(
                        color: isActive
                            ? AppColors.primary.withValues(alpha: 0.6)
                            : AppColors.borderSubtle,
                        width: isActive ? 1.5 : 1,
                      ),
                      boxShadow: isActive ? AppShadows.card : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Clickable Timestamp Seek Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive ? AppColors.primary : AppColors.surfaceContainer,
                                borderRadius: AppRadii.roundedFull,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isActive ? Icons.volume_up : Icons.play_arrow,
                                    size: 13,
                                    color: isActive ? Colors.white : AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    chunk.formattedTime,
                                    style: AppTypography.labelSmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: isActive ? Colors.white : AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isActive)
                              Text(
                                'NOW PLAYING',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              )
                            else
                              Text(
                                'Take ${index + 1}',
                                style: AppTypography.labelSmall.copyWith(color: AppColors.inkSubtle),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          chunk.text,
                          style: AppTypography.bodyLarge.copyWith(
                            height: 1.62,
                            color: AppColors.inkPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
