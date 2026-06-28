import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show MainContainer, AppColors;
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.bgGray,
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.navyBlue,
              ),
            ),
          );
        }
        if (snapshot.hasData) {
          return const MainContainer();
        }
        return const LoginScreen();
      },
    );
  }
}
