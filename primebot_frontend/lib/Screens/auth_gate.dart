import 'package:flutter/material.dart';
import 'package:primebot_frontend/Screens/get_started.dart';
import 'package:primebot_frontend/Screens/main_shell.dart';
import 'package:primebot_frontend/services/user_session.dart';

/// App entry point: sends a device straight to the chat if it already has a
/// saved session (from a prior login/signup), otherwise shows onboarding.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Object>?>(
      future: UserSession.instance.getUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5F7FA),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data != null ? const MainShell() : const GetStarted();
      },
    );
  }
}
