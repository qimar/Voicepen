import '../../../../core/services/google_drive_backup_service.dart';
import '../../../../core/services/cloud_sync_service.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_page_route.dart';
import '../../../../core/state/notes_state.dart';
import '../../../../core/widgets/app_bounceable.dart';
import '../../../../core/services/gemini_service.dart';
import '../../../../core/services/supabase_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
import '../../../monetization/presentation/screens/paywall_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _obscureKey = true;
  bool _isValidatingKey = false;
  bool _showByokInput = false;
  double _audioCacheMb = 0.0;
  double _dbSizeMb = 0.0;

  @override
  void initState() {
    super.initState();
    final currentState = ref.read(notesProvider);
    _apiKeyController.text = currentState.byokApiKey;
    _showByokInput = currentState.byokApiKey.isNotEmpty;
    _calculateStorageUsage();
  }

  Future<void> _calculateStorageUsage() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${docsDir.path}/audio');
      int audioBytes = 0;
      if (await audioDir.exists()) {
        await for (final file in audioDir.list()) {
          if (file is File) {
            audioBytes += await file.length();
          }
        }
      }

      int dbBytes = 0;
      try {
        final dbFile = File('${docsDir.path}/voicepen.db');
        if (await dbFile.exists()) {
          dbBytes = await dbFile.length();
        } else {
          // Alternatively check databases path if stored there
          final appSupportDir = Directory('${docsDir.parent.path}/databases/voicepen.db');
          if (await appSupportDir.exists()) {
            dbBytes = await appSupportDir.stat().then((s) => s.size);
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _audioCacheMb = audioBytes / (1024 * 1024);
          _dbSizeMb = dbBytes > 0 ? dbBytes / (1024 * 1024) : 0.05;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ref.read(notesProvider.notifier).setByokApiKey('');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gemini API key cleared.'),
          backgroundColor: AppColors.inkPrimary,
          behavior: SnackBarBehavior.floating,
          shape: StadiumBorder(),
        ),
      );
      return;
    }

    setState(() => _isValidatingKey = true);
    HapticFeedback.lightImpact();

    final error = await GeminiService().validateApiKey(key);
    if (!mounted) return;
    setState(() => _isValidatingKey = false);

    if (error == null) {
      ref.read(notesProvider.notifier).setByokApiKey(key);
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Gemini API key verified and saved!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: StadiumBorder(),
        ),
      );
    } else {
      HapticFeedback.heavyImpact();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('API Key Validation Failed', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          content: Text(error, style: const TextStyle(color: AppColors.inkPrimary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.inkMuted,
              ),
              child: const Text('Edit Key'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              onPressed: () {
                ref.read(notesProvider.notifier).setByokApiKey(key);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('API key saved without verification.'),
                    backgroundColor: AppColors.inkPrimary,
                    behavior: SnackBarBehavior.floating,
                    shape: StadiumBorder(),
                  ),
                );
              },
              child: const Text('Save Anyway'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _clearCache() async {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Cache?', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.inkPrimary)),
        content: const Text(
          'This will delete all local audio files and all notes from this device. Your cloud backup in Supabase is not affected.',
          style: TextStyle(height: 1.5, color: AppColors.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.inkMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      // Delete ALL local audio files
      final docsDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${docsDir.path}/audio');
      int deletedCount = 0;
      if (await audioDir.exists()) {
        await for (final file in audioDir.list()) {
          if (file is File) {
            await file.delete();
            deletedCount++;
          }
        }
      }

      // Delete all notes from local SQLite and reload state
      await ref.read(notesProvider.notifier).clearAllNotes();
      await _calculateStorageUsage();

      messenger.showSnackBar(
        SnackBar(
          content: Text('Cache cleared — $deletedCount audio file${deletedCount == 1 ? '' : 's'} and all local notes removed.'),
          backgroundColor: AppColors.inkPrimary,
          behavior: SnackBarBehavior.floating,
          shape: const StadiumBorder(),
        ),
      );
    } catch (_) {
      await _calculateStorageUsage();
    }
  }

  Future<void> _deleteAllData() async {
    HapticFeedback.heavyImpact();
    final messenger = ScaffoldMessenger.of(context);
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete All Data?', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
        content: const Text(
          'This will permanently delete all notes, transcripts, and audio files from this device AND from the cloud. This cannot be undone.',
          style: TextStyle(height: 1.5, color: AppColors.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.inkMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      // 1. Delete all local audio files
      final docsDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${docsDir.path}/audio');
      if (await audioDir.exists()) {
        await for (final file in audioDir.list()) {
          if (file is File) await file.delete();
        }
      }

      // 2. Delete all notes from local SQLite
      await ref.read(notesProvider.notifier).clearAllNotes();

      // 3. Delete all notes from Supabase cloud
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('notes')
            .delete()
            .eq('user_id', user.id);
      }

      await _calculateStorageUsage();

      messenger.showSnackBar(
        const SnackBar(
          content: Text('All data deleted from device and cloud.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: StadiumBorder(),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error deleting data: $e'),
          backgroundColor: AppColors.inkPrimary,
          behavior: SnackBarBehavior.floating,
          shape: const StadiumBorder(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesState = ref.watch(notesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
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
                  const Expanded(
                    child: Text(
                      'Settings',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 38), // Balancer
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 0: Account & Cloud Session
                    _buildAccountSection(),
                    const SizedBox(height: 24),

                    // Section 1: VoicePen Pro Card
                    Container(
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.peachTint,
                                        borderRadius: AppRadii.roundedFull,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.verified,
                                            size: 13,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            notesState.isProUser
                                                ? 'LIFETIME ACTIVE'
                                                : 'FREE TIER',
                                            style: AppTypography.labelSmall.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primaryDark,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      notesState.isProUser
                                          ? 'VoicePen Pro Lifetime'
                                          : 'Upgrade to VoicePen Pro',
                                      style: AppTypography.labelLarge.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.inkPrimary,
                                        fontSize: 17,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      notesState.isProUser
                                          ? 'Unlimited recording length & private sandbox unlocked.'
                                          : 'Unlock unlimited recordings, all 7 tones & BYOK.',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: AppColors.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.peachTint,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.workspace_premium,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(height: 1, color: AppColors.borderSubtle.withValues(alpha: 0.6)),
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 10,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    notesState.isProUser
                                        ? 'Verified'
                                        : '15-min free limit',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.inkMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (notesState.isProUser) ...[
                                    AppBounceable(
                                      onTap: () {
                                        HapticFeedback.mediumImpact();
                                        ref.read(notesProvider.notifier).setProUser(false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Pro status removed (Testing mode active).'),
                                            backgroundColor: AppColors.inkPrimary,
                                            behavior: SnackBarBehavior.floating,
                                            shape: StadiumBorder(),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: AppColors.errorContainer,
                                          borderRadius: AppRadii.roundedFull,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.remove_circle_outline, size: 13, color: AppColors.error),
                                            SizedBox(width: 4),
                                            Text(
                                              'Remove Pro (Test)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  AppBounceable(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        AppPageRoute(page: const PaywallScreen()),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: notesState.isProUser
                                            ? AppColors.surfaceContainer
                                            : AppColors.primary,
                                        borderRadius: AppRadii.roundedFull,
                                      ),
                                      child: Text(
                                        notesState.isProUser ? 'Manage Pass' : 'Unlock \$4.99',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: notesState.isProUser ? AppColors.inkPrimary : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section 2: AI Processing Engine (VoicePen Cloud vs BYOK)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'AI PROCESSING ENGINE',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppColors.peachTint,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            ref.watch(notesProvider).byokApiKey.isNotEmpty ? 'BYOK Active' : 'Cloud Pool Active',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primaryDark,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Container(
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
                          // Option A: VoicePen Cloud AI (Default)
                          AppBounceable(
                            onTap: () {
                              if (ref.read(notesProvider).byokApiKey.isNotEmpty) {
                                ref.read(notesProvider.notifier).setByokApiKey('');
                                _apiKeyController.clear();
                                setState(() => _showByokInput = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Switched to VoicePen Cloud AI (30 notes/day).'),
                                    backgroundColor: AppColors.primary,
                                    behavior: SnackBarBehavior.floating,
                                    shape: StadiumBorder(),
                                  ),
                                );
                              } else {
                                setState(() => _showByokInput = false);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ref.watch(notesProvider).byokApiKey.isEmpty && !_showByokInput
                                    ? AppColors.peachTint.withValues(alpha: 0.35)
                                    : AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: ref.watch(notesProvider).byokApiKey.isEmpty && !_showByokInput
                                      ? AppColors.primary
                                      : AppColors.borderSubtle,
                                  width: ref.watch(notesProvider).byokApiKey.isEmpty && !_showByokInput ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    ref.watch(notesProvider).byokApiKey.isEmpty && !_showByokInput
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    size: 18,
                                    color: ref.watch(notesProvider).byokApiKey.isEmpty && !_showByokInput
                                        ? AppColors.primary
                                        : AppColors.inkMuted,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'VoicePen Cloud AI',
                                              style: AppTypography.labelLarge.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.inkPrimary,
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
                                                'Default',
                                                style: TextStyle(
                                                  color: AppColors.primaryDark,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Server-managed key pool with failover rotation. 30 requests/day included.',
                                          style: AppTypography.labelSmall.copyWith(
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

                          const SizedBox(height: 10),

                          // Option B: Personal Gemini API Key (BYOK)
                          AppBounceable(
                            onTap: () {
                              setState(() => _showByokInput = true);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ref.watch(notesProvider).byokApiKey.isNotEmpty || _showByokInput
                                    ? AppColors.peachTint.withValues(alpha: 0.35)
                                    : AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: ref.watch(notesProvider).byokApiKey.isNotEmpty || _showByokInput
                                      ? AppColors.primary
                                      : AppColors.borderSubtle,
                                  width: ref.watch(notesProvider).byokApiKey.isNotEmpty || _showByokInput ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    ref.watch(notesProvider).byokApiKey.isNotEmpty || _showByokInput
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    size: 18,
                                    color: ref.watch(notesProvider).byokApiKey.isNotEmpty || _showByokInput
                                        ? AppColors.primary
                                        : AppColors.inkMuted,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Personal Gemini Key (BYOK)',
                                          style: AppTypography.labelLarge.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.inkPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Unlimited requests using your free Google AI Studio API key.',
                                          style: AppTypography.labelSmall.copyWith(
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

                          // If BYOK is active or being edited, show the input field
                          if (_showByokInput || ref.watch(notesProvider).byokApiKey.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            TextField(
                              controller: _apiKeyController,
                              obscureText: _obscureKey,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'AIzaSy...',
                                hintStyle: const TextStyle(color: AppColors.inkSubtle),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureKey ? Icons.visibility : Icons.visibility_off,
                                    size: 18,
                                    color: AppColors.inkMuted,
                                  ),
                                  onPressed: () {
                                    setState(() => _obscureKey = !_obscureKey);
                                  },
                                ),
                                filled: true,
                                fillColor: AppColors.surfaceContainerLow,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (ref.watch(notesProvider).byokApiKey.isNotEmpty) ...[
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        ref.read(notesProvider.notifier).setByokApiKey('');
                                        _apiKeyController.clear();
                                        setState(() => _showByokInput = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Switched back to VoicePen Cloud AI.'),
                                            backgroundColor: AppColors.primary,
                                            behavior: SnackBarBehavior.floating,
                                            shape: StadiumBorder(),
                                          ),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                        side: const BorderSide(color: AppColors.error),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Text('Clear Key'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: _isValidatingKey ? null : _saveApiKey,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: AppColors.onPrimary,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (_isValidatingKey)
                                          const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        else
                                          const Icon(Icons.check, size: 16),
                                        const SizedBox(width: 6),
                                        Text(_isValidatingKey ? 'Validating...' : 'Save Key'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section 3: Local Data & Storage
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'LOCAL DATA & STORAGE',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          '${_audioCacheMb.toStringAsFixed(1)} MB Used',
                          style: AppTypography.labelSmall.copyWith(color: AppColors.inkMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Card A: Storage Breakdown Meter
                    Builder(
                      builder: (context) {
                        final totalMb = _audioCacheMb + _dbSizeMb;
                        final totalDisplay = totalMb < 0.1 ? '< 0.1 MB' : '${totalMb.toStringAsFixed(1)} MB';
                        final audioDisplay = _audioCacheMb < 0.1 ? '< 0.1 MB' : '${_audioCacheMb.toStringAsFixed(1)} MB';
                        final dbDisplay = _dbSizeMb < 0.1 ? '< 0.1 MB' : '${_dbSizeMb.toStringAsFixed(1)} MB';

                        final audioFlex = totalMb > 0 ? ((_audioCacheMb / totalMb) * 100).round().clamp(5, 95) : 50;
                        final dbFlex = 100 - audioFlex;

                        return Container(
                          padding: const EdgeInsets.all(16),
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
                                  Row(
                                    children: [
                                      const Icon(Icons.storage, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Sandboxed Database',
                                        style: AppTypography.labelMedium.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.inkPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Total $totalDisplay',
                                    style: AppTypography.labelSmall.copyWith(color: AppColors.inkMuted),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Storage Meter Bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: SizedBox(
                                  height: 8,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: audioFlex,
                                        child: Container(color: AppColors.primary),
                                      ),
                                      Expanded(
                                        flex: dbFlex,
                                        child: Container(color: AppColors.secondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Vault $audioDisplay',
                                        style: AppTypography.labelSmall.copyWith(
                                          color: AppColors.inkMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'SQLite $dbDisplay',
                                        style: AppTypography.labelSmall.copyWith(
                                          color: AppColors.inkMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Sandboxed',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.inkSubtle,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    // Card B: Storage Actions (Export + Clear Cache)
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadii.roundedLg,
                        border: Border.all(color: AppColors.borderSubtle),
                        boxShadow: AppShadows.card,
                      ),
                      child: Column(
                        children: [
                          // Export All Notes Tile
                          AppBounceable(
                            onTap: () async {
                              final allNotes = ref.read(notesProvider).notes;
                              if (allNotes.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('No notes available to export.'),
                                    backgroundColor: AppColors.inkPrimary,
                                    behavior: SnackBarBehavior.floating,
                                    shape: StadiumBorder(),
                                  ),
                                );
                                return;
                              }

                              final buffer = StringBuffer();
                              buffer.writeln('# VoicePen Notes Export');
                              buffer.writeln('Exported on: ${DateTime.now().toIso8601String()}\n');
                              buffer.writeln('Total notes: ${allNotes.length}\n');
                              buffer.writeln('---\n');

                              for (final n in allNotes) {
                                buffer.writeln('## ${n.title}');
                                buffer.writeln('**Date:** ${n.createdAt.toIso8601String().split('T').first} | **Duration:** ${n.formattedDuration} | **Tone:** ${n.tone}');
                                if (n.tags.isNotEmpty) {
                                  buffer.writeln('**Tags:** ${n.tags.join(', ')}');
                                }
                                buffer.writeln('\n### Cleaned Content\n${n.cleanedContent}\n');
                                buffer.writeln('### Verbatim Transcript\n${n.verbatimTranscript}\n');
                                buffer.writeln('---\n');
                              }

                              try {
                                await SharePlus.instance.share(
                                  ShareParams(
                                    text: buffer.toString(),
                                    subject: 'VoicePen Notes Export (${allNotes.length} notes)',
                                  ),
                                );
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Could not open share dialogue for export.'),
                                      backgroundColor: AppColors.inkPrimary,
                                      behavior: SnackBarBehavior.floating,
                                      shape: StadiumBorder(),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: AppColors.peachTint,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.upload_file, size: 18, color: AppColors.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Export All Notes',
                                          style: AppTypography.labelMedium.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.inkPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Markdown (.md) and JSON bundle',
                                          style: AppTypography.labelSmall.copyWith(color: AppColors.inkMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, size: 20, color: AppColors.inkSubtle),
                                ],
                              ),
                            ),
                          ),
                          Container(height: 1, color: AppColors.borderSubtle.withValues(alpha: 0.5)),
                          // Clear Cache Tile
                          AppBounceable(
                            onTap: _clearCache,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: AppColors.errorContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.cleaning_services, size: 18, color: AppColors.error),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Clear Cache',
                                          style: AppTypography.labelMedium.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.error,
                                          ),
                                        ),
                                        Text(
                                          'Delete all local notes and audio files from this device.',
                                          style: AppTypography.labelSmall.copyWith(color: AppColors.inkMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, size: 20, color: AppColors.inkSubtle),
                                ],
                              ),
                            ),
                          ),
                          Container(height: 1, color: AppColors.borderSubtle.withValues(alpha: 0.5)),
                          // Delete All Data Tile
                          AppBounceable(
                            onTap: _deleteAllData,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: AppColors.errorContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.delete_forever, size: 18, color: AppColors.error),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Delete All Data',
                                          style: AppTypography.labelMedium.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.error,
                                          ),
                                        ),
                                        Text(
                                          'Permanently remove all notes and audio from device and cloud.',
                                          style: AppTypography.labelSmall.copyWith(color: AppColors.inkMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, size: 20, color: AppColors.inkSubtle),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // App Footer matching Stitch
                    Center(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppBounceable(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: AppColors.surface,
                                      surfaceTintColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.inkPrimary)),
                                      content: const SingleChildScrollView(
                                        child: Text(
                                          'VoicePen respects your privacy. All audio memos, verbatim transcripts, and SQLite database records are stored locally and securely in your device sandboxed storage.\n\nWhen using AI Polish with your Google AI Studio API Key (BYOK), audio is processed strictly according to Google Generative AI terms and is never saved to external 3rd-party servers by VoicePen.',
                                          style: TextStyle(height: 1.5, color: AppColors.inkMuted),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(),
                                          style: TextButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            shape: const StadiumBorder(),
                                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                          ),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Text(
                                  'Privacy Policy',
                                  style: AppTypography.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('•', style: TextStyle(color: AppColors.borderSubtle)),
                              const SizedBox(width: 8),
                              AppBounceable(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: AppColors.surface,
                                      surfaceTintColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      title: const Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.inkPrimary)),
                                      content: const SingleChildScrollView(
                                        child: Text(
                                          'By using VoicePen, you retain full ownership of all voice recordings and generated text. You are responsible for ensuring that you have appropriate rights and permissions to record any conversational or audio content.',
                                          style: TextStyle(height: 1.5, color: AppColors.inkMuted),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(),
                                          style: TextButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            shape: const StadiumBorder(),
                                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                          ),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Text(
                                  'Terms of Service',
                                  style: AppTypography.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('•', style: TextStyle(color: AppColors.borderSubtle)),
                              const SizedBox(width: 8),
                              AppBounceable(
                                onTap: () => showLicensePage(
                                  context: context,
                                  applicationName: 'VoicePen',
                                  applicationVersion: '1.0.0',
                                ),
                                child: Text(
                                  'Licenses',
                                  style: AppTypography.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection() {
    final user = ref.watch(currentUserProvider);
    final email = user?.email ?? 'Connected User';
    final displayName = user?.userMetadata?['full_name'] as String? ?? '';
    final isSyncing = ref.watch(syncStatusProvider);
    final isAudioBackup = ref.watch(notesProvider).isAudioCloudBackupEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_done_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'ACCOUNT & CLOUD',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.inkMuted,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            AppBounceable(
              onTap: isSyncing
                  ? null
                  : () async {
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Syncing with VoicePen Cloud...'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          shape: StadiumBorder(),
                        ),
                      );
                      await ref.read(notesProvider.notifier).syncWithCloud();
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSyncing)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
                      )
                    else
                      const Icon(Icons.sync, size: 13, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      isSyncing ? 'Syncing...' : 'Sync Now',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
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
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.peachTint,
                    child: Text(
                      email.isNotEmpty ? email[0].toUpperCase() : 'U',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (displayName.isNotEmpty) ...[
                          Text(
                            displayName,
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.inkPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          email,
                          style: AppTypography.bodyMedium.copyWith(
                            color: displayName.isNotEmpty ? AppColors.inkMuted : AppColors.inkPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSyncing ? AppColors.peachTint : AppColors.successContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSyncing ? Icons.sync : Icons.check_circle,
                          size: 12,
                          color: isSyncing ? AppColors.primary : AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isSyncing ? 'Syncing' : 'Synced',
                          style: AppTypography.labelSmall.copyWith(
                            color: isSyncing ? AppColors.primaryDark : AppColors.onSuccess,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: AppColors.borderSubtle, height: 1),
              const SizedBox(height: 12),
              // Audio Cloud Backup Toggle (Pro Feature)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Audio Cloud Backup',
                                  style: AppTypography.labelLarge.copyWith(
                                    color: AppColors.inkPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.peachTint,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    'PRO',
                                    style: TextStyle(
                                      color: AppColors.primaryDark,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Privately back up original recordings to your personal cloud vault.',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.inkMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: isAudioBackup,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) async {
                          HapticFeedback.lightImpact();
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);
                          final isPro = ref.read(notesProvider).isProUser;
                          if (!isPro && val) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Audio Cloud Backup is a VoicePen Pro feature.'),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: StadiumBorder(),
                              ),
                            );
                            navigator.push(
                              AppPageRoute(page: const PaywallScreen()),
                            );
                            return;
                          }

                          if (val) {
                            final driveService = ref.read(googleDriveBackupServiceProvider);
                            if (!driveService.isSignedIn) {
                              try {
                                final account = await driveService.signIn();
                                if (account == null) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('✓ Connected to cloud vault: '),
                                    backgroundColor: AppColors.primary,
                                    behavior: SnackBarBehavior.floating,
                                    shape: const StadiumBorder(),
                                  ),
                                );
                              } catch (e) {
                                debugPrint('[Settings] Cloud vault auth error: ');
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Could not connect to cloud vault. Check Google Services setup.'),
                                    backgroundColor: AppColors.inkPrimary,
                                    behavior: SnackBarBehavior.floating,
                                    shape: StadiumBorder(),
                                  ),
                                );
                                return;
                              }
                            }
                          }

                          ref.read(notesProvider.notifier).setAudioCloudBackupEnabled(val);
                        },
                      ),
                    ],
                  ),
                  if (isAudioBackup && ref.watch(googleDriveBackupServiceProvider).isSignedIn) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.peachTint.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_done_outlined, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Vault connected: ${ref.watch(googleDriveBackupServiceProvider).currentUser?.email ?? "Active"}',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primaryDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.borderSubtle, height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _confirmSignOut,
                    icon: const Icon(Icons.logout, size: 16, color: AppColors.inkMuted),
                    label: Text(
                      'Sign Out',
                      style: AppTypography.labelMedium.copyWith(color: AppColors.inkMuted),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  TextButton(
                    onPressed: _confirmDeleteAccount,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Delete Account',
                      style: AppTypography.labelMedium.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out', style: AppTypography.headlineSmall.copyWith(color: AppColors.inkPrimary)),
        content: Text('Are you sure you want to sign out of VoicePen?', style: AppTypography.bodyMedium.copyWith(color: AppColors.inkMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppTypography.labelLarge.copyWith(color: AppColors.inkMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(supabaseAuthServiceProvider).signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  AppPageRoute(page: const AuthScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Account?', style: AppTypography.headlineSmall.copyWith(color: AppColors.error)),
        content: Text(
          'This will permanently delete your VoicePen account, cloud notes, and profile. This action cannot be undone.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppTypography.labelLarge.copyWith(color: AppColors.inkMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(supabaseAuthServiceProvider).deleteAccount();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    AppPageRoute(page: const AuthScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete account: $e'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: const StadiumBorder(),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }
}
