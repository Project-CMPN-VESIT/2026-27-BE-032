import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/prediction_result.dart';
import '../providers/assessment_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/eye_scan_provider.dart';
import '../providers/foot_scan_provider.dart';
import '../providers/multi_modal_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/scan_data_provider.dart';
import '../routes/app_routes.dart';
import '../utils/constants.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/custom_footer.dart';
import '../widgets/custom_header.dart';

class DiabetesAssessmentScreen extends StatefulWidget {
  const DiabetesAssessmentScreen({super.key});

  @override
  State<DiabetesAssessmentScreen> createState() =>
      _DiabetesAssessmentScreenState();
}

class _DiabetesAssessmentScreenState extends State<DiabetesAssessmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // 1. Personal & Biometrics
  int? _sex; // 1 = Male, 0 = Female
  int? _ageCategory; // 1-13 scale
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  // 2. Medical History
  bool _highBp = false;
  bool _highChol = false;
  bool _cholCheck = false;
  bool _stroke = false;
  bool _heartDisease = false;

  // 3. Family History (Restored)
  int? _familyHistory;
  int? _familyMembersCount;
  String? _familyDiabetesType;

  // 4. Expanded Lifestyle Assessment (Restored)
  String? _sleepDuration;
  int? _sleepQuality;
  int? _stressLevel;
  String? _occupation;
  int? _dailySittingTime;
  int? _exerciseFrequency;
  int? _walkingMinutes;
  int? _waterIntake;
  int? _junkFood;
  int? _sugaryDrinks;
  int? _fruitIntake;
  int? _vegetableIntake;
  bool _smoker = false;
  int? _alcohol;

  // 5. General & Functional Health
  int? _physHlthRating;
  int? _mentHlthRating;
  bool _diffWalk = false;

  static const Map<int, String> _ageOptions = {
    1: '18 - 24 years',
    2: '25 - 29 years',
    3: '30 - 34 years',
    4: '35 - 39 years',
    5: '40 - 44 years',
    6: '45 - 49 years',
    7: '50 - 54 years',
    8: '55 - 59 years',
    9: '60 - 64 years',
    10: '65 - 69 years',
    11: '70 - 74 years',
    12: '75 - 79 years',
    13: '80 years or older',
  };

  static const Map<int, String> _healthRatingOptions = {
    1: 'Excellent',
    2: 'Good',
    3: 'Fair',
    4: 'Poor',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ScanDataProvider>(context, listen: false).clearAll();
      Provider.of<MultiModalProvider>(context, listen: false).resetWorkflow();
      Provider.of<EyeScanProvider>(context, listen: false).reset();
      Provider.of<FootScanProvider>(context, listen: false).reset();
      Provider.of<AssessmentProvider>(context, listen: false).reset();
      Provider.of<NavProvider>(context, listen: false).setIndex(1);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.user != null) {
        Provider.of<ScanDataProvider>(context, listen: false)
            .loadForUser(auth.user!.uid);
      }
    });
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AssessmentProvider>(context);
    final multiModal = Provider.of<MultiModalProvider>(context);
    final scanData = Provider.of<ScanDataProvider>(context);
    final eyeScan = Provider.of<EyeScanProvider>(context);
    final footScan = Provider.of<FootScanProvider>(context);
    final navProvider = Provider.of<NavProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final height = double.tryParse(_heightController.text) ?? 0;
    final weight = double.tryParse(_weightController.text) ?? 0;
    final bmi = provider.calculateBmi(height, weight);

    final isRetinaDone = scanData.isRetinaComplete || eyeScan.uploadSuccess;
    final isFootDone = scanData.isFootComplete || footScan.uploadSuccess;
    final isAssessmentDone = scanData.isAssessmentComplete;

    final canRunCombined = isAssessmentDone && isRetinaDone && isFootDone;

    return Scaffold(
      appBar: const CustomHeader(),
      backgroundColor: AppConstants.bgLightSlate,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Comprehensive Diabetes Assessment',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Section 1: Demographics & Biometrics
                      _buildSectionCard(
                        title: '1. Demographics & Biometrics',
                        icon: Icons.person_outline,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _sex,
                                    decoration: const InputDecoration(
                                      labelText: 'Sex',
                                      hintText: 'Select',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 1, child: Text('Male')),
                                      DropdownMenuItem(
                                          value: 0, child: Text('Female')),
                                    ],
                                    validator: (v) =>
                                        v == null ? 'Required' : null,
                                    onChanged: (val) =>
                                        setState(() => _sex = val),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _ageCategory,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Age Category',
                                      hintText: 'Select Age',
                                    ),
                                    items: _ageOptions.entries
                                        .map((e) => DropdownMenuItem(
                                              value: e.key,
                                              child: Text(e.value,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            ))
                                        .toList(),
                                    validator: (v) =>
                                        v == null ? 'Required' : null,
                                    onChanged: (val) =>
                                        setState(() => _ageCategory = val),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _heightController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Height (cm)',
                                      hintText: 'e.g. 170',
                                    ),
                                    onChanged: (_) => setState(() {}),
                                    validator: (v) {
                                      final n = double.tryParse(v ?? '');
                                      if (n == null || n <= 0) {
                                        return 'Valid height required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _weightController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Weight (kg)',
                                      hintText: 'e.g. 75',
                                    ),
                                    onChanged: (_) => setState(() {}),
                                    validator: (v) {
                                      final n = double.tryParse(v ?? '');
                                      if (n == null || n <= 0) {
                                        return 'Valid weight required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppConstants.primaryBlueLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppConstants.primaryBlue
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Calculated BMI (Auto)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppConstants.primaryBlue,
                                    ),
                                  ),
                                  Text(
                                    bmi > 0 ? bmi.toStringAsFixed(1) : '--',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppConstants.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Section 2: Medical History
                      _buildSectionCard(
                        title: '2. Medical History',
                        icon: Icons.medical_information_outlined,
                        child: Column(
                          children: [
                            _buildSwitchTile(
                              title: 'High Blood Pressure',
                              subtitle: 'Told by doctor or health professional',
                              value: _highBp,
                              onChanged: (v) => setState(() => _highBp = v),
                            ),
                            _buildSwitchTile(
                              title: 'High Cholesterol',
                              subtitle: 'Told by doctor or health professional',
                              value: _highChol,
                              onChanged: (v) => setState(() => _highChol = v),
                            ),
                            _buildSwitchTile(
                              title: 'Cholesterol Checked',
                              subtitle: 'Checked within past 5 years',
                              value: _cholCheck,
                              onChanged: (v) => setState(() => _cholCheck = v),
                            ),
                            _buildSwitchTile(
                              title: 'Stroke History',
                              subtitle: 'Ever diagnosed with a stroke',
                              value: _stroke,
                              onChanged: (v) => setState(() => _stroke = v),
                            ),
                            _buildSwitchTile(
                              title: 'Coronary Heart Disease',
                              subtitle: 'Heart attack or angina history',
                              value: _heartDisease,
                              onChanged: (v) =>
                                  setState(() => _heartDisease = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Section 3: Family History (Restored)
                      _buildSectionCard(
                        title: '3. Family History',
                        icon: Icons.family_restroom_outlined,
                        child: Column(
                          children: [
                            DropdownButtonFormField<int>(
                              initialValue: _familyHistory,
                              decoration: const InputDecoration(
                                  labelText: 'Family Diabetes History'),
                              items: const [
                                DropdownMenuItem(value: 0, child: Text('None')),
                                DropdownMenuItem(
                                    value: 1, child: Text('Father')),
                                DropdownMenuItem(
                                    value: 2, child: Text('Mother')),
                                DropdownMenuItem(
                                    value: 3, child: Text('Brother / Sister')),
                                DropdownMenuItem(
                                    value: 4,
                                    child: Text('Multiple family members')),
                              ],
                              onChanged: (val) =>
                                  setState(() => _familyHistory = val),
                            ),
                            if ((_familyHistory ?? 0) > 0) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      initialValue: _familyMembersCount,
                                      decoration: const InputDecoration(
                                          labelText: 'Affected Members'),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 1, child: Text('1 Member')),
                                        DropdownMenuItem(
                                            value: 2, child: Text('2 Members')),
                                        DropdownMenuItem(
                                            value: 3,
                                            child: Text('3+ Members')),
                                      ],
                                      onChanged: (val) => setState(
                                          () => _familyMembersCount = val),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _familyDiabetesType,
                                      decoration: const InputDecoration(
                                          labelText: 'Diabetes Type'),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'Type 1',
                                            child: Text('Type 1')),
                                        DropdownMenuItem(
                                            value: 'Type 2',
                                            child: Text('Type 2')),
                                        DropdownMenuItem(
                                            value: 'Gestational',
                                            child: Text('Gestational')),
                                        DropdownMenuItem(
                                            value: 'Don\'t Know',
                                            child: Text('Don\'t Know')),
                                      ],
                                      onChanged: (val) => setState(
                                          () => _familyDiabetesType = val),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Section 4: Expanded Lifestyle Assessment (Restored)
                      _buildSectionCard(
                        title: '4. Expanded Lifestyle Assessment',
                        icon: Icons.directions_run_outlined,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _exerciseFrequency,
                                    decoration: const InputDecoration(
                                        labelText: 'Physical Activity'),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 0, child: Text('None')),
                                      DropdownMenuItem(
                                          value: 1, child: Text('1–2 days/wk')),
                                      DropdownMenuItem(
                                          value: 2, child: Text('3–4 days/wk')),
                                      DropdownMenuItem(
                                          value: 3, child: Text('5+ days/wk')),
                                    ],
                                    onChanged: (val) => setState(
                                        () => _exerciseFrequency = val),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _waterIntake,
                                    decoration: const InputDecoration(
                                        labelText: 'Water Intake'),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 1, child: Text('<4 glasses')),
                                      DropdownMenuItem(
                                          value: 2, child: Text('4–6 glasses')),
                                      DropdownMenuItem(
                                          value: 3, child: Text('6–8 glasses')),
                                      DropdownMenuItem(
                                          value: 4, child: Text('>8 glasses')),
                                    ],
                                    onChanged: (val) =>
                                        setState(() => _waterIntake = val),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _fruitIntake,
                                    decoration: const InputDecoration(
                                        labelText: 'Fruit Intake'),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 0, child: Text('Never')),
                                      DropdownMenuItem(
                                          value: 1, child: Text('Sometimes')),
                                      DropdownMenuItem(
                                          value: 2, child: Text('Daily')),
                                    ],
                                    onChanged: (val) =>
                                        setState(() => _fruitIntake = val),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _vegetableIntake,
                                    decoration: const InputDecoration(
                                        labelText: 'Vegetable Intake'),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 0, child: Text('Never')),
                                      DropdownMenuItem(
                                          value: 1, child: Text('Sometimes')),
                                      DropdownMenuItem(
                                          value: 2, child: Text('Daily')),
                                    ],
                                    onChanged: (val) =>
                                        setState(() => _vegetableIntake = val),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _sleepDuration,
                                    decoration: const InputDecoration(
                                        labelText: 'Sleep Duration'),
                                    items: const [
                                      DropdownMenuItem(
                                          value: '<6 hrs',
                                          child: Text('< 6 hours')),
                                      DropdownMenuItem(
                                          value: '6-8 hrs',
                                          child: Text('6 – 8 hours')),
                                      DropdownMenuItem(
                                          value: '>8 hrs',
                                          child: Text('> 8 hours')),
                                    ],
                                    onChanged: (val) =>
                                        setState(() => _sleepDuration = val),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _stressLevel,
                                    decoration: const InputDecoration(
                                        labelText: 'Stress Level'),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 1, child: Text('Low (1)')),
                                      DropdownMenuItem(
                                          value: 2,
                                          child: Text('Moderate (2)')),
                                      DropdownMenuItem(
                                          value: 3, child: Text('High (3)')),
                                    ],
                                    onChanged: (val) =>
                                        setState(() => _stressLevel = val),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildSwitchTile(
                              title: 'Smoker',
                              subtitle: 'Smoked 100+ cigarettes in lifetime',
                              value: _smoker,
                              onChanged: (v) => setState(() => _smoker = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Section 5: General & Functional Health
                      _buildSectionCard(
                        title: '5. General & Functional Health',
                        icon: Icons.health_and_safety_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _physHlthRating,
                                    decoration: const InputDecoration(
                                        labelText: 'Physical Health'),
                                    items: _healthRatingOptions.entries
                                        .map((e) => DropdownMenuItem(
                                            value: e.key, child: Text(e.value)))
                                        .toList(),
                                    onChanged: (val) =>
                                        setState(() => _physHlthRating = val),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _mentHlthRating,
                                    decoration: const InputDecoration(
                                        labelText: 'Mental Health'),
                                    items: _healthRatingOptions.entries
                                        .map((e) => DropdownMenuItem(
                                            value: e.key, child: Text(e.value)))
                                        .toList(),
                                    onChanged: (val) =>
                                        setState(() => _mentHlthRating = val),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildSwitchTile(
                              title: 'Difficulty Walking',
                              subtitle:
                                  'Serious difficulty walking or climbing stairs',
                              value: _diffWalk,
                              onChanged: (v) => setState(() => _diffWalk = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Save Assessment Form Data Button
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (_formKey.currentState?.validate() ?? false) {
                            final payload = {
                              'HighBP': _highBp ? 1 : 0,
                              'HighChol': _highChol ? 1 : 0,
                              'CholCheck': _cholCheck ? 1 : 0,
                              'BMI': double.parse(bmi.toStringAsFixed(1)),
                              'Smoker': _smoker ? 1 : 0,
                              'Stroke': _stroke ? 1 : 0,
                              'HeartDiseaseorAttack': _heartDisease ? 1 : 0,
                              'PhysActivity':
                                  (_exerciseFrequency ?? 0) > 0 ? 1 : 0,
                              'Fruits': (_fruitIntake ?? 0) > 0 ? 1 : 0,
                              'Veggies': (_vegetableIntake ?? 0) > 0 ? 1 : 0,
                              'HvyAlcoholConsump': (_alcohol ?? 0) >= 2 ? 1 : 0,
                              'DiffWalk': _diffWalk ? 1 : 0,
                              'Sex': _sex ?? 1,
                              'Age': _ageCategory ?? 7,
                              'FamilyHistory': _familyHistory ?? 0,
                              'FamilyMembersCount': _familyMembersCount ?? 0,
                              'FamilyDiabetesType':
                                  _familyDiabetesType ?? 'None',
                              'SleepDuration': _sleepDuration ?? '6-8 hrs',
                              'SleepQuality': _sleepQuality ?? 3,
                              'StressLevel': _stressLevel ?? 1,
                              'Occupation': _occupation ?? 'Sedentary',
                              'DailySittingTime': _dailySittingTime ?? 4,
                              'WalkingMinutes': _walkingMinutes ?? 30,
                              'JunkFood': _junkFood ?? 0,
                              'SugaryDrinks': _sugaryDrinks ?? 0,
                            };
                            final score =
                                provider.calculateAssessmentRisk(payload);

                            multiModal.setAssessmentPayload(
                                payload, score * 1.5);
                            scanData.setAssessmentData(payload, score * 1.5);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    '✓ Assessment Form Data Saved Successfully'),
                                backgroundColor: AppConstants.statusHealthy,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          scanData.isAssessmentComplete
                              ? '✓ Assessment Form Saved'
                              : 'Save Assessment Form Data',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: scanData.isAssessmentComplete
                              ? AppConstants.statusHealthy
                              : AppConstants.primaryBlue,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Section 6: Retinal Fundus Scan (Embedded) ─────────
                      _buildSectionCard(
                        title: '6. Retinal Fundus Image Scan',
                        icon: Icons.remove_red_eye_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (eyeScan.selectedImage != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  eyeScan.selectedImage!,
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else if ((scanData.retinaUrl ?? '').isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: (scanData.retinaUrl!.startsWith('http'))
                                    ? Image.network(scanData.retinaUrl!,
                                        height: 160,
                                        width: double.infinity,
                                        fit: BoxFit.cover)
                                    : Image.file(
                                        File(scanData.retinaUrl!
                                            .replaceAll('file://', '')),
                                        height: 160,
                                        width: double.infinity,
                                        fit: BoxFit.cover),
                              )
                            else
                              Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  color: AppConstants.bgLightSlate,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppConstants.cardBorder),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.remove_red_eye_outlined,
                                          size: 36,
                                          color: AppConstants.textMuted),
                                      SizedBox(height: 6),
                                      Text('No Retinal Fundus Image Selected',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppConstants.textSecondary)),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        eyeScan.pickImage(ImageSource.camera),
                                    icon: const Icon(Icons.camera_alt_outlined,
                                        size: 18),
                                    label: const Text('Camera'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        eyeScan.pickImage(ImageSource.gallery),
                                    icon: const Icon(
                                        Icons.photo_library_outlined,
                                        size: 18),
                                    label: const Text('Gallery'),
                                  ),
                                ),
                              ],
                            ),
                            if (eyeScan.selectedImage != null) ...[
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: eyeScan.isAnalyzing
                                    ? null
                                    : () async {
                                        await eyeScan.runRetinaScan(
                                            uid: auth.user?.uid ?? '');
                                        if (eyeScan.scanResult != null) {
                                          if (eyeScan.uploadedImageUrl !=
                                              null) {
                                            scanData.setRetinaData(
                                                eyeScan.uploadedImageUrl!,
                                                eyeScan.scanResult
                                                        ?.predictionLabel ??
                                                    'Healthy Fundus');
                                          }
                                          multiModal.setRetinaScan(
                                            imageFile: eyeScan.selectedImage,
                                            imageUrl:
                                                eyeScan.uploadedImageUrl ?? '',
                                          );
                                          if (eyeScan.retinaResultMap != null) {
                                            multiModal.setRetinaResultMap(
                                                eyeScan.retinaResultMap!);
                                          } else {
                                            multiModal.setRetinaPrediction(
                                              eyeScan.scanResult!.predictionLabel,
                                              confidence: eyeScan.scanResult!
                                                  .confidencePercentage,
                                            );
                                          }
                                        }
                                      },
                                icon: eyeScan.isAnalyzing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : const Icon(Icons.analytics_outlined),
                                label: Text(eyeScan.isAnalyzing
                                    ? 'Uploading & Analyzing...'
                                    : 'Analyze Retinal Image'),
                              ),
                            ],
                            if (isRetinaDone) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: AppConstants.statusHealthyBg,
                                    borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle,
                                        color: AppConstants.statusHealthy,
                                        size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '✓ Retina Scan Uploaded: ${scanData.retinaResult ?? eyeScan.scanResult?.predictionLabel ?? "Healthy Fundus"}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppConstants.statusHealthy),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Section 7: Diabetic Foot Scan (Embedded) ─────────
                      _buildSectionCard(
                        title: '7. Diabetic Foot Image Scan',
                        icon: Icons.medical_services_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (footScan.selectedImage != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  footScan.selectedImage!,
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else if ((scanData.footUrl ?? '').isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: (scanData.footUrl!.startsWith('http'))
                                    ? Image.network(scanData.footUrl!,
                                        height: 160,
                                        width: double.infinity,
                                        fit: BoxFit.cover)
                                    : Image.file(
                                        File(scanData.footUrl!
                                            .replaceAll('file://', '')),
                                        height: 160,
                                        width: double.infinity,
                                        fit: BoxFit.cover),
                              )
                            else
                              Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  color: AppConstants.bgLightSlate,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppConstants.cardBorder),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.medical_services_outlined,
                                          size: 36,
                                          color: AppConstants.textMuted),
                                      SizedBox(height: 6),
                                      Text('No Diabetic Foot Image Selected',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppConstants.textSecondary)),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        footScan.pickImage(ImageSource.camera),
                                    icon: const Icon(Icons.camera_alt_outlined,
                                        size: 18),
                                    label: const Text('Camera'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        footScan.pickImage(ImageSource.gallery),
                                    icon: const Icon(
                                        Icons.photo_library_outlined,
                                        size: 18),
                                    label: const Text('Gallery'),
                                  ),
                                ),
                              ],
                            ),
                            if (footScan.selectedImage != null) ...[
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: footScan.isAnalyzing
                                    ? null
                                    : () async {
                                        await footScan.runFootScan(
                                            uid: auth.user?.uid ?? '');
                                        if (footScan.scanResult != null) {
                                          if (footScan.uploadedImageUrl !=
                                              null) {
                                            scanData.setFootData(
                                                footScan.uploadedImageUrl!,
                                                footScan.scanResult
                                                        ?.predictionLabel ??
                                                    'Grade 0 Normal');
                                          }
                                          multiModal.setFootScan(
                                            imageFile: footScan.selectedImage,
                                            imageUrl:
                                                footScan.uploadedImageUrl ?? '',
                                          );
                                          if (footScan.footResultMap != null) {
                                            multiModal.setFootResultMap(
                                                footScan.footResultMap!);
                                          } else {
                                            multiModal.setFootPrediction(
                                              footScan
                                                  .scanResult!.predictionLabel,
                                              confidence: footScan.scanResult!
                                                  .confidencePercentage,
                                            );
                                          }
                                        }
                                      },
                                icon: footScan.isAnalyzing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : const Icon(Icons.analytics_outlined),
                                label: Text(footScan.isAnalyzing
                                    ? 'Uploading & Analyzing...'
                                    : 'Analyze Foot Image'),
                              ),
                            ],
                            if (isFootDone) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: AppConstants.statusHealthyBg,
                                    borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle,
                                        color: AppConstants.statusHealthy,
                                        size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '✓ Foot Scan Uploaded: ${scanData.footResult ?? footScan.scanResult?.predictionLabel ?? "No Ulcer Detected"}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppConstants.statusHealthy),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Multi-Modal Requirements Status Box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: canRunCombined
                              ? AppConstants.statusHealthyBg
                              : AppConstants.statusPrediabeticBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: canRunCombined
                                ? AppConstants.statusHealthy
                                    .withValues(alpha: 0.3)
                                : AppConstants.statusPrediabetic
                                    .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              canRunCombined
                                  ? '✅ All 3 Diagnostic Inputs Ready!'
                                  : 'Complete all three assessments before generating your final diabetes prediction.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: canRunCombined
                                    ? AppConstants.statusHealthy
                                    : AppConstants.statusPrediabetic,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _buildReqBadge('Assessment', isAssessmentDone),
                                const SizedBox(width: 8),
                                _buildReqBadge('Retina Scan', isRetinaDone),
                                const SizedBox(width: 8),
                                _buildReqBadge('Foot Scan', isFootDone),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Combined Predict Diabetes Button
                      ElevatedButton(
                        onPressed: (!canRunCombined || multiModal.isAnalyzing)
                            ? null
                            : () async {
                                debugPrint("--------------------------------------------------");
                                debugPrint("STEP 1: [AssessmentScreen] Calculate Final Diabetes Risk button pressed");
                                final messenger = ScaffoldMessenger.of(context);
                                if (!multiModal.isRetinaComplete &&
                                    scanData.retinaUrl != null) {
                                  multiModal.setRetinaScan(
                                      imageUrl: scanData.retinaUrl!);
                                }
                                if (!multiModal.isFootComplete &&
                                    scanData.footUrl != null) {
                                  multiModal.setFootScan(
                                      imageUrl: scanData.footUrl!);
                                }
                                final success = await multiModal
                                    .runCombinedMultiModalPrediction(
                                  auth.user?.uid ?? '',
                                );

                                if (multiModal.errorMessage != null) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(multiModal.errorMessage!),
                                      backgroundColor:
                                          AppConstants.statusDiabetic,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  multiModal.clearErrorMessage();
                                }

                                if (success &&
                                    mounted &&
                                    _scrollController.hasClients) {
                                  _scrollController.animateTo(
                                    _scrollController.position.maxScrollExtent +
                                        300,
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeOut,
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canRunCombined
                              ? AppConstants.primaryBlue
                              : Colors.grey.shade400,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: multiModal.isAnalyzing
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                      'Generating Multi-Modal AI Prediction...'),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    canRunCombined
                                        ? Icons.auto_awesome
                                        : Icons.lock_outline,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    canRunCombined
                                        ? 'Predict Diabetes (All 3 Inputs Ready)'
                                        : 'Predict Diabetes (Complete All 3 First)',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),

                      // Combined Result Card
                      if (multiModal.latestPrediction != null) ...[
                        const SizedBox(height: 24),
                        _buildCombinedResultCard(multiModal.latestPrediction!),
                      ],
                    ],
                  ),
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

  Widget _buildReqBadge(String label, bool isDone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDone ? AppConstants.statusHealthyBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone ? AppConstants.statusHealthy : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: isDone ? AppConstants.statusHealthy : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDone
                  ? AppConstants.statusHealthy
                  : AppConstants.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppConstants.primaryBlue, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppConstants.cardBorder),
          child,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: SwitchListTile(
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                fontSize: 12, color: AppConstants.textSecondary)),
        value: value,
        activeThumbColor: AppConstants.primaryBlue,
        contentPadding: EdgeInsets.zero,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildCombinedResultCard(PredictionResult result) {
    final riskColor = result.riskLevel == RiskLevel.healthy
        ? AppConstants.statusHealthy
        : (result.riskLevel == RiskLevel.prediabetic
            ? AppConstants.statusPrediabetic
            : AppConstants.statusDiabetic);

    final riskBgColor = result.riskLevel == RiskLevel.healthy
        ? AppConstants.statusHealthyBg
        : (result.riskLevel == RiskLevel.prediabetic
            ? AppConstants.statusPrediabeticBg
            : AppConstants.statusDiabeticBg);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: riskColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: riskColor.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        color: AppConstants.primaryBlue, size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Multi-Modal AI Diagnosis',
                        softWrap: true,
                        overflow: TextOverflow.visible,
                        maxLines: null,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppConstants.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: riskBgColor,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(
                  result.riskLevel.name.toUpperCase(),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: riskColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text(
                  '${result.riskPercentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: riskColor),
                ),
                Text(
                  result.predictionLabel,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  maxLines: null,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppConstants.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          const Text(
            'Integrated Diagnostic Findings:',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppConstants.textPrimary),
          ),
          const SizedBox(height: 8),
          _buildFindingTile('Tabular Assessment Score',
              '${result.assessmentScore.toStringAsFixed(1)}% Risk Score'),
          _buildFindingTile('Retinal Scan Result', result.retinaResult),
          _buildFindingTile('Diabetic Foot Scan Result', result.footResult),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.favorite_outline,
                  color: AppConstants.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.carePlanStatus,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  maxLines: null,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppConstants.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...result.recommendations.map(
            (rec) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: AppConstants.statusHealthy, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rec,
                      softWrap: true,
                      overflow: TextOverflow.visible,
                      maxLines: null,
                      style: const TextStyle(
                          fontSize: 13, color: AppConstants.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFindingTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              softWrap: true,
              overflow: TextOverflow.visible,
              maxLines: null,
              style: const TextStyle(
                fontSize: 12,
                color: AppConstants.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value,
              softWrap: true,
              overflow: TextOverflow.visible,
              maxLines: null,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppConstants.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
