import 'package:flutter/material.dart';

/// Placeholder identity for a cat. Real artwork replaces this later.
///
/// The three coats match the brand: cream, charcoal ink, and orange.
enum CatAppearance {
  cream(label: 'Cream', color: Color(0xFFE8C99B)),
  charcoal(label: 'Charcoal', color: Color(0xFF1B2B30)),
  ginger(label: 'Ginger', color: Color(0xFFF69337));

  const CatAppearance({required this.label, required this.color});

  final String label;
  final Color color;
}
