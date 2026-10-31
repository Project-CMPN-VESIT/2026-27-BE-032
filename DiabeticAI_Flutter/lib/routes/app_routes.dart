import 'package:flutter/material.dart';
import '../screens/dashboard_screen.dart';
import '../screens/diabetes_assessment_screen.dart';
import '../screens/foot_ulcer_screen.dart';
import '../screens/history_screen.dart';
import '../screens/login_screen.dart';
import '../screens/personalized_care_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/register_screen.dart';
import '../screens/retina_detection_screen.dart';
import '../screens/splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';
  static const String diabetesAssessment = '/assessment';
  static const String footUlcer = '/foot-ulcer';
  static const String retinaDetection = '/retina-detection';
  static const String personalizedCare = '/care-plan';
  static const String history = '/history';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> get routes {
    return {
      splash: (context) => const SplashScreen(),
      login: (context) => const LoginScreen(),
      register: (context) => const RegisterScreen(),
      dashboard: (context) => const DashboardScreen(),
      diabetesAssessment: (context) => const DiabetesAssessmentScreen(),
      footUlcer: (context) => const FootUlcerScreen(),
      retinaDetection: (context) => const RetinaDetectionScreen(),
      personalizedCare: (context) => const PersonalizedCareScreen(),
      history: (context) => const HistoryScreen(),
      profile: (context) => const ProfileScreen(),
    };
  }
}
