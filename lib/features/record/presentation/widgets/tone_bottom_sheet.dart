import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_page_route.dart';
import '../../../../core/constants/tone_presets.dart';
import '../../../../core/widgets/app_bounceable.dart';
import '../../../../core/state/notes_state.dart';
import '../../../monetization/presentation/screens/paywall_screen.dart';

class ToneBottomSheet extends ConsumerStatefulWidget {
  final String currentTone;
  final String currentIntensity;
  final bool isRepolishing;
  final Function(String tone, String intensity) onApply;

  const ToneBottomSheet({
    super.key,
    required this.currentTone,
    required this.currentIntensity,
    this.isRepolishing = true,
    required this.onApply,
  });

  @override
  ConsumerState<ToneBottomSheet> createState() => _ToneBottomSheetState();
}

class _ToneBottomSheetState extends ConsumerState<ToneBottomSheet> {
  late String _selectedTone;
  late String _selectedIntensity;

  @override
  void initState() {
    super.initState();
    _selectedTone = widget.currentTone;
    _selectedIntensity = widget.currentIntensity;
  }

  String _getIntensityDescription(String level) {
    switch (level) {
      case 'Low':
        return 'Low: Preserves your exact vocabulary, grammar, and sentence structure.';
      case 'High':
        return 'High: Aggressively restructures paragraphs into bold, synthesized executive prose.';
      default:
        return 'Medium: Strips filler words, sharpens flow, and formats key takeaways naturally.';
    }
  }

  String _getIntensityBadge(String level) {
    switch (level) {
      case 'Low':
        return 'Minimal Edits';
      case 'High':
        return 'Full Restructure';
      default:
        return 'Balanced Polish';
    }
  }

