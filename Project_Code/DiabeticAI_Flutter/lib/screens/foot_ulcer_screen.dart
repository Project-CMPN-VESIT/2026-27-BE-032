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
                    'Upload Foot Image',
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
                      'Foot Skin Screening',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Upload a clear foot image for visual skin screening.',
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
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final metrics = provider
                                              .footResultMap?['image_metrics'];
                                          final imageWidth = metrics is Map &&
                                                  metrics['width'] is num
                                              ? (metrics['width'] as num)
                                                  .toDouble()
                                              : 0.0;
                                          final imageHeight = metrics is Map &&
                                                  metrics['height'] is num
                                              ? (metrics['height'] as num)
                                                  .toDouble()
                                              : 0.0;
                                          final regions = (provider
                                                      .footResultMap?['regions']
                                                  as List<dynamic>?) ??
                                              const <dynamic>[];
                                          final imageRatio = imageHeight > 0
                                              ? imageWidth / imageHeight
                                              : 0.0;
                                          final boxRatio =
                                              constraints.maxWidth /
                                                  constraints.maxHeight;
                                          final renderedWidth =
                                              imageRatio > 0 &&
                                                      imageRatio < boxRatio
                                                  ? constraints.maxHeight *
                                                      imageRatio
                                                  : constraints.maxWidth;
                                          final renderedHeight =
                                              imageRatio > 0 &&
                                                      imageRatio < boxRatio
                                                  ? constraints.maxHeight
                                                  : constraints.maxWidth /
                                                      (imageRatio > 0
                                                          ? imageRatio
                                                          : boxRatio);
                                          final offsetX =
                                              (constraints.maxWidth -
                                                      renderedWidth) /
                                                  2;
                                          final offsetY =
                                              (constraints.maxHeight -
                                                      renderedHeight) /
                                                  2;

                                          return Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Image.file(
                                                provider.selectedImage!,
                                                fit: BoxFit.contain,
                                              ),
                                              if (imageRatio > 0)
                                                for (final region in regions)
                                                  if (region is Map &&
                                                      region['x'] is num &&
                                                      region['y'] is num &&
                                                      region['width'] is num &&
                                                      region['height'] is num)
                                                    Positioned(
                                                      left: offsetX +
                                                          (region['x'] as num)
                                                                  .toDouble() *
                                                              renderedWidth,
                                                      top: offsetY +
                                                          (region['y'] as num)
                                                                  .toDouble() *
                                                              renderedHeight,
                                                      width: (region['width']
                                                                  as num)
                                                              .toDouble() *
                                                          renderedWidth,
                                                      height: (region['height']
                                                                  as num)
                                                              .toDouble() *
                                                          renderedHeight,
                                                      child: DecoratedBox(
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.red
                                                              .withValues(
                                                                  alpha: 0.12),
                                                          border: Border.all(
                                                            color: Colors.red,
                                                            width: 2,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                            ],
                                          );
                                        },
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
                                          'Tap to Upload Foot Image',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppConstants.primaryBlue,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Use a clear, well-lit image of the foot',
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
                                      debugPrint(
                                          "--------------------------------------------------");
                                      debugPrint(
                                          "STEP 1: [FootScreen] Analyze Foot Lesion button pressed");
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
                                  : const Text('Analyze Foot Image'),
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
                                  'Foot Image Screening Result',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppConstants.textPrimary,
                                  ),
                                ),
                                Text(
                                  provider.footResultMap?['screening_mode'] ==
                                          'actual-upload'
                                      ? 'OPENCV PRELIMINARY SCREENING'
                                      : 'IMAGE QUALITY CHECK',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppConstants.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Preliminary screening only; not clinically validated or a diagnosis.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppConstants.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              provider.scanResult!.predictionLabel,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: switch (
                                    provider.scanResult!.predictionLabel) {
                                  'NORMAL' => AppConstants.statusHealthy,
                                  'SEVERE FINDING' ||
                                  'ULCER SUSPECTED' =>
                                    AppConstants.statusDiabetic,
                                  'INCONCLUSIVE' => AppConstants.textSecondary,
                                  _ => AppConstants.statusPrediabetic,
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              provider.scanResult!.footResult,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppConstants.textPrimary,
                              ),
                            ),
                            if (provider.footResultMap?['image_metrics']
                                is Map) ...[
                              const SizedBox(height: 8),
                              Builder(
                                builder: (context) {
                                  final metrics = provider
                                      .footResultMap!['image_metrics'] as Map;
                                  final sharpness = metrics['sharpness'];
                                  final brightness = metrics['brightness_mean'];
                                  final regionCount =
                                      metrics['localized_region_count'];
                                  return Text(
                                    'OpenCV metrics: ${sharpness is num ? 'sharpness ${sharpness.toStringAsFixed(1)}' : ''}'
                                    '${sharpness is num && brightness is num ? ', ' : ''}'
                                    '${brightness is num ? 'brightness ${brightness.toStringAsFixed(1)}' : ''}'
                                    '${(sharpness is num || brightness is num) && regionCount is num ? ', ' : ''}'
                                    '${regionCount is num ? 'localized regions ${regionCount.toInt()}' : ''}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppConstants.textSecondary,
                                    ),
                                  );
                                },
                              ),
                            ],
                            if (provider.footResultMap?['confidence'] is num &&
                                (provider.footResultMap!['confidence'] as num)
                                    .isFinite &&
                                (provider.footResultMap!['confidence']
                                        as num) >=
                                    0 &&
                                (provider.footResultMap!['confidence']
                                        as num) <=
                                    100) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Model-reported confidence: ${(provider.footResultMap!['confidence'] as num).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppConstants.textSecondary,
                                ),
                              ),
                            ],
                            if ((provider.footResultMap?['regions']
                                        as List<dynamic>?)
                                    ?.isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 8),
                              for (final (index, region)
                                  in (provider.footResultMap!['regions']
                                          as List<dynamic>)
                                      .indexed)
                                Text(
                                  'Region ${index + 1}: ${region['label'] ?? 'Review required'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppConstants.textPrimary,
                                  ),
                                ),
                            ],
                            if (provider.footResultMap?['status'] ==
                                'INCONCLUSIVE') ...[
                              const SizedBox(height: 8),
                              Text(
                                provider.footResultMap!['reason'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppConstants.textPrimary,
                                ),
                              ),
                            ],
                            if (provider.footResultMap?['demo_mode']
                                is String) ...[
                              const SizedBox(height: 8),
                              Text(
                                provider.footResultMap!['demo_mode'] as String,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppConstants.textSecondary,
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
