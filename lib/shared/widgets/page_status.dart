import 'package:flutter/material.dart';

class PageLoading extends StatelessWidget {
  const PageLoading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(text, style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class PageError extends StatelessWidget {
  const PageError(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: TextStyle(color: Colors.white)),
    );
  }
}

/// Empty list content. The caller supplies any outer centering or scrolling.
class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.sentiment_dissatisfied, size: 48, color: Colors.white),
        const SizedBox(height: 12),
        Text(text, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
