import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/service/google_auth_service.dart';

class ProfilePage extends StatelessWidget {
  ProfilePage({super.key});

  final User? user = GoogleAuthService().getCurrentUser();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profile'), leading: BackButton()),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 80,
            child: Icon(Icons.person_outlined, size: 80),
          ),
          const SizedBox(height: 20),
          Text(
            user?.displayName ?? "N/A",
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(user?.email ?? "N/A"),
        ],
      ),
    ),
  );
}
