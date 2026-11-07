import 'package:flutter/material.dart';
import '../utils/constants.dart';

class CustomFooter extends StatelessWidget {
  const CustomFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0.0),
      child: Container(
        height: 28.0,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppConstants.bgWhite,
        ),
        child: const Text(
          AppConstants.copyrightFooter,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppConstants.textMuted,
            fontSize: 11,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
