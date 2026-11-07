import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prediction_result.dart';
import '../providers/auth_provider.dart';
import '../providers/multi_modal_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/scan_data_provider.dart';
import '../routes/app_routes.dart';
import '../utils/constants.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/custom_footer.dart';
import '../widgets/custom_header.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Set Home as active nav index
      Provider.of<NavProvider>(context, listen: false).setIndex(0);
      // Load latest scan data from Firestore
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.user != null) {
        Provider.of<ScanDataProvider>(context, listen: false)
            .loadForUser(auth.user!.uid);
        Provider.of<MultiModalProvider>(context, listen: false)
            .loadLatestPredictionForUser(auth.user!.uid);
      }
    });
  }

  String _cleanFirstName(String? rawName, String? email) {
    String name = rawName?.trim() ?? '';
    if (name.isEmpty && email != null && email.isNotEmpty) {
      name = email.split('@').first;
    } else if (name.contains('@')) {
      name = name.split('@').first;
    }
    if (name.isEmpty) return '';
    String first = name.split(' ').first.split('.').first.split('_').first;
    first = first.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (first.isEmpty) return '';
    final lower = first.toLowerCase();
    if (lower.startsWith('priya')) return 'Priya';
    return first[0].toUpperCase() + first.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final firstName = _cleanFirstName(user?.fullName, user?.email);
    final greetingText = firstName.isNotEmpty ? 'Hello $firstName' : 'Hello';
    final navProvider = Provider.of<NavProvider>(context);

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
                    // Greeting
                    Text(
                      greetingText,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Your multi-modal AI screening overview',
                      style: TextStyle(
                          fontSize: 13, color: AppConstants.textSecondary),
                    ),
                    const SizedBox(height: 20),

                    const SizedBox(height: 10),

                    // ── Latest Prediction Summary ─────────────────────────
                    Consumer2<MultiModalProvider, ScanDataProvider>(
                      builder: (ctx, multiModal, scanData, _) {
                        final latest = multiModal.latestPrediction;
                        final riskColor = latest == null
                            ? AppConstants.textSecondary
                            : (latest.riskLevel == RiskLevel.healthy
                                ? AppConstants.statusHealthy
                                : (latest.riskLevel == RiskLevel.prediabetic ||
                                        latest.riskLevel == RiskLevel.borderline
                                    ? AppConstants.statusPrediabetic
                                    : AppConstants.statusDiabetic));
                        final riskBackground =
                            latest?.riskLevel == RiskLevel.healthy
                                ? AppConstants.statusHealthyBg
                                : (latest == null
                                    ? Colors.white
                                    : (latest.riskLevel == RiskLevel.prediabetic ||
                                            latest.riskLevel == RiskLevel.borderline
                                        ? AppConstants.statusPrediabeticBg
                                        : AppConstants.statusDiabeticBg));

                        return Column(
                          children: [
                            if (scanData.loadError != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  scanData.loadError!,
                                  style: const TextStyle(
                                    color: AppConstants.statusDiabetic,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (latest != null) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.auto_awesome,
                                                color: AppConstants.primaryBlue,
                                                size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'Latest Multi-Modal Screening',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14),
                                            ),
                                          ],
                                        ),
                                        Flexible(
                                          child: Text(
                                            latest.overallStatusLabel,
                                            textAlign: TextAlign.end,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: riskColor,
                                                fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Retina: ${latest.retinaStatusLabel}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color:
                                                    AppConstants.textSecondary),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Foot: ${latest.footStatusLabel}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color:
                                                    AppConstants.textSecondary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.5,
                              children: [
                                _buildStatCard(
                                  title: 'Total Scans',
                                  value: scanData.isLoading
                                      ? 'Loading...'
                                      : (scanData.loadError != null
                                          ? 'Unavailable'
                                          : (scanData.totalScans == 0
                                              ? 'No scans yet'
                                              : scanData.totalScans
                                                      ?.toString() ??
                                                  'Unavailable')),
                                  bgColor: const Color(0xFFEFF6FF),
                                  accentColor: AppConstants.primaryBlue,
                                  icon: Icons.analytics_outlined,
                                ),
                                _buildStatCard(
                                  title: 'Risk Level',
                                  value: latest?.overallStatusLabel ??
                                      (scanData.loadError == null
                                          ? 'No assessment yet'
                                          : 'Unavailable'),
                                  bgColor: riskBackground,
                                  accentColor: riskColor,
                                  icon: Icons.speed_outlined,
                                ),
                                _buildStatCard(
                                  title: 'BMI Index',
                                  value: scanData.isLoading
                                      ? 'Loading...'
                                      : (scanData.loadError != null
                                          ? 'Unavailable'
                                          : (scanData.bmi == null
                                              ? 'Not measured'
                                              : scanData.bmi!
                                                  .toStringAsFixed(1))),
                                  bgColor: AppConstants.statusPrediabeticBg,
                                  accentColor: AppConstants.statusPrediabetic,
                                  icon: Icons.monitor_weight_outlined,
                                ),
                                _buildStatCard(
                                  title: 'Avg Glucose',
                                  value: 'Not recorded',
                                  bgColor: AppConstants.accentCyanLight,
                                  accentColor: AppConstants.accentCyan,
                                  icon: Icons.water_drop_outlined,
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    _buildHeroBanner(),
                    const SizedBox(height: 24),

                    // Services Grid
                    const Text(
                      'AI Services',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.35,
                      children: [
                        _buildServiceCard(
                          context,
                          title: 'Foot Ulcer',
                          icon: Icons.accessibility_new,
                          route: AppRoutes.footUlcer,
                        ),
                        _buildServiceCard(
                          context,
                          title: 'Retina Scan',
                          icon: Icons.remove_red_eye_outlined,
                          route: AppRoutes.retinaDetection,
                        ),
                        _buildServiceCard(
                          context,
                          title: 'Assessment',
                          icon: Icons.list_alt,
                          route: AppRoutes.diabetesAssessment,
                        ),
                        _buildServiceCard(
                          context,
                          title: 'Care Plan',
                          icon: Icons.favorite_border,
                          route: AppRoutes.personalizedCare,
                        ),
                      ],
                    ),
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
                if (index == 1) {
                  Navigator.pushNamed(context, AppRoutes.diabetesAssessment);
                }
                if (index == 2) {
                  Navigator.pushNamed(context, AppRoutes.history);
                }
                if (index == 3) {
                  Navigator.pushNamed(context, AppRoutes.profile);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color bgColor,
    required Color accentColor,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppConstants.textSecondary,
                ),
              ),
              Icon(icon, color: accentColor, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppConstants.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      height: 155,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF2563EB), Color(0xFF06B6D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryBlue.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'AI HEALTHCARE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'AI-Powered Diabetes Screening',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Fast • Accurate • Personalized',
                          style: TextStyle(
                            color: Color(0xFFE0F2FE),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Image.asset(
                    'assets/images/ai_banner.png',
                    height: 110,
                    width: 110,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        child: const Icon(
                          Icons.medical_services_outlined,
                          size: 48,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String route,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.pushNamed(context, route),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppConstants.primaryBlue, size: 30),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
