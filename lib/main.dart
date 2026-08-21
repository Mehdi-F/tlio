import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/library_service.dart';
import 'services/link_service.dart';
import 'services/book_service.dart';
import 'services/manga_service.dart';
import 'providers/auth_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/library_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  runApp(const TlioApp());
}

class TlioApp extends StatelessWidget {
  const TlioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => BookService()),
        Provider(create: (_) => MangaService()),
        Provider(create: (_) => LibraryService()),
        Provider(create: (_) => LinkService()),
        ChangeNotifierProvider(create: (_) => AuthProvider(AuthService())),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (context) => LibraryProvider(context.read<LibraryService>())),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          ThemeMode themeMode = ThemeMode.dark;
          if (settings.themeMode == AppThemeMode.light) {
            themeMode = ThemeMode.light;
          } else if (settings.themeMode == AppThemeMode.auto) {
            themeMode = ThemeMode.system;
          }

          return MaterialApp(
            title: 'The Library Is Open',
            theme: buildAppTheme(isDark: false),
            darkTheme: buildAppTheme(isDark: true),
            themeMode: themeMode,
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const LoginScreen();
    }
    context.read<LibraryProvider>().watch(user.uid);
    context.read<LinkService>().ensureProfile(
          uid: user.uid,
          displayName: user.displayName,
          email: user.email,
          photoUrl: user.photoURL,
        );
    return const HomeShell();
  }
}
