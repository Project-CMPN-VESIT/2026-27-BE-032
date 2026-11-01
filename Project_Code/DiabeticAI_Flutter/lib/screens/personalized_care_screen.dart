import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/care_provider.dart';
import '../utils/constants.dart';
import '../widgets/custom_footer.dart';
import '../widgets/custom_header.dart';

class PersonalizedCareScreen extends StatelessWidget {
  const PersonalizedCareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final carePlan = Provider.of<CareProvider>(context).currentCarePlan;

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
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      carePlan.statusSummary,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppConstants.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Diet Card
                    _buildCareCard(
                      title: 'Nutrition & Diet Plan',
                      icon: Icons.restaurant_menu,
                      items: carePlan.dietPlan,
                    ),
                    const SizedBox(height: 12),
                    // Exercise Card
                    _buildCareCard(
                      title: 'Exercise & Physical Activity',
                      icon: Icons.directions_run,
                      items: carePlan.exercisePlan,
                    ),
                    const SizedBox(height: 12),
                    // Medication Card
                    _buildCareCard(
                      title: 'Medication & Supplements',
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
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppConstants.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16, color: AppConstants.primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 13, color: AppConstants.textSecondary),
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
