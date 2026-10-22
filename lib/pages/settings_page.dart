import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/provider/session_logout_provider.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('This is Settings Page', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.push(Routes.mineProfilePage),
              child: const Text('View Profile Page'),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => context.push(Routes.detailsPage),
              child: const Text('View Details Page'),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => signOutWithFeedback(context, ref),
              child: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}