  void _showCustomPromptDialog() {
    final currentCustomPrompt = ref.read(notesProvider).customTonePrompt;
    final controller = TextEditingController(text: currentCustomPrompt);

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
                    Icons.psychology,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Custom AI Instructions',
                style: GoogleFonts.newsreader(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Give the AI your exact persona, formatting guidelines, or specialized instructions.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.inkMuted,
                  height: 1.4,
                  fontSize: 12.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: TextField(
                  controller: controller,
                  maxLines: 4,
                  maxLength: 300,
                  style: const TextStyle(fontSize: 13, color: AppColors.inkPrimary),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Structure as a YouTube script with Hook, Core Lesson, and Call to Action.',
                    hintStyle: TextStyle(color: AppColors.inkSubtle, fontSize: 12),
                    border: InputBorder.none,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AppBounceable(
                onTap: () {
                  final newPrompt = controller.text.trim();
                  ref.read(notesProvider.notifier).setCustomTonePrompt(newPrompt);
                  Navigator.of(ctx).pop();
                  setState(() {
                    _selectedTone = 'Custom Tone';
                  });
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Custom AI Tone prompt saved!'),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: StadiumBorder(),
                    ),
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
                      'Save Instructions',
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
                  height: 42,
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
  Widget build(BuildContext context) {
    final customPromptText = ref.watch(notesProvider).customTonePrompt;
    final isPro = ref.watch(notesProvider).isProUser;

    final gridPresets = TonePresets.all.where((p) => p.id != 'actionable_todo' && p.id != 'custom_tone').toList();
    final todoPreset = TonePresets.all.firstWhere(
      (p) => p.id == 'actionable_todo',
      orElse: () => TonePresets.all.first,
    );
    final customPreset = TonePresets.all.firstWhere(
      (p) => p.id == 'custom_tone',
      orElse: () => TonePresets.all.last,
    );
    final isTodoSelected = _selectedTone == todoPreset.label;
    final isCustomSelected = _selectedTone == customPreset.label;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.88,
      ),
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

            // Header matching Stitch
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
                          widget.isRepolishing ? 'Re-polish with New Tone' : 'Customize Tone & Polish',
                          style: AppTypography.headlineSmall.copyWith(
                            color: AppColors.inkPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select how the AI rephrases and structures your voice note.',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

              // Sub-header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'EDITORIAL TONE',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      '7 presets available',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 6 Tone Presets 2x3 Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.24,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: gridPresets.length,
                  itemBuilder: (context, index) {
                    final preset = gridPresets[index];
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
                        setState(() {
                          _selectedTone = preset.label;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.peachTint : AppColors.surface,
                          borderRadius: AppRadii.roundedMd,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.borderSubtle,
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected ? AppShadows.card : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primaryTint
                                        : AppColors.surfaceContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    preset.icon,
                                    size: 17,
                                    color: isSelected ? AppColors.primary : AppColors.inkPrimary,
                                  ),
                                ),
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? AppColors.primary : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : AppColors.borderSubtle,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Center(
                                          child: Icon(Icons.check, size: 12, color: Colors.white),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  preset.label,
                                  style: AppTypography.labelMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? AppColors.primaryDark
                                        : AppColors.inkPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  preset.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelSmall.copyWith(
                                    fontSize: 10,
                                    color: AppColors.inkMuted,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              // 7th Preset: Actionable To-Do Full Width Card matching Stitch
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppBounceable(
                  onTap: () {
                    final isLocked = todoPreset.isProOnly && !ref.watch(notesProvider).isProUser;
                    if (isLocked) {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(
                        AppPageRoute(page: const PaywallScreen()),
                      );
                      return;
                    }
                    setState(() {
                      _selectedTone = todoPreset.label;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isTodoSelected ? AppColors.peachTint : AppColors.surface,
                      borderRadius: AppRadii.roundedMd,
                      border: Border.all(
                        color: isTodoSelected ? AppColors.primary : AppColors.borderSubtle,
                        width: isTodoSelected ? 1.5 : 1,
                      ),
                      boxShadow: isTodoSelected ? AppShadows.card : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isTodoSelected ? AppColors.primaryTint : AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            todoPreset.icon,
                            size: 18,
                            color: isTodoSelected ? AppColors.primary : AppColors.inkPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                todoPreset.label,
                                style: AppTypography.labelMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isTodoSelected ? AppColors.primaryDark : AppColors.inkPrimary,
                                ),
                              ),
                              Text(
                                todoPreset.description,
                                style: AppTypography.labelSmall.copyWith(
                                  fontSize: 10.5,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isTodoSelected ? AppColors.primary : Colors.transparent,
                            border: Border.all(
                              color: isTodoSelected ? AppColors.primary : AppColors.borderSubtle,
                              width: 1.5,
                            ),
                          ),
                          child: isTodoSelected
                              ? const Center(
                                  child: Icon(Icons.check, size: 12, color: Colors.white),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // 8th Preset: Custom Tone (Pro Only) with Prompt Edit Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppBounceable(
                  onTap: () {
                    if (!isPro) {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(
                        AppPageRoute(page: const PaywallScreen()),
                      );
                      return;
                    }
                    if (customPromptText.isEmpty) {
                      _showCustomPromptDialog();
                    } else {
                      setState(() {
                        _selectedTone = customPreset.label;
                      });
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCustomSelected ? AppColors.peachTint : AppColors.surface,
                      borderRadius: AppRadii.roundedMd,
                      border: Border.all(
                        color: isCustomSelected ? AppColors.primary : AppColors.borderSubtle,
                        width: isCustomSelected ? 1.5 : 1,
                      ),
                      boxShadow: isCustomSelected ? AppShadows.card : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isCustomSelected ? AppColors.primaryTint : AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            customPreset.icon,
                            size: 18,
                            color: isCustomSelected ? AppColors.primary : AppColors.inkPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    customPreset.label,
                                    style: AppTypography.labelMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: isCustomSelected ? AppColors.primaryDark : AppColors.inkPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppColors.peachTint,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'PRO',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                customPromptText.isNotEmpty
                                    ? '"$customPromptText"'
                                    : customPreset.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSmall.copyWith(
                                  fontSize: 10.5,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isPro)
                          AppBounceable(
                            onTap: _showCustomPromptDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.edit, size: 12, color: AppColors.primary),
                                  SizedBox(width: 3),
                                  Text(
                                    'Edit',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCustomSelected ? AppColors.primary : Colors.transparent,
                            border: Border.all(
                              color: isCustomSelected ? AppColors.primary : AppColors.borderSubtle,
                              width: 1.5,
                            ),
                          ),
                          child: isCustomSelected
                              ? const Center(
                                  child: Icon(Icons.check, size: 12, color: Colors.white),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Rewrite Intensity Segmented Selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'REWRITE INTENSITY',
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppColors.peachTint,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getIntensityBadge(_selectedIntensity),
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primaryDark,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: AppRadii.roundedFull,
                      ),
                      child: Row(
                        children: TonePresets.intensityLevels.map((level) {
                          final isSelected = _selectedIntensity == level;
                          return Expanded(
                            child: AppBounceable(
                              onTap: () {
                                setState(() {
                                  _selectedIntensity = level;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : Colors.transparent,
                                  borderRadius: AppRadii.roundedFull,
                                  boxShadow: isSelected ? AppShadows.card : null,
                                ),
                                child: Center(
                                  child: Text(
                                    isSelected ? '• $level' : level,
                                    style: AppTypography.labelMedium.copyWith(
                                      fontWeight:
                                          isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.inkMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: AppColors.inkSubtle),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _getIntensityDescription(_selectedIntensity),
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.inkMuted,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
                  ],
                ),
              ),
            ),

            // Pinned Bottom Action Container
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
                  debugPrint('[ToneBottomSheet] CTA tapped with tone: $_selectedTone, intensity: $_selectedIntensity');
                  HapticFeedback.mediumImpact();
                  widget.onApply(_selectedTone, _selectedIntensity);
                  Navigator.of(context).pop();
                },
                child: Container(
                  height: 52,
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        widget.isRepolishing
                            ? 'Re-polish Note with $_selectedTone'
                            : 'Apply Tone: $_selectedTone',
                        style: const TextStyle(
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
