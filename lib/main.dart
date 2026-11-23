import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_preview/device_preview.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/config/supabase_config.dart';
import 'core/services/preferences_service.dart';
import 'core/database/notes_database.dart';
import 'core/state/notes_state.dart';
import 'features/notes/presentation/screens/library_screen.dart';
import 'features/auth/presentation/screens/auth_screen.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Force portrait orientation for the voice-first Android experience
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Edge-to-edge: app content renders behind system bars, we control our own insets
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Render behind both status bar and navigation bar
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Initialize Supabase Cloud Backend
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // ignore: deprecated_member_use
    anonKey: SupabaseConfig.anonKey,
  );

  // Initialize SharedPreferences and SQLite database
  final prefsService = await PreferencesService.init();
  final notesDb = NotesDatabase();
  final initialNotes = await notesDb.getAllNotes();

  // Native splash is released smoothly as Flutter renders
  FlutterNativeSplash.remove();

  runApp(
    DevicePreview(
      enabled: kDebugMode,
      builder: (context) => ProviderScope(
        overrides: [
          preferencesServiceProvider.overrideWithValue(prefsService),
          notesDatabaseProvider.overrideWithValue(notesDb),
          initialNotesProvider.overrideWithValue(initialNotes),
        ],
        child: const VoicePenApp(),
      ),
    ),
  );
}

class VoicePenApp extends StatelessWidget {
  final Widget? initialScreen;
  const VoicePenApp({super.key, this.initialScreen});

  @override
  Widget build(BuildContext context) {
    Widget homeScreen;
    if (initialScreen != null) {
      homeScreen = initialScreen!;
    } else {
      try {
        final session = Supabase.instance.client.auth.currentSession;
        homeScreen = session != null ? const LibraryScreen() : const AuthScreen();
      } catch (_) {
        homeScreen = const AuthScreen();
      }
    }

    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          title: 'VoicePen',
          debugShowCheckedModeBanner: false,
          locale: DevicePreview.locale(context),
          builder: DevicePreview.appBuilder,
          theme: AppTheme.lightTheme,
          color: AppColors.background,
          home: homeScreen,
        );
      },
    );
  }
}
