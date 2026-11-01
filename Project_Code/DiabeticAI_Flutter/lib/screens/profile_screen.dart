import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/scan_data_provider.dart';
import '../providers/multi_modal_provider.dart';
import '../providers/eye_scan_provider.dart';
import '../providers/foot_scan_provider.dart';
import '../providers/assessment_provider.dart';
import '../routes/app_routes.dart';
import '../services/firebase_storage_service.dart';
import '../utils/constants.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/custom_footer.dart';
import '../widgets/custom_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseStorageService _storageService = FirebaseStorageService();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NavProvider>(context, listen: false).setIndex(3);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.statusDiabetic,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.statusHealthy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  ImageProvider? _getAvatarImage(String? photoUrl, File? localFile) {
    if (localFile != null) {
      return FileImage(localFile);
    }
    if (photoUrl == null || photoUrl.isEmpty) {
      return null;
    }
    if (photoUrl.startsWith('data:image')) {
      try {
        final base64Str = photoUrl.split(',').last;
        return MemoryImage(base64Decode(base64Str));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(photoUrl);
  }

  Future<void> _handleEditProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;

    final existingName = currentUser?.fullName.trim() ?? '';
    final nameParts = existingName.split(' ');
    final firstNameController = TextEditingController(
        text: nameParts.isNotEmpty ? nameParts.first : '');
    final lastNameController = TextEditingController(
      text: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
    );
    File? selectedImageFile;
    String? newPhotoUrl = currentUser?.photoUrl;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final avatarImage = _getAvatarImage(newPhotoUrl, selectedImageFile);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 45,
                          backgroundColor: AppConstants.primaryBlueLight,
                          backgroundImage: avatarImage,
                          child: avatarImage == null
                              ? const Icon(Icons.person,
                                  size: 50, color: AppConstants.primaryBlue)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: () async {
                              final picker = ImagePicker();
                              final source =
                                  await showModalBottomSheet<ImageSource>(
                                context: modalCtx,
                                builder: (_) => SafeArea(
                                  child: Wrap(
                                    children: [
                                      ListTile(
                                        leading:
                                            const Icon(Icons.photo_library),
                                        title:
                                            const Text('Choose from Gallery'),
                                        onTap: () => Navigator.pop(
                                            modalCtx, ImageSource.gallery),
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.camera_alt),
                                        title: const Text('Take Photo'),
                                        onTap: () => Navigator.pop(
                                            modalCtx, ImageSource.camera),
                                      ),
                                    ],
                                  ),
                                ),
                              );

                              if (source != null) {
                                final picked = await picker.pickImage(
                                  source: source,
                                  imageQuality: 80,
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    selectedImageFile = File(picked.path);
                                  });
                                }
                              }
                            },
                            child: const CircleAvatar(
                              radius: 16,
                              backgroundColor: AppConstants.primaryBlue,
                              child: Icon(Icons.camera_alt,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isUploading
                        ? null
                        : () async {
                            setModalState(() {
                              _isUploading = true;
                            });

                            try {
                              String? uploadedUrl = newPhotoUrl;

                              if (selectedImageFile != null) {
                                uploadedUrl = await _storageService.uploadImage(
                                  selectedImageFile!,
                                  folder: 'profile',
                                  uid: currentUser?.uid ?? '',
                                );
                              }

                              final firstName = firstNameController.text.trim();
                              final lastName = lastNameController.text.trim();
                              final fullName = [firstName, lastName]
                                  .where((s) => s.isNotEmpty)
                                  .join(' ');

                              final error = await authProvider.updateProfile(
                                fullName: fullName,
                                photoUrl: uploadedUrl,
                              );

                              if (!mounted || !modalCtx.mounted) return;

                              if (error != null) {
                                _showError(error);
                              } else {
                                Navigator.pop(modalCtx);
                                _showSuccess('Profile updated successfully!');
                              }
                            } finally {
                              setModalState(() {
                                _isUploading = false;
                              });
                            }
                          },
                    child: _isUploading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final navProvider = Provider.of<NavProvider>(context);
    final user = authProvider.user;

    final photoUrl = user?.photoUrl;
    final rawName = user?.fullName.trim() ?? '';
    final displayName = (rawName.isEmpty || rawName == 'User')
        ? (user?.email.isNotEmpty == true ? 'User' : 'User')
        : rawName;

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
                  children: [
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
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppConstants.primaryBlueLight,
                            backgroundImage: _getAvatarImage(photoUrl, null),
                            child: _getAvatarImage(photoUrl, null) == null
                                ? const Icon(
                                    Icons.person,
                                    size: 48,
                                    color: AppConstants.primaryBlue,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.textPrimary,
                            ),
                          ),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppConstants.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.person_outline,
                                color: AppConstants.primaryBlue),
                            title: const Text('Edit Profile'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _handleEditProfile,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.lock_outline,
                                color: AppConstants.primaryBlue),
                            title: const Text('Privacy & Security'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _showInfoSheet(
                              context,
                              title: 'Privacy & Security',
                              icon: Icons.lock_outline,
                              items: [
                                const _InfoItem(
                                    icon: Icons.shield_outlined,
                                    label: 'Data Encryption',
                                    value:
                                        'All data is encrypted in transit and at rest using AES-256.'),
                                const _InfoItem(
                                    icon: Icons.storage_outlined,
                                    label: 'Data Storage',
                                    value:
                                        'Your health data is securely stored in Google Firestore with access control.'),
                                const _InfoItem(
                                    icon: Icons.visibility_off_outlined,
                                    label: 'Privacy Policy',
                                    value:
                                        'We do not share your personal health data with third parties.'),
                                const _InfoItem(
                                    icon: Icons.delete_outline,
                                    label: 'Delete Account',
                                    value:
                                        'To request account deletion, contact support@diabeticai.com.'),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.help_outline,
                                color: AppConstants.primaryBlue),
                            title: const Text('Help & Support'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _showInfoSheet(
                              context,
                              title: 'Help & Support',
                              icon: Icons.help_outline,
                              items: [
                                const _InfoItem(
                                    icon: Icons.email_outlined,
                                    label: 'Email Support',
                                    value: 'support@diabeticai.com'),
                                const _InfoItem(
                                    icon: Icons.info_outline,
                                    label: 'App Version',
                                    value: 'DiabeticAI v1.0.0 (Flutter)'),
                                const _InfoItem(
                                    icon: Icons.camera_alt_outlined,
                                    label: 'Image Upload',
                                    value:
                                        'Use Gallery or Camera to upload scans. Supported formats: JPG, PNG.'),
                                const _InfoItem(
                                    icon: Icons.medical_services_outlined,
                                    label: 'Disclaimer',
                                    value:
                                        'This app provides AI-assisted screening only and is not a substitute for medical advice.'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: () async {
                        Provider.of<ScanDataProvider>(context, listen: false)
                            .clearAll();
                        Provider.of<MultiModalProvider>(context, listen: false)
                            .resetWorkflow();
                        Provider.of<EyeScanProvider>(context, listen: false)
                            .reset();
                        Provider.of<FootScanProvider>(context, listen: false)
                            .reset();
                        Provider.of<AssessmentProvider>(context, listen: false)
                            .reset();
                        await authProvider.logout();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.login,
                            (route) => false,
                          );
                        }
                      },
                      child: const Text('Logout'),
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
                if (index == 0) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, AppRoutes.dashboard, (route) => false);
                }
                if (index == 1) {
                  Navigator.pushNamed(context, AppRoutes.diabetesAssessment);
                }
                if (index == 2) Navigator.pushNamed(context, AppRoutes.history);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem(
      {required this.icon, required this.label, required this.value});
}

void _showInfoSheet(
  BuildContext context, {
  required String title,
  required IconData icon,
  required List<_InfoItem> items,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppConstants.primaryBlue, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryBlueLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon,
                        color: AppConstants.primaryBlue, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppConstants.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.value,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppConstants.textSecondary,
                          ),
                        ),
                      ],
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
