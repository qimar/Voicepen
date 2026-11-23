import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/models/note_model.dart';
import '../../../../core/state/notes_state.dart';
import '../../../../core/widgets/app_bounceable.dart';
import 'share_bottom_sheet.dart';
import '../../../record/presentation/widgets/tone_bottom_sheet.dart';

class NoteOptionsSheet extends ConsumerWidget {
  final NoteModel note;
  final VoidCallback? onDeleteRequested;
  final void Function(String tone, String intensity)? onRepolishRequested;
  final void Function(List<String> tags)? onTagsUpdated;

  const NoteOptionsSheet({
    super.key,
    required this.note,
    this.onDeleteRequested,
    this.onRepolishRequested,
    this.onTagsUpdated,
  });

  void _showEditTagsSheet(BuildContext context, NotesNotifier notesNotifier) {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      builder: (ctx) => _EditTagsBottomSheet(
        initialTags: note.tags,
        onSave: (newTags) {
          notesNotifier.updateNote(note.copyWith(tags: newTags));
          onTagsUpdated?.call(newTags);
          messenger.showSnackBar(
            const SnackBar(
              content: Text('✓ Note tags updated successfully'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: StadiumBorder(),
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, NotesNotifier notesNotifier) {
    showDialog(
      context: context,
      barrierColor: AppColors.scrim,
      builder: (dialogCtx) => Dialog(
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
                  color: AppColors.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Delete Voice Memo?',
                style: GoogleFonts.newsreader(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This will permanently remove the polished note, transcript, and audio recording from your device.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.inkMuted,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              AppBounceable(
                onTap: () {
                  Navigator.of(dialogCtx).pop();
                  if (onDeleteRequested != null) {
                    onDeleteRequested!();
                  } else {
                    notesNotifier.deleteNote(note.id);
                  }
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
                      'Delete Memo',
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
                onTap: () => Navigator.of(dialogCtx).pop(),
                child: Container(
                  width: double.infinity,
                  height: 44,
                  alignment: Alignment.center,
                  child: const Text(
                    'Cancel',
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
  Widget build(BuildContext context, WidgetRef ref) {
    final formattedDate = DateFormat('MMM d, yyyy').format(note.createdAt);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadii.bottomSheet,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Drag Handle Pill
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Header Section matching Stitch HTML
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.tune, size: 13, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                'NOTE OPTIONS',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.newsreader(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 12, color: AppColors.inkMuted),
                              const SizedBox(width: 4),
                              Text(
                                'Created $formattedDate',
                                style: AppTypography.labelSmall.copyWith(color: AppColors.inkMuted, fontSize: 11),
                              ),
                              const SizedBox(width: 6),
                              Container(width: 3, height: 3, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary)),
                              const SizedBox(width: 6),
                              Text(
                                '${note.formattedDuration} audio master',
                                style: AppTypography.labelSmall.copyWith(color: AppColors.inkMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    AppBounceable(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.close, size: 18, color: AppColors.inkMuted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: AppColors.borderSubtle, height: 20),

              // Action Items List matching Stitch
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [


                    // Row 1.5: Edit Tags
                    _buildOptionTile(
                      icon: Icons.label_outline,
                      iconBg: AppColors.peachTint,
                      iconColor: AppColors.primary,
                      title: 'Edit Tags',
                      subtitle: note.tags.isEmpty
                          ? 'Assign tags to organize'
                          : note.tags.map((t) => '#$t').join('  '),
                      trailingBadge: '${note.tags.length} tags',
                      onTap: () {
                        final notesNotifier = ref.read(notesProvider.notifier);
                        Navigator.of(context).pop();
                        _showEditTagsSheet(context, notesNotifier);
                      },
                    ),
                    const SizedBox(height: 8),

                    // Row 2: Pin / Unpin
                    _buildOptionTile(
                      icon: note.isPinned ? Icons.push_pin : Icons.star_border,
                      iconBg: const Color(0xFFFFF3E0),
                      iconColor: const Color(0xFFD97706),
                      title: note.isPinned ? 'Remove from Favorites' : 'Add to Favorites',
                      subtitle: note.isPinned ? 'Unpin from top of Vault' : 'Pin to top of your Notes Vault',
                      trailingBadge: note.isPinned ? 'Pinned' : 'Pin',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        final notesNotifier = ref.read(notesProvider.notifier);
                        notesNotifier.togglePin(note.id);
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(height: 8),

                    // Row 3: Re-polish with new Tone
                    _buildOptionTile(
                      icon: Icons.autorenew,
                      iconBg: const Color(0xFFE8EFE9),
                      iconColor: const Color(0xFF2E6347),
                      title: 'Re-polish Note',
                      subtitle: 'Choose a different tone or intensity',
                      trailingBadge: 'AI Polish',
                      onTap: () {
                        final nav = Navigator.of(context);
                        nav.pop();
                        showModalBottomSheet(
                          context: nav.context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          backgroundColor: Colors.transparent,
                          barrierColor: AppColors.scrim,
                          builder: (_) => ToneBottomSheet(
                            currentTone: note.tone,
                            currentIntensity: note.intensity,
                            isRepolishing: true,
                            onApply: (tone, intensity) {
                              debugPrint('[NoteOptionsSheet] onApply called with tone: $tone, intensity: $intensity');
                              onRepolishRequested?.call(tone, intensity);
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    // Row 4: Share / Export
                    _buildOptionTile(
                      icon: Icons.share_outlined,
                      iconBg: AppColors.peachTint,
                      iconColor: AppColors.primaryDark,
                      title: 'Export / Share Note',
                      subtitle: 'Copy Markdown, Plain text, or share to apps',
                      onTap: () {
                        Navigator.of(context).pop();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          barrierColor: AppColors.scrim,
                          builder: (_) => ShareBottomSheet(note: note),
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    // Row 5: Destructive Delete
                    _buildOptionTile(
                      icon: Icons.delete_forever_outlined,
                      iconBg: AppColors.errorContainer,
                      iconColor: AppColors.error,
                      title: 'Delete Note & Audio',
                      subtitle: 'Removes local recording permanently',
                      isDestructive: true,
                      onTap: () {
                        final notesNotifier = ref.read(notesProvider.notifier);
                        Navigator.of(context).pop();
                        _showDeleteDialog(context, notesNotifier);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Cancel Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppBounceable(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadii.roundedFull,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: const Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppColors.inkMuted,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? trailingBadge,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return AppBounceable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isDestructive ? const Color(0xFFFFF5F5) : AppColors.surface,
          borderRadius: AppRadii.roundedMd,
          border: Border.all(
            color: isDestructive ? const Color(0xFFFAD2D2) : AppColors.borderSubtle,
            width: 1,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.labelLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? AppColors.error : AppColors.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.labelSmall.copyWith(
                      color: isDestructive
                          ? AppColors.error.withValues(alpha: 0.8)
                          : AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (trailingBadge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.peachTint,
                  borderRadius: AppRadii.roundedFull,
                ),
                child: Text(
                  trailingBadge,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right,
                size: 20,
                color: isDestructive ? AppColors.error.withValues(alpha: 0.7) : AppColors.inkSubtle,
              ),
          ],
        ),
      ),
    );
  }
}

class _EditTagsBottomSheet extends StatefulWidget {
  final List<String> initialTags;
  final ValueChanged<List<String>> onSave;

  const _EditTagsBottomSheet({
    required this.initialTags,
    required this.onSave,
  });

  @override
  State<_EditTagsBottomSheet> createState() => _EditTagsBottomSheetState();
}

class _EditTagsBottomSheetState extends State<_EditTagsBottomSheet> {
  late final List<String> _tags;
  final TextEditingController _tagController = TextEditingController();

  static const List<String> _suggestedTags = [
    'Ideas',
    'Work',
    'Meetings',
    'Personal',
    'Tasks',
    'Journal',
    'Project',
    'Study',
  ];

  @override
  void initState() {
    super.initState();
    _tags = List<String>.from(widget.initialTags);
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  void _addTag(String raw) {
    var tag = raw.trim().replaceAll('#', '');
    if (tag.isEmpty) return;
    if (tag.length > 20) tag = tag.substring(0, 20);

    // Normalize: capitalize first letter
    tag = tag[0].toUpperCase() + tag.substring(1);

    if (!_tags.any((t) => t.toLowerCase() == tag.toLowerCase())) {
      HapticFeedback.lightImpact();
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    } else {
      _tagController.clear();
    }
  }

  void _removeTag(String tag) {
    HapticFeedback.lightImpact();
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.85,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadii.bottomSheet,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Header Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Note Tags',
                          style: GoogleFonts.newsreader(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Categorize this voice memo with searchable tags',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppBounceable(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.close, size: 18, color: AppColors.inkMuted),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.borderSubtle, height: 16),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tag Input Field Row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 46,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppRadii.roundedFull,
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  '#',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextField(
                                    controller: _tagController,
                                    maxLength: 20,
                                    style: const TextStyle(fontSize: 14, color: AppColors.inkPrimary),
                                    decoration: const InputDecoration(
                                      hintText: 'Enter new tag name...',
                                      hintStyle: TextStyle(color: AppColors.inkSubtle, fontSize: 13),
                                      border: InputBorder.none,
                                      counterText: '',
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onSubmitted: _addTag,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppBounceable(
                          onTap: () => _addTag(_tagController.text),
                          child: Container(
                            height: 46,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: AppRadii.roundedFull,
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add, size: 16, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Add',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Active Tags Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ASSIGNED TAGS (${_tags.length})',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.inkMuted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        if (_tags.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() => _tags.clear()),
                            child: Text(
                              'Clear All',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Active Tags Chips
                    if (_tags.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: AppColors.inkSubtle),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'No tags assigned yet. Tap a suggestion or type one above.',
                                style: AppTypography.labelSmall.copyWith(color: AppColors.inkMuted),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
                            decoration: BoxDecoration(
                              color: AppColors.peachTint,
                              borderRadius: AppRadii.roundedFull,
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '#$tag',
                                  style: AppTypography.labelMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _removeTag(tag),
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.close, size: 12, color: AppColors.primaryDark),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 24),

                    // Suggested Tags Section
                    Text(
                      'SUGGESTIONS',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestedTags.map((suggestion) {
                        final isAlreadyAdded = _tags.any(
                          (t) => t.toLowerCase() == suggestion.toLowerCase(),
                        );

                        return AppBounceable(
                          onTap: isAlreadyAdded ? null : () => _addTag(suggestion),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isAlreadyAdded
                                  ? AppColors.surfaceContainerLow
                                  : AppColors.surface,
                              borderRadius: AppRadii.roundedFull,
                              border: Border.all(
                                color: isAlreadyAdded
                                    ? AppColors.borderSubtle.withValues(alpha: 0.4)
                                    : AppColors.borderSubtle,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isAlreadyAdded ? Icons.check : Icons.add,
                                  size: 13,
                                  color: isAlreadyAdded ? AppColors.inkSubtle : AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '#$suggestion',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: isAlreadyAdded ? AppColors.inkSubtle : AppColors.inkPrimary,
                                    fontWeight: isAlreadyAdded ? FontWeight.w500 : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Pinned Bottom Save Button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: AppBounceable(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  widget.onSave(_tags);
                  Navigator.of(context).pop();
                },
                child: Container(
                  height: 50,
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
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Apply & Save Tags',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
