import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/foot_scan_provider.dart';
import '../providers/scan_data_provider.dart';
import '../utils/constants.dart';
import '../widgets/custom_footer.dart';
import '../widgets/custom_header.dart';

class FootUlcerScreen extends StatefulWidget {
  const FootUlcerScreen({super.key});

  @override
  State<FootUlcerScreen> createState() => _FootUlcerScreenState();
}

class _FootUlcerScreenState extends State<FootUlcerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.user != null) {
        Provider.of<ScanDataProvider>(context, listen: false)
            .loadForUser(auth.user!.uid);
      }
    });
  }

  void _showImageSourceBottomSheet(
      BuildContext context, FootScanProvider provider, String uid) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Wrap(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Upload Diabetic Foot Image',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textPrimary,
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.camera_alt,
                      color: AppConstants.primaryBlue),
                  title: const Text('Take Photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    provider.pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library,
                      color: AppConstants.primaryBlue),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(ctx);
                    provider.pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.close, color: Colors.grey),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FootScanProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final scanData = Provider.of<ScanDataProvider>(context);
    final uid = auth.user?.uid ?? '';

    if (provider.validationError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.validationError!),
            backgroundColor: AppConstants.statusDiabetic,
            behavior: SnackBarBehavior.floating,
          ),
        );
        provider.clearValidationError();
      });
    }

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
                      'Foot Ulcer Detection',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Upload a diabetic foot image for AI-powered ulcer and lesion detection.',
                      style: TextStyle(
                          fontSize: 13, color: AppConstants.textSecondary),
                    ),

                    // Previously uploaded image from Firestore
                    if (scanData.isFootComplete &&
                        provider.selectedImage == null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppConstants.statusHealthyBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppConstants.statusHealthy
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: AppConstants.statusHealthy, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Previously Uploaded Foot Image',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppConstants.statusHealthy,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (scanData.footResult != null)
                                    Text(
                                      scanData.footResult!,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppConstants.textSecondary),
                                    ),
                                ],
                              ),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                scanData.footUrl!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image, size: 40),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    Container(
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
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () => _showImageSourceBottomSheet(
                                context, provider, uid),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 190,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppConstants.primaryBlueLight,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppConstants.primaryBlue
                                      .withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: provider.selectedImage != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.file(
                                        provider.selectedImage!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.medical_services_outlined,
                                          size: 48,
                                          color: AppConstants.primaryBlue,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Tap to Upload Diabetic Foot Image',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppConstants.primaryBlue,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Accepts Diabetic Foot & Ulcer Scans Only',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppConstants.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showImageSourceBottomSheet(
                                context, provider, uid),
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: Text(
                              provider.selectedImage != null
                                  ? 'Change Image'
                                  : 'Upload Image',
                            ),
                          ),
                          if (provider.selectedImage != null) ...[
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: provider.isAnalyzing
                                  ? null
                                  : () {
                                      debugPrint("--------------------------------------------------");
                                      debugPrint("STEP 1: [FootScreen] Analyze Foot Lesion button pressed");
                                      provider.runFootScan(uid: uid);
                                    },
                              child: provider.isAnalyzing
                                  ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2),
                                        ),
                                        SizedBox(width: 10),
                                        Text('Uploading & Analyzing...'),
                                      ],
                                    )
                                  : const Text('Analyze Foot Lesion'),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Upload error
                    if (provider.uploadError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppConstants.statusDiabeticBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppConstants.statusDiabetic
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppConstants.statusDiabetic, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                provider.uploadError!,
                                style: const TextStyle(
                                  color: AppConstants.statusDiabetic,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Upload success + AI Result
                    if (provider.uploadSuccess &&
                        provider.scanResult != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppConstants.statusHealthyBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppConstants.statusHealthy
                                  .withValues(alpha: 0.3)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: AppConstants.statusHealthy,
                                    size: 20),
                                SizedBox(width: 8),
                                Text(
                                  '✅ Foot image uploaded successfully.',
                                  style: TextStyle(
                                    color: AppConstants.statusHealthy,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Please complete the Diabetes Assessment and Retina Scan to generate your final diabetes prediction.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppConstants.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
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
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'AI Foot Analysis Result',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppConstants.textPrimary,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppConstants.primaryBlueLight,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${provider.scanResult!.confidencePercentage.toStringAsFixed(0)}% Confidence',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppConstants.primaryBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              provider.scanResult!.predictionLabel,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: provider.scanResult!.predictionLabel
                                        .toLowerCase()
                                        .contains('no lesion')
                                    ? AppConstants.statusHealthy
                                    : AppConstants.statusDiabetic,
                              ),
                            ),
                            if (provider.footResultMap != null &&
                                provider.footResultMap!['severity'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Severity: ${provider.footResultMap!['severity']}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppConstants.textSecondary,
                                ),
                              ),
                            ],
                            if (provider.footResultMap != null &&
                                provider.footResultMap!['reason'] != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                provider.footResultMap!['reason'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppConstants.textPrimary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
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
}
