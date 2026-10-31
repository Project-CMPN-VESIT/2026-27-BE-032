import 'package:flutter/material.dart';
import '../utils/constants.dart';

class CustomFooter extends StatelessWidget {
  const CustomFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24.0,
      color: AppConstants.bgWhite,
      alignment: Alignment.center,
      child: const Text(
        AppConstants.copyrightFooter,
        maxLines: 1,
        style: TextStyle(
          color: AppConstants.textMuted,
          fontSize: 11,
        ),
      ),
    );
  }
}
