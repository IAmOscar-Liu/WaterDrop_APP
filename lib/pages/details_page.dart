import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:go_router/go_router.dart';

class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Details')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('This is Details Page', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go(Routes.mineProfilePage),
              child: const Text('View Profile Page'),
            ),
          ],
        ),
      ),
    );
  }
}
