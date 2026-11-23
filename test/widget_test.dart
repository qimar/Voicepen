import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicepen/main.dart';
import 'package:voicepen/core/services/preferences_service.dart';
import 'package:voicepen/core/state/notes_state.dart';
import 'package:voicepen/features/auth/presentation/screens/auth_screen.dart';

void main() {
  testWidgets('VoicePenApp builds smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final prefsService = PreferencesService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesServiceProvider.overrideWithValue(prefsService),
        ],
        child: const VoicePenApp(initialScreen: AuthScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('VoicePen'), findsOneWidget);
  });
}
