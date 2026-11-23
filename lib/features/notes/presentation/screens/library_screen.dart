import '../../../../core/services/cloud_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_page_route.dart';
import '../../../../core/state/notes_state.dart';
import '../../../../core/models/note_model.dart';
import '../../../../core/widgets/app_bounceable.dart';
import '../widgets/note_card.dart';
import '../widgets/library_empty_state.dart';
import '../widgets/note_options_sheet.dart';
import 'note_detail_screen.dart';
import '../../../record/presentation/screens/record_screen.dart';
import '../../../record/presentation/widgets/ai_processing_overlay.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../monetization/presentation/screens/paywall_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Initial background sync with Supabase cloud
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notesProvider.notifier).syncWithCloud();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _openNote(NoteModel note) {
    Navigator.of(context).push(
      AppPageRoute(page: NoteDetailScreen(note: note)),
    );
  }

  void _openRecord() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      AppPageRoute(page: const RecordScreen()),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      AppPageRoute(page: const SettingsScreen()),
    );
  }

  void _openPaywall() {
    Navigator.of(context).push(
      AppPageRoute(page: const PaywallScreen()),
    );
  }

  Future<void> _importAudioFile() async {
    final isPro = ref.read(notesProvider).isProUser;
    if (!isPro) {
      HapticFeedback.lightImpact();
      _openPaywall();
      return;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m4a', 'mp3', 'wav', 'aac', 'ogg', 'mp4'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        if (!mounted) return;

        debugPrint('[LibraryScreen] Audio file picked: $filePath');
        // Probe real audio duration with just_audio
        final probePlayer = AudioPlayer();
        int probedSeconds = 0;
        try {
          final dur = await probePlayer.setFilePath(filePath);
          if (dur != null && dur.inSeconds > 0) {
            probedSeconds = dur.inSeconds;
          }
        } catch (e) {
          debugPrint('[LibraryScreen] Error probing audio duration: $e');
        } finally {
          await probePlayer.dispose();
        }

        final m = (probedSeconds ~/ 60).toString().padLeft(2, '0');
        final s = (probedSeconds % 60).toString().padLeft(2, '0');
        final formattedDur = probedSeconds > 0 ? '$m:$s' : '00:01';
        final durSeconds = probedSeconds > 0 ? probedSeconds : 1;
        debugPrint('[LibraryScreen] Probed duration: $durSeconds s ($formattedDur)');

        if (!mounted) return;

        // Push directly to processing overlay
        Navigator.of(context).push(
          AppPageRoute(
            page: AiProcessingOverlay(
              tone: 'Clear & Concise',
              intensity: 'Medium',
              formattedDuration: formattedDur,
              durationSeconds: durSeconds,
              audioPath: filePath,
              onComplete: (newNote) {
                Navigator.of(context).pushReplacement(
                  AppPageRoute(page: NoteDetailScreen(note: newNote)),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[LibraryScreen] FilePicker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not access selected audio file.'),
            backgroundColor: AppColors.inkPrimary,
            behavior: SnackBarBehavior.floating,
            shape: StadiumBorder(),
          ),
        );
      }
    }
  }

  void _showNoteOptions(NoteModel note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      builder: (_) => NoteOptionsSheet(
        note: note,
        onRepolishRequested: (tone, intensity) {
          debugPrint('[LibraryScreen] onRepolishRequested: tone: $tone, intensity: $intensity');
          final updatedNote = note.copyWith(tone: tone, intensity: intensity);
          Navigator.of(context).push(
            AppPageRoute(
              page: NoteDetailScreen(
                note: updatedNote,
                autoStartRepolish: true,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesState = ref.watch(notesProvider);
    final filteredNotes = notesState.filteredNotes;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // 1. Top App Bar matching Stitch
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Brand Italic Title
                      Text(
                        'VoicePen',
                        style: GoogleFonts.newsreader(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          color: AppColors.inkPrimary,
                        ),
                      ),
                      // Actions: Sync Badge + Import Audio + Settings Gear
                      Row(
                        children: [
                          Consumer(
                            builder: (context, ref, _) {
                              final isSyncing = ref.watch(syncStatusProvider);
                              return AppBounceable(
                                onTap: () async {
                                  HapticFeedback.lightImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Syncing with VoicePen Cloud...'),
                                      backgroundColor: AppColors.primary,
                                      duration: Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                      shape: StadiumBorder(),
                                    ),
                                  );
                                  await ref.read(notesProvider.notifier).syncWithCloud();
                                },
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.borderSubtle),
                                  ),
                                  child: Center(
                                    child: isSyncing
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.cloud_done_outlined,
                                            size: 19,
                                            color: AppColors.primary,
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          AppBounceable(
                            onTap: _importAudioFile,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              child: const Center(
                                child: Icon(Icons.file_upload_outlined, size: 20, color: AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          AppBounceable(
                            onTap: _openSettings,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(shape: BoxShape.circle),
                              child: const Center(
                                child: Icon(Icons.settings, size: 22, color: AppColors.inkMuted),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Search & Tag Filters
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Search Input (Warm rounded pill capsule)
                      Container(
                        height: 50,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: AppColors.borderSubtle.withValues(alpha: 0.8),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.inkPrimary.withValues(alpha: 0.05),
                              offset: const Offset(0, 3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) =>
                              ref.read(notesProvider.notifier).setSearchQuery(val),
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.inkPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search notes or transcripts...',
                            hintStyle: AppTypography.bodyMedium.copyWith(
                              color: AppColors.inkSubtle,
                            ),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(left: 14, right: 10),
                              child: Icon(
                                Icons.search,
                                size: 21,
                                color: AppColors.inkSubtle,
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 46),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      ref.read(notesProvider.notifier).setSearchQuery('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Horizontal Tag Chips Row
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: notesState.availableTags.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final tag = notesState.availableTags[index];
                            final isSelected = notesState.selectedTag == tag;

                            int count = 0;
                            if (tag == 'All') {
                              count = notesState.notes.length;
                            } else {
                              count = notesState.notes
                                  .where((n) => n.tags.contains(tag))
                                  .length;
                            }

                            final label = tag == 'All' ? 'All ($count)' : '#$tag ($count)';

                            return AppBounceable(
                              onTap: () {
                                ref.read(notesProvider.notifier).setSelectedTag(tag);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : AppColors.surface,
                                  borderRadius: AppRadii.roundedFull,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.borderSubtle,
                                    width: 1,
                                  ),
                                  boxShadow: isSelected ? AppShadows.card : null,
                                ),
                                child: Center(
                                  child: Text(
                                    label,
                                    style: AppTypography.labelMedium.copyWith(
                                      color: isSelected ? Colors.white : AppColors.inkMuted,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 3. Notes List or Empty State with Pull-to-Refresh Cloud Sync
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    onRefresh: () async {
                      await ref.read(notesProvider.notifier).syncWithCloud();
                    },
                    child: filteredNotes.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.55,
                              child: const LibraryEmptyState(),
                            ),
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(
                              left: 20,
                              right: 20,
                              top: 8,
                              bottom: 120, // generous bottom padding for floating FAB
                            ),
                            itemCount: filteredNotes.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final note = filteredNotes[index];
                              return NoteCard(
                                note: note,
                                onTap: () => _openNote(note),
                                onMoreTap: () => _showNoteOptions(note),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),

            // 4. Floating Action Button (FAB) matching Stitch with ambient glow
            Positioned(
              bottom: 24,
              right: 20,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ambient Terracotta Glow Ring
                      Container(
                        width: 60 + (_pulseController.value * 14),
                        height: 60 + (_pulseController.value * 14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(
                            alpha: 0.18 * (1.0 - _pulseController.value),
                          ),
                        ),
                      ),
                      // Core FAB Button with spring bounce
                      AppBounceable(
                        onTap: _openRecord,
                        scaleFactor: 0.92,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: AppShadows.fab,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.mic,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
