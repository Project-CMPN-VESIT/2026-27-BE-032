import 'package:flutter/material.dart';
import '../utils/constants.dart';

class CustomHeader extends StatelessWidget implements PreferredSizeWidget {
  const CustomHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(60.0);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppConstants.bgWhite,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 60.0,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      // Left: Transparent Logo (40px)
                      Container(
                        width: 40.0,
                        height: 40.0,
                        decoration: BoxDecoration(
                          color: AppConstants.primaryBlueLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.health_and_safety,
                          color: AppConstants.primaryBlue,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      // Right: Title & Subtitle
                      const Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppConstants.appName,
                              style: TextStyle(
                                color: AppConstants.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'AI-Powered Early Detection of Diabetes',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppConstants.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Single Thin Light Gray Divider
              Container(
                height: 1.0,
                color: AppConstants.dividerColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
