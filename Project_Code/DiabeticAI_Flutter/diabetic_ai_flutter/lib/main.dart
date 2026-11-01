// NOTE: This file is a Flutter default scaffold placeholder.
// The REAL DiabeticAI application entry point is:
//   Project_Code/DiabeticAI_Flutter/lib/main.dart
// Do NOT run this file as your app.

import 'package:flutter/material.dart';

void main() {
  runApp(const PlaceholderApp());
}

class PlaceholderApp extends StatelessWidget {
  const PlaceholderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Wrong entry point.\nRun DiabeticAI_Flutter/lib/main.dart instead.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
