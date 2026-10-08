import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kid_smile/data/pack_repository.dart';
import 'package:kid_smile/logic/quiz_engine.dart';
import 'package:kid_smile/models/question.dart';
import 'package:kid_smile/screens/home_screen.dart';
import 'package:kid_smile/screens/quiz_screen.dart';
import 'package:kid_smile/screens/result_screen.dart';
import 'package:kid_smile/screens/settings_screen.dart';
import 'package:kid_smile/services/app_language.dart';
import 'package:kid_smile/services/content_sync.dart';
import 'package:kid_smile/strings.dart';
import 'package:kid_smile/theme.dart';
import 'package:kid_smile/widgets/responsive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Logical sizes covering the devices the app should look right on.
const _devices = <String, Size>{
  'small phone (iPhone SE 1st gen)': Size(320, 568),
  'phone (Android 360)': Size(360, 800),
  'large phone (Pixel 7)': Size(412, 915),
  'phone sideways': Size(800, 360),
  'small phone sideways': Size(568, 320),
  'tablet portrait': Size(768, 1024),
  'tablet landscape': Size(1280, 800),
  'desktop': Size(1920, 1080),
};

Widget _app(Widget home, {double textScale = 1}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppLanguage()),
      ChangeNotifierProvider(create: (_) => ContentSync()),
    ],
    child: MaterialApp(
      // Same per-device theming + text clamping as the real app.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: ClampTextScale(
          child: Theme(
            data: AppTheme.themeFor(context.screenClass),
            child: child!,
          ),
        ),
      ),
      home: home,
    ),
  );
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

/// Pumps long enough for staggered entrances to finish (the app has
/// looping animations, so pumpAndSettle would never return), then
/// unmounts so no timers are left pending.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

List<AnsweredQuestion> _answers() {
  final questions = [
    for (var i = 0; i < 10; i++)
      Question(
        id: i,
        categoryId: 1,
        prompt: i.isEven
            ? 'Which animal has a very long neck so it can reach the '
                  'leaves at the top of tall trees?'
            : 'What is $i + 2?',
        choices: const ['Giraffe', 'Zebra', 'Hippopotamus', 'Pig'],
        language: 'en',
        correctIndex: 0,
        difficulty: 'easy',
        ageGroup: '4-6',
      ),
  ];
  final engine = QuizEngine(questions);
  for (var i = 0; i < 10; i++) {
    engine.answer(i % 3 == 0 ? -1 : i % 4);
  }
  return engine.answers;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppStrings.load();
    AppTheme.useGoogleFonts = false;
  });

  for (final entry in _devices.entries) {
    group(entry.key, () {
      testWidgets('home grid and quiz-length sheet fit', (tester) async {
        await _setSize(tester, entry.value);
        await tester.runAsync(() => PackRepository().ensureSeeded());
        await tester.pumpWidget(_app(const HomeScreen()));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await _settle(tester);
        await tester.tap(find.text('Mixed Quiz'));
        await _settle(tester);
        // The picker is a centered dialog, not a bottom sheet.
        final card = tester.getRect(
          find
              .ancestor(of: find.text('8'), matching: find.byType(Material))
              .first,
        );
        final screen = entry.value;
        expect(card.center.dx, moreOrLessEquals(screen.width / 2, epsilon: 1));
        if (card.height < screen.height - 40) {
          expect(
            card.center.dy,
            moreOrLessEquals(screen.height / 2, epsilon: 30),
          );
        }
        // All three length choices must be reachable, even sideways.
        for (final n in ['6', '8', '10']) {
          await tester.ensureVisible(find.text(n));
          expect(find.text(n), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        // ✕ closes it without starting a quiz.
        await tester.ensureVisible(find.byIcon(Icons.close_rounded));
        await tester.tap(find.byIcon(Icons.close_rounded));
        await _settle(tester);
        expect(find.text('8'), findsNothing);
        await _unmount(tester);
      });

      testWidgets('quiz screen fits', (tester) async {
        await _setSize(tester, entry.value);
        await tester.runAsync(() => PackRepository().ensureSeeded());
        await tester.pumpWidget(
          _app(const QuizScreen(categoryId: null, categoryTitle: 'Mixed Quiz')),
        );
        // Let the real DB query finish, then render the first question.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
        await _settle(tester);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _unmount(tester);
      });

      testWidgets('result screen fits, with the answer review open', (
        tester,
      ) async {
        await _setSize(tester, entry.value);
        await tester.pumpWidget(
          _app(
            ResultScreen(
              score: 4,
              total: 10,
              answers: _answers(),
              categoryTitle: 'Animals',
              categoryId: 1,
            ),
          ),
        );
        await _settle(tester);
        await tester.ensureVisible(find.text('Check My Answers'));
        await tester.tap(find.text('Check My Answers'));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        await _unmount(tester);
      });

      testWidgets('settings screen fits with large system text', (
        tester,
      ) async {
        await _setSize(tester, entry.value);
        await tester.runAsync(() => PackRepository().ensureSeeded());
        await tester.pumpWidget(_app(const SettingsScreen(), textScale: 2));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
        await _unmount(tester);
      });
    });
  }
}
