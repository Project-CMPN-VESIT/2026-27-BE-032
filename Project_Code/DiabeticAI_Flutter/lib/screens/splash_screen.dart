import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../utils/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgWhite,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Large Transparent Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppConstants.primaryBlueLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.health_and_safety,
                  color: AppConstants.primaryBlue,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              // App Name
              const Text(
                AppConstants.appName,
                style: TextStyle(
                  color: AppConstants.textPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Subtitle
              const Text(
                AppConstants.appSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppConstants.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 48),
              // Modern Loading Animation
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppConstants.accentCyan),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
