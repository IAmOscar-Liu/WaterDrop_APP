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
