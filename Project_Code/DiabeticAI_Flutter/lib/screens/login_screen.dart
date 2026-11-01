import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../utils/constants.dart';
import '../widgets/custom_footer.dart';
import '../widgets/custom_header.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;

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

  Future<void> _handleForgotPassword() async {
    final emailController = TextEditingController(text: _emailController.text.trim());

    final dialogEmail = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your email address and we will send you a password reset link.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, emailController.text.trim()),
            child: const Text('Send Link'),
          ),
        ],
      ),
    );

    if (dialogEmail == null || dialogEmail.isEmpty) return;
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final error = await authProvider.sendPasswordResetEmail(dialogEmail);

    if (!mounted) return;

    if (error != null) {
      _showError(error);
    } else {
      _showSuccess('Password reset email sent to $dialogEmail. Please check your inbox.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
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
                          'Sign in to access your AI health records',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppConstants.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
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
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                ),
                                const Text('Remember Me', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                            TextButton(
                              onPressed: _handleForgotPassword,
                              child: const Text('Forgot Password?'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: authProvider.isLoading
                              ? null
                              : () async {
                                  final navigator = Navigator.of(context);
                                  final email = _emailController.text.trim();
                                  final password = _passwordController.text;

                                  if (email.isEmpty || password.isEmpty) {
                                    _showError('Please enter your email and password.');
                                    return;
                                  }

                                  final error = await authProvider.login(email, password);

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
                              : const Text('Login'),
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
                            onPressed: () {
                              Navigator.pushNamed(context, AppRoutes.register);
                            },
                            child: const Text("Don't have an account? Register"),
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
    ),
  );
}
}
