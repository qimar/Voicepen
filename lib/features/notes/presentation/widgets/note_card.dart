import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/models/note_model.dart';
import '../../../../core/widgets/app_bounceable.dart';

class NoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onMoreTap,
  });

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays == 0) {
      return 'Today, ${DateFormat('h:mm a').format(dt)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${DateFormat('h:mm a').format(dt)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(dt);
    }
  }

  IconData _getToneIcon(String tone) {
    switch (tone) {
      case 'Executive Memo':
        return Icons.business_center_outlined;
      case 'Casual Email':
        return Icons.mail_outline;
      case 'Bullet Points':
      case 'Bullet Summary':
        return Icons.format_list_bulleted;
      case 'Brain Dump':
      case 'Idea Dump':
        return Icons.lightbulb_outline;
      case 'Twitter / X Post':
        return Icons.tag;
      case 'Actionable To-Do':
        return Icons.check_circle_outline;
      case 'Story / Journal':
        return Icons.menu_book_outlined;
      default:
        return Icons.auto_awesome;
    }
  }

  String _cleanExcerpt(String content) {
    // Strip markdown headings, bold, italic, bullets, and literal \$ from multiline strings
    final cleaned = content
        .replaceAll(RegExp(r'#+\s*'), '')
        .replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'\*([^*]+)\*'), (m) => m.group(1) ?? '')
        .replaceAll(RegExp(r'^\s*\d+\.\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[-*]\s*', multiLine: true), '')
        .replaceAll(r'\$', '')      // strip literal \$ escape sequences
        .replaceAll(RegExp(r'\n+'), ' ')
        .trim();
    return cleaned.isNotEmpty ? cleaned : 'Voice note preview...';
  }

  @override
  Widget build(BuildContext context) {
    return AppBounceable(
      onTap: onTap,
      scaleFactor: 0.98,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.roundedMd,
          border: Border.all(color: AppColors.borderSubtle, width: 1),
          boxShadow: AppShadows.card,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (note.isPinned) ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 2.0),
                      child: Icon(Icons.push_pin, size: 15, color: AppColors.primary),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      note.title,
                      style: GoogleFonts.newsreader(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: AppColors.inkPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onMoreTap,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8.0, bottom: 4.0),
                      child: Icon(Icons.more_vert, size: 20, color: AppColors.inkMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Clean Excerpt (line-clamp-2)
              Text(
                _cleanExcerpt(note.cleanedContent),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium.copyWith(
                  height: 1.45,
                  color: AppColors.inkMuted.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 12),
              // Subtle Hairline Divider
              Container(
                height: 1,
                color: AppColors.borderSubtle.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 10),
              // Responsive Metadata Footer Row (Hardened against overflows)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Timestamp on left (Expanded so it claims all space after badges)
                  Expanded(
                    child: Text(
                      _formatTimestamp(note.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.inkSubtle,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Badges on right
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Duration Capsule
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: AppRadii.roundedFull,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule, size: 12, color: AppColors.inkMuted),
                            const SizedBox(width: 3),
                            Text(
                              note.formattedDuration,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.inkMuted,
                                fontWeight: FontWeight.w500,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      // Tone Badge or Offline Pending Pill
                      if (note.isPending)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.warningBg,
                            borderRadius: AppRadii.roundedFull,
                            border: Border.all(color: AppColors.warningBorder, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off, size: 12, color: AppColors.warningIcon),
                              const SizedBox(width: 3),
                              Text(
                                'Offline',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.warningText,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: AppRadii.roundedFull,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getToneIcon(note.tone),
                                size: 12,
                                color: AppColors.primaryDark,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                note.tone,
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
