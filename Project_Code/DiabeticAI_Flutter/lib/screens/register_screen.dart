import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../utils/constants.dart';
import '../widgets/custom_footer.dart';
import '../widgets/custom_header.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.statusDiabetic,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: const CustomHeader(),
      backgroundColor: AppConstants.bgLightSlate,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Start your AI-powered early health screening',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppConstants.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _confirmController,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: const Icon(Icons.lock_reset_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirm = !_obscureConfirm;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: authProvider.isLoading
                              ? null
                              : () async {
                                  final navigator = Navigator.of(context);
                                  final name = _nameController.text.trim();
                                  final email = _emailController.text.trim();
                                  final password = _passwordController.text;
                                  final confirm = _confirmController.text;

                                  if (name.isEmpty || email.isEmpty || password.isEmpty) {
                                    _showError('Please fill in all required fields.');
                                    return;
                                  }
                                  if (password != confirm) {
                                    _showError('Passwords do not match.');
                                    return;
                                  }
                                  if (password.length < 6) {
                                    _showError('Password must be at least 6 characters.');
                                    return;
                                  }

                                  final error = await authProvider.register(
                                    name,
                                    email,
                                    password,
                                  );

                                  if (!mounted) return;

                                  if (error != null) {
                                    _showError(error);
                                  } else {
                                    navigator.pushReplacementNamed(AppRoutes.dashboard);
                                  }
                                },
                          child: authProvider.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Create Account'),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: authProvider.isLoading
                              ? null
                              : () async {
                                  final navigator = Navigator.of(context);
                                  final error = await authProvider.signInWithGoogle();
                                  if (!mounted) return;
                                  if (error != null && error != 'Google Sign-In cancelled.') {
                                    _showError(error);
                                  } else if (error == null) {
                                    navigator.pushReplacementNamed(AppRoutes.dashboard);
                                  }
                                },
                          icon: const Icon(Icons.g_mobiledata, size: 28, color: AppConstants.primaryBlue),
                          label: const Text('Sign in with Google'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Already have an account? Login'),
                          ),
                        ),
                      ],
                    ),
                  ),
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
