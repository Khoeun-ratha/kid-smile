import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'platform/db_factory.dart';
import 'screens/splash_screen.dart';
import 'services/app_language.dart';
import 'services/content_sync.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets/kid_background.dart';
import 'widgets/responsive.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The app must look right with no internet, so the Baloo 2 font ships in
  // assets/google_fonts/ and is never downloaded at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });
  configureDatabaseFactory();
  await AppStrings.load();
  runApp(const KidSmileApp());
}

class KidSmileApp extends StatelessWidget {
  const KidSmileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppLanguage()..load()),
        // Started by the splash screen once the offline packs are seeded.
        ChangeNotifierProvider(create: (_) => ContentSync()),
      ],
      child: MaterialApp(
        title: 'Kid Smile',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        // One shared animated backdrop behind every route; screens use
        // transparent scaffolds so it shows through. The theme is swapped
        // per device class here (above the Navigator, so every route sees
        // it) and follows rotation / window resizes.
        builder: (context, child) => ClampTextScale(
          child: Theme(
            data: AppTheme.themeFor(context.screenClass),
            child: KidBackground(child: child!),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
