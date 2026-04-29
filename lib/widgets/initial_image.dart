import 'package:flutter/material.dart';

class InitialImage extends StatelessWidget {
  const InitialImage({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final String letter = (name.isNotEmpty
        ? name.trim()[0].toUpperCase()
        : '?');

    // Soft, deterministic gradient based on the hash of the name
    final int h = name.hashCode;
    final Color c1 = Color(0xFF80DEEA + (h & 0x0000FF));
    final Color c2 = Color(0xFFB39DDB + ((h >> 8) & 0x0000FF));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2],
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: Theme.of(context).textTheme.displayLarge?.fontSize ?? 56,
          ),
        ),
      ),
    );
  }
}
