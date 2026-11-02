import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prediction_result.dart';
import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../providers/nav_provider.dart';
import '../routes/app_routes.dart';
import '../services/firestore_service.dart';
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
  Future<void> _confirmClearHistory(String uid) async {
    final clearHistory = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear all your history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (clearHistory != true || !mounted) return;

    try {
      await Provider.of<HistoryProvider>(context, listen: false)
          .clearHistory(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('History cleared.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FirestoreService.userFacingError(
            error,
            operation: 'clear prediction history',
          )),
        ),
      );
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} • $hour:$minute $period';
  }

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
    final uid = Provider.of<AuthProvider>(context).user?.uid ?? '';
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: uid.isEmpty
                            ? null
                            : () => _confirmClearHistory(uid),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Clear History'),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                    ] else if (historyProvider.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          historyProvider.errorMessage!,
                          style: const TextStyle(
                              color: AppConstants.statusDiabetic),
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
                              'Your completed assessments and screenings will appear here.',
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
                          final timestamp = item.createdAt;

                          switch (item.riskLevel) {
                            case RiskLevel.highRisk:
                            case RiskLevel.diabetic:
                              badgeColor = AppConstants.statusDiabetic;
                              badgeBg = AppConstants.statusDiabeticBg;
                              break;
                            case RiskLevel.prediabetic:
                            case RiskLevel.borderline:
                            case RiskLevel.inconclusive:
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
                                          item.historyStatusLabel,
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
                                    timestamp == null
                                        ? '${item.date} • ${item.time}'
                                        : _formatTimestamp(timestamp),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppConstants.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.historyStatusLabel,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppConstants.textSecondary,
                                    ),
                                  ),
                                  if (item.assessmentScore != null ||
                                      item.retinaRiskPercentage != null ||
                                      item.footRiskPercentage != null ||
                                      (item.footFinding?.isNotEmpty ?? false) ||
                                      (item.type ==
                                              PredictionType.multiModalCombined &&
                                          (item.retinaResult.isNotEmpty ||
                                              item.footResult.isNotEmpty))) ...[
                                    const Divider(height: 16),
                                    if (item.assessmentScore != null)
                                      Text(
                                        'Diabetes assessment score: '
                                        '${item.assessmentScore!.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppConstants.textSecondary),
                                      ),
                                    if (item.type ==
                                            PredictionType.multiModalCombined &&
                                        item.retinaResult.isNotEmpty)
                                      Text(
                                        'Retina result: ${item.retinaStatusLabel}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppConstants.textSecondary),
                                      ),
                                    if (item.type ==
                                            PredictionType.multiModalCombined &&
                                        item.footResult.isNotEmpty)
                                      Text(
                                        'Foot result: ${item.footStatusLabel}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppConstants.textSecondary),
                                      ),
                                    if (item.retinaRiskPercentage != null)
                                      Text(
                                        'Retina risk score: '
                                        '${item.retinaRiskPercentage!.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppConstants.textSecondary),
                                      ),
                                    if (item.footRiskPercentage != null)
                                      Text(
                                        'Foot risk score: '
                                        '${item.footRiskPercentage!.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppConstants.textSecondary),
                                      ),
                                    if (item.footFinding?.isNotEmpty ?? false)
                                      Text(
                                        'Finding: ${item.footFinding}',
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
