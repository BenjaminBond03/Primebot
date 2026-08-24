import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:primebot_frontend/Screens/auth_gate.dart';
import 'package:primebot_frontend/Screens/login.dart';
import 'package:primebot_frontend/Screens/signup.dart';
import 'package:primebot_frontend/Screens/main_shell.dart';
import 'package:primebot_frontend/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  NotificationService.instance.requestPermissions();
  runApp(const Primebot());
}

class Primebot extends StatelessWidget {
  const Primebot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthGate(),
        '/login': (context) => const Login(),
        '/signup': (context) => const Signup(),
        '/chat': (context) => const MainShell(),
      },
    );
  }
}
