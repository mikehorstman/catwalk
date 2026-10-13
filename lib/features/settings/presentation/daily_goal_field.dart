import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A step-goal input shared by onboarding and Settings.
///
/// Digits only. The caller decides what to do with the parsed value.
class DailyGoalField extends StatelessWidget {
  const DailyGoalField({
    required this.controller,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(
        labelText: 'Steps',
        border: OutlineInputBorder(),
        suffixText: 'steps',
      ),
      onChanged: onChanged,
    );
  }
}
