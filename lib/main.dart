import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'config.dart';
import 'data/demo_backend.dart';
import 'data/firebase_backend.dart';
import 'firebase_options.dart';
import 'platform/push.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppController controller;
  if (kDemo) {
    controller = AppController(
      auth: DemoAuthService(signedIn: demoParams['screen'] != 'auth'),
      repositoryFor: (_) => DemoTaskRepository(),
      push: FakePushService(),
    );
    final theme = demoParams['theme'];
    if (theme == 'dark') controller.setThemeMode(ThemeMode.dark);
    if (theme == 'light') controller.setThemeMode(ThemeMode.light);
  } else {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    final db = FirebaseFirestore.instance;
    db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    controller = AppController(
      auth: FirebaseAuthService(FirebaseAuth.instance),
      repositoryFor: (user) => FirestoreTaskRepository(db, user.uid),
      push: FirebasePushService(),
    );
  }

  runApp(TaskTrackerApp(controller: controller));
}

class TaskTrackerApp extends StatelessWidget {
  const TaskTrackerApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => MaterialApp(
          title: 'Task Tracker',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: controller.themeMode,
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final Widget child;
    if (!app.authResolved) {
      child = const _Splash(key: ValueKey('splash'));
    } else if (app.user == null) {
      child = const AuthScreen(key: ValueKey('auth'));
    } else {
      child = HomeScreen(key: ValueKey('home-${app.user!.uid}'));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: child,
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 56),
            const SizedBox(height: 20),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.circular(4),
                color: scheme.primary,
                backgroundColor: scheme.primaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
