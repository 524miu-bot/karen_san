import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName ?? user.email ?? 'ゲスト';
    return Scaffold(
      appBar: AppBar(
        title: const Text('カレンさん'),
        actions: [
          TextButton.icon(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('ログアウト'),
          ),
        ],
      ),
      body: Center(
        child: Text(
          'ようこそ、$name さん',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
