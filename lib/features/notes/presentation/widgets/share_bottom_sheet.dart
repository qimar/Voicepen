import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_page_route.dart';
import '../../../../core/models/note_model.dart';
import '../../../../core/state/notes_state.dart';
import '../../../../core/widgets/app_bounceable.dart';
import '../../../monetization/presentation/screens/paywall_screen.dart';

class ShareBottomSheet extends ConsumerWidget {
  final NoteModel note;

  const ShareBottomSheet({
    super.key,
    required this.note,
  });

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.inkPrimary,
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareExternal(BuildContext context) {
    Navigator.of(context).pop();
    final shareContent = '''# ${note.title}

${note.cleanedContent}

---
Transcribed & polished with VoicePen''';
    SharePlus.instance.share(
      ShareParams(text: shareContent, subject: note.title),
    );
  }

  Future<pw.Document> _buildPdfDocument() async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'VoicePen',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.brown800,
                    ),
                  ),
                  pw.Text(
                    note.createdAt.toIso8601String().split('T').first,
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              note.title,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                pw.Text(
                  'Tone: ${note.tone}  |  Duration: ${note.formattedDuration}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 12),
            pw.Paragraph(
              text: note.cleanedContent,
              style: pw.TextStyle(
                fontSize: 12,
                lineSpacing: 3,
                color: PdfColors.grey900,
              ),
            ),
            if (note.verbatimTranscript.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Text(
                'ORIGINAL TRANSCRIPT',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey500,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Paragraph(
                text: note.verbatimTranscript,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey700,
                  lineSpacing: 2,
                ),
              ),
            ],
          ];
        },
      ),
    );
    return doc;
  }

  Future<void> _exportPdf(BuildContext context) async {
    Navigator.of(context).pop();
    try {
      final doc = await _buildPdfDocument();
      final bytes = await doc.save();
      final sanitizedTitle = note.title.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
      final fileName = '${sanitizedTitle.isEmpty ? "voicepen_note" : sanitizedTitle}.pdf';
      await Printing.sharePdf(
        bytes: bytes,
        filename: fileName,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: AppColors.inkPrimary,
            behavior: SnackBarBehavior.floating,
            shape: const StadiumBorder(),
          ),
        );
      }
    }
  }

  Future<void> _printDirect(BuildContext context) async {
    Navigator.of(context).pop();
    try {
      final doc = await _buildPdfDocument();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print document: $e'),
            backgroundColor: AppColors.inkPrimary,
            behavior: SnackBarBehavior.floating,
            shape: const StadiumBorder(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(notesProvider).isProUser;

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

              // Header Section matching Stitch
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Share & Export Note',
                            style: GoogleFonts.newsreader(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.description_outlined, size: 13, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${note.title} • ${note.formattedDuration}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.inkMuted,
                                  ),
                                ),
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

              // Options List
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Export Formatted PDF (Pro Gated)
                    _buildShareTile(
                      icon: Icons.picture_as_pdf_outlined,
                      iconBg: const Color(0xFFFFEBEE),
                      iconColor: const Color(0xFFC62828),
                      title: 'Export Formatted PDF',
                      subtitle: 'Styled PDF with metadata & transcript',
                      isProOnly: true,
                      isProUser: isPro,
                      onTap: () {
                        if (!isPro) {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(AppPageRoute(page: const PaywallScreen()));
                        } else {
                          _exportPdf(context);
                        }
                      },
                    ),
                    const SizedBox(height: 8),

                    // Copy Formatted Markdown
                    _buildShareTile(
                      icon: Icons.code,
                      iconBg: AppColors.peachTint,
                      iconColor: AppColors.primary,
                      title: 'Copy Formatted Markdown',
                      subtitle: 'Clean headers, lists, and formatting',
                      onTap: () => _copyToClipboard(
                        context,
                        '# ${note.title}\n\n${note.cleanedContent}',
                        'Copied Formatted Markdown to clipboard',
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Copy Plain Text
                    _buildShareTile(
                      icon: Icons.content_copy,
                      iconBg: AppColors.surfaceContainer,
                      iconColor: AppColors.inkPrimary,
                      title: 'Copy Plain Text',
                      subtitle: 'Raw text without markdown tags',
                      onTap: () {
                        final plain = note.cleanedContent
                            .replaceAll(RegExp(r'#+\s*'), '')
                            .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
                            .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
                        _copyToClipboard(
                          context,
                          '${note.title}\n\n$plain',
                          'Copied Plain Text to clipboard',
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    // Export Audio Recording
                    _buildShareTile(
                      icon: Icons.graphic_eq,
                      iconBg: AppColors.peachTint,
                      iconColor: AppColors.primary,
                      title: 'Export Audio Recording',
                      subtitle: 'Original .m4a audio master (${note.formattedDuration})',
                      trailingIcon: Icons.download_outlined,
                      onTap: () async {
                        Navigator.of(context).pop();
                        if (note.audioPath.isNotEmpty && await File(note.audioPath).exists()) {
                          try {
                            await SharePlus.instance.share(
                              ShareParams(
                                files: [XFile(note.audioPath)],
                                subject: '${note.title} (Audio Recording)',
                              ),
                            );
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Could not open audio share dialog.'),
                                  backgroundColor: AppColors.inkPrimary,
                                  behavior: SnackBarBehavior.floating,
                                  shape: StadiumBorder(),
                                ),
                              );
                            }
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Audio recording is not available on this device.'),
                                backgroundColor: AppColors.inkPrimary,
                                behavior: SnackBarBehavior.floating,
                                shape: StadiumBorder(),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              // ),
              // const SizedBox(height: 10),

              // // App Icons Row
              // Padding(
              //   padding: const EdgeInsets.symmetric(horizontal: 16),
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.spaceAround,
              //     children: [
              //       _buildAppIcon(
              //         label: 'WhatsApp',
              //         icon: Icons.chat_bubble_outline,
              //         bgColor: const Color(0xFFE8F5E9),
              //         iconColor: const Color(0xFF2E7D32),
              //         onTap: () => _shareExternal(context),
              //       ),
              //       _buildAppIcon(
              //         label: 'Gmail',
              //         icon: Icons.mail_outline,
              //         bgColor: const Color(0xFFFFEBEE),
              //         iconColor: const Color(0xFFC62828),
              //         onTap: () => _shareExternal(context),
              //       ),
              //       _buildAppIcon(
              //         label: 'Slack',
              //         icon: Icons.tag,
              //         bgColor: const Color(0xFFF3E5F5),
              //         iconColor: const Color(0xFF6A1B9A),
              //         onTap: () => _shareExternal(context),
              //       ),
              //       _buildAppIcon(
              //         label: 'Drive',
              //         icon: Icons.add_to_drive,
              //         bgColor: const Color(0xFFFFF8E1),
              //         iconColor: const Color(0xFFF57F17),
              //         onTap: () => _shareExternal(context),
              //       ),
              //       _buildAppIcon(
              //         label: 'More...',
              //         icon: Icons.more_horiz,
              //         bgColor: AppColors.surfaceContainer,
              //         iconColor: AppColors.inkMuted,
              //         onTap: () => _shareExternal(context),
              //       ),
              //     ],
              //   ),
              // ),

              // const SizedBox(height: 20),

              // Bottom Actions: Copy Secret Link + Print Icon
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: AppBounceable(
                        onTap: () => _shareExternal(context),
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
                              Icon(Icons.link, size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Share Note to Apps',
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
                    const SizedBox(width: 10),
                    AppBounceable(
                      onTap: () {
                        if (!isPro) {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(AppPageRoute(page: const PaywallScreen()));
                        } else {
                          _printDirect(context);
                        }
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadii.roundedFull,
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Center(
                          child: Icon(
                            isPro ? Icons.print_outlined : Icons.lock_outline,
                            size: 20,
                            color: isPro ? AppColors.inkPrimary : AppColors.primary,
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
      ),
    );
  }

  Widget _buildShareTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    IconData trailingIcon = Icons.chevron_right,
    bool isProOnly = false,
    bool isProUser = true,
    required VoidCallback onTap,
  }) {
    return AppBounceable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.roundedMd,
          border: Border.all(color: AppColors.borderSubtle, width: 1),
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: AppTypography.labelLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkPrimary,
                          ),
                        ),
                      ),
                      if (isProOnly && !isProUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.peachTint,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              (isProOnly && !isProUser) ? Icons.lock_outline : trailingIcon,
              size: 20,
              color: (isProOnly && !isProUser) ? AppColors.primary : AppColors.inkSubtle,
            ),
          ],
        ),
      ),
    );
  }
}
