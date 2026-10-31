import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prediction_result.dart';
import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../providers/nav_provider.dart';
import '../routes/app_routes.dart';
import '../utils/constants.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/custom_footer.dart';
import '../widgets/custom_header.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NavProvider>(context, listen: false).setIndex(2);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.user != null) {
        Provider.of<HistoryProvider>(context, listen: false)
            .fetchHistoryForUser(auth.user!.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyProvider = Provider.of<HistoryProvider>(context);
    final navProvider = Provider.of<NavProvider>(context);
    final history = historyProvider.history;

    return Scaffold(
      appBar: const CustomHeader(),
      backgroundColor: AppConstants.bgLightSlate,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Prediction Timeline History',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'User-isolated archive of past AI diabetic screening reports',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppConstants.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (historyProvider.isLoading) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ] else if (history.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(30),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.history,
                                size: 48, color: AppConstants.textMuted),
                            SizedBox(height: 12),
                            Text(
                              'No prediction records found yet.',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.textSecondary),
                            ),
                            Text(
                              'Complete Assessment, Retina, and Foot scans to generate your multi-modal prediction report.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12, color: AppConstants.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ...history.map(
                        (item) {
                          Color badgeColor;
                          Color badgeBg;
                          final retinaRisk = item.retinaRiskPercentage ??
                              (item.type == PredictionType.retinaScan
                                  ? item.riskPercentage
                                  : null);
                          final footRisk = item.footRiskPercentage ??
                              (item.type == PredictionType.footUlcerScan
                                  ? item.riskPercentage
                                  : null);

                          switch (item.riskLevel) {
                            case RiskLevel.highRisk:
                            case RiskLevel.diabetic:
                              badgeColor = AppConstants.statusDiabetic;
                              badgeBg = AppConstants.statusDiabeticBg;
                              break;
                            case RiskLevel.prediabetic:
                              badgeColor = AppConstants.statusPrediabetic;
                              badgeBg = AppConstants.statusPrediabeticBg;
                              break;
                            case RiskLevel.healthy:
                              badgeColor = AppConstants.statusHealthy;
                              badgeBg = AppConstants.statusHealthyBg;
                              break;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppConstants.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: badgeBg,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${item.riskPercentage.toStringAsFixed(1)}% RISK',
                                          style: TextStyle(
                                            color: badgeColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.date} • ${item.time}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppConstants.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.predictionLabel,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppConstants.textSecondary,
                                    ),
                                  ),
                                  if (retinaRisk != null ||
                                      footRisk != null) ...[
                                    const Divider(height: 16),
                                    if (retinaRisk != null && retinaRisk > 0)
                                      Text(
                                        'Retina Risk: '
                                        '${retinaRisk.round()}% '
                                        '(${item.retinaResult})',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppConstants.textSecondary),
                                      ),
                                    if (footRisk != null && footRisk > 0)
                                      Text(
                                        'Foot Risk: '
                                        '${footRisk.round()}% '
                                        '(${item.footResult})',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppConstants.textSecondary),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const CustomFooter(),
            CustomBottomNav(
              currentIndex: navProvider.currentIndex,
              onTap: (index) {
                Provider.of<NavProvider>(context, listen: false)
                    .setIndex(index);
                if (index == 0) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, AppRoutes.dashboard, (route) => false);
                }
                if (index == 1) {
                  Navigator.pushNamed(context, AppRoutes.diabetesAssessment);
                }
                if (index == 3) Navigator.pushNamed(context, AppRoutes.profile);
              },
            ),
          ],
        ),
      ),
    );
  }
}
