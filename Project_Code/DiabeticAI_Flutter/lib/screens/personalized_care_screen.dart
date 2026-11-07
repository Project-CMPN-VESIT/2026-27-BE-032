import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prediction_result.dart';
import '../providers/care_provider.dart';
import '../providers/multi_modal_provider.dart';
import '../utils/constants.dart';
import '../widgets/custom_footer.dart';
import '../widgets/custom_header.dart';

class PersonalizedCareScreen extends StatelessWidget {
  const PersonalizedCareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final multiModal = Provider.of<MultiModalProvider>(context);
    final careProvider = Provider.of<CareProvider>(context);

    // Auto-sync care plan with latest multimodal screening result if present
    if (multiModal.latestPrediction != null &&
        careProvider.currentCarePlan.riskLevel !=
            multiModal.latestPrediction!.riskLevel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        careProvider.updateFromPrediction(multiModal.latestPrediction!);
      });
    }

    final carePlan = careProvider.currentCarePlan;

    // Theme color based on risk level
    final Color riskColor = switch (carePlan.riskLevel) {
      RiskLevel.healthy => AppConstants.statusHealthy,
      RiskLevel.prediabetic || RiskLevel.borderline => AppConstants.statusPrediabetic,
      _ => AppConstants.statusDiabetic,
    };

    final Color riskBgColor = switch (carePlan.riskLevel) {
      RiskLevel.healthy => AppConstants.statusHealthyBg,
      RiskLevel.prediabetic || RiskLevel.borderline => AppConstants.statusPrediabeticBg,
      _ => AppConstants.statusDiabeticBg,
    };

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
                      'Personalized Care Plan',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Status Summary Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: riskBgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: riskColor.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            carePlan.riskLevel == RiskLevel.healthy
                                ? Icons.check_circle
                                : (carePlan.riskLevel == RiskLevel.highRisk ||
                                        carePlan.riskLevel == RiskLevel.diabetic
                                    ? Icons.warning_rounded
                                    : Icons.info_outline),
                            color: riskColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  switch (carePlan.riskLevel) {
                                    RiskLevel.healthy => 'HEALTHY / NORMAL CARE PROTOCOL',
                                    RiskLevel.prediabetic => 'PREDIABETIC / EARLY RISK INTERVENTION',
                                    RiskLevel.borderline => 'BORDERLINE CLINICAL MONITORING PLAN',
                                    _ => 'HIGH RISK / DIABETIC CLINICAL PROTOCOL',
                                  },
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: riskColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  carePlan.statusSummary,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppConstants.textPrimary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Doctor Consultation & Follow-up
                    if (carePlan.doctorFollowUpSchedule.isNotEmpty)
                      Card(
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month, color: AppConstants.primaryBlue, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Clinical Follow-Up Schedule',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppConstants.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      carePlan.doctorFollowUpSchedule,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: riskColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Emergency Warnings if any
                    if (carePlan.emergencyWarnings.isNotEmpty) ...[
                      _buildCareCard(
                        title: 'Clinical Warnings & Urgent Flags',
                        icon: Icons.emergency,
                        items: carePlan.emergencyWarnings,
                        accentColor: AppConstants.statusDiabetic,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Foot Care Card
                    if (carePlan.footCareAdvice.isNotEmpty) ...[
                      _buildCareCard(
                        title: 'Diabetic Foot Care & Ulcer Management',
                        icon: Icons.personal_injury_outlined,
                        items: carePlan.footCareAdvice,
                        accentColor: carePlan.riskLevel == RiskLevel.healthy
                            ? AppConstants.primaryBlue
                            : AppConstants.statusPrediabetic,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Eye Care Card
                    if (carePlan.eyeCareAdvice.isNotEmpty) ...[
                      _buildCareCard(
                        title: 'Retinal & Ophthalmic Care Guidance',
                        icon: Icons.remove_red_eye_outlined,
                        items: carePlan.eyeCareAdvice,
                        accentColor: carePlan.riskLevel == RiskLevel.healthy
                            ? AppConstants.primaryBlue
                            : AppConstants.statusPrediabetic,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Nutrition Card
                    _buildCareCard(
                      title: 'Nutrition & Dietary Guidelines',
                      icon: Icons.restaurant_menu,
                      items: carePlan.dietPlan,
                    ),
                    const SizedBox(height: 12),

                    // Exercise Card
                    _buildCareCard(
                      title: 'Physical Activity & Exercise Routine',
                      icon: Icons.directions_run,
                      items: carePlan.exercisePlan,
                    ),
                    const SizedBox(height: 12),

                    // Lifestyle & Monitoring Card
                    _buildCareCard(
                      title: 'Glucose Monitoring & Daily Habits',
                      icon: Icons.monitor_heart_outlined,
                      items: [
                        ...carePlan.bloodSugarSchedule,
                        ...carePlan.lifestyleAdvice,
                        'Target Daily Hydration: ${carePlan.waterIntake}',
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Medication Card
                    _buildCareCard(
                      title: 'Medication & Clinical Guidance',
                      icon: Icons.medication_outlined,
                      items: carePlan.medicationReminder,
                    ),
                  ],
                ),
              ),
            ),
            const CustomFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildCareCard({
    required String title,
    required IconData icon,
    required List<String> items,
    Color accentColor = AppConstants.primaryBlue,
  }) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: accentColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppConstants.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
