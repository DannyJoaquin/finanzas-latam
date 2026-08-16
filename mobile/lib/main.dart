import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/storage_keys.dart';
import 'core/services/fcm_service.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Optionally open preference boxes on startup
  await Hive.openBox<String>(StorageKeys.preferencesBox);

  // Initialize local notifications
  await NotificationService.instance.initialize();

  // Initialize Firebase if native config is present.
  final firebaseInitialized = await _initializeFirebase();
  if (firebaseInitialized) {
    await FcmService.instance.initialize();
  }

  runApp(const ProviderScope(child: FinanzasApp()));
}

Future<bool> _initializeFirebase() async {
  try {
    if (kIsWeb) {
      const apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
      const appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
      const messagingSenderId =
          String.fromEnvironment('FIREBASE_WEB_MESSAGING_SENDER_ID');
      const projectId = String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');

      if (apiKey.isEmpty ||
          appId.isEmpty ||
          messagingSenderId.isEmpty ||
          projectId.isEmpty) {
        debugPrint('[FCM] Firebase Web config missing; push disabled');
        return false;
      }

      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          authDomain: String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN'),
          storageBucket: String.fromEnvironment('FIREBASE_WEB_STORAGE_BUCKET'),
          measurementId: String.fromEnvironment('FIREBASE_WEB_MEASUREMENT_ID'),
        ),
      );
      return true;
    }

    await Firebase.initializeApp();
    return true;
  } catch (e) {
    debugPrint('[FCM] Firebase init skipped: $e');
    return false;
  }
}

class FinanzasApp extends ConsumerWidget {
  const FinanzasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final theme = ref.watch(themeNotifierProvider);

    return MaterialApp.router(
      title: 'Zentri',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: theme,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('es'),
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],
    );
  }
}
