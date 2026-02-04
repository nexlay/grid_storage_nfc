import 'package:flutter/material.dart';
import 'package:grid_storage_nfc/core/services/auth_service.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text("Zaloguj się, aby uzyskać dostęp"),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                AuthService().signInWithGoogle();
              },
              icon: const Icon(Icons.login),
              label: const Text("Zaloguj przez Google"),
            ),
          ],
        ),
      ),
    );
  }
}
