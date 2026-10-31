import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/assessment_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/care_provider.dart';
import 'providers/eye_scan_provider.dart';
import 'providers/foot_scan_provider.dart';
import 'providers/history_provider.dart';
import 'providers/multi_modal_provider.dart';
import 'providers/nav_provider.dart';
import 'providers/scan_data_provider.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';

class DiabeticApp extends StatelessWidget {
  const DiabeticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NavProvider()),
        ChangeNotifierProvider(create: (_) => ScanDataProvider()),
        ChangeNotifierProvider(create: (_) => AssessmentProvider()),
        ChangeNotifierProvider(create: (_) => FootScanProvider()),
        ChangeNotifierProvider(create: (_) => EyeScanProvider()),
        ChangeNotifierProvider(create: (_) => CareProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => MultiModalProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: AppRoutes.splash,
        routes: AppRoutes.routes,
      ),
    );
  }
}
