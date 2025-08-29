import 'package:deepsage/providers/theme_provider.dart';
import 'package:deepsage/screens/auth/loginscreen.dart';
import 'package:deepsage/screens/auth/loginscreen.dart';
import 'package:deepsage/screens/chat_screen.dart';
import 'package:deepsage/services/auth_service.dart';
import 'package:deepsage/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'DeepSage',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            // home: const ChatScreen(),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // StorageService.instance.clearAuth();
      AuthServices.instance.isSignedIn.then((v) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => v ? ChatScreen() : LoginScreen()),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Image.asset('assets/splash_logo.png', scale: 4)),
    );
  }
}
