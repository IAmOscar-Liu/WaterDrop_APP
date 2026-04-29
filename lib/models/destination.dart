import 'package:flutter/material.dart';

class Destination {
  const Destination({
    required this.label,
    required this.icon,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final int badgeCount;
}
