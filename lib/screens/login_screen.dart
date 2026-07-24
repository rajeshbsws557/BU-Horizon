// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../di/di.dart';
import '../navigation/app_router.dart';
import '../supabase/auth_service.dart';
import '../supabase/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/horizon_logo.dart';

/// Sign-in accepts a university email OR a Student ID (poll Q22) plus a
/// password. A Student ID is resolved to its account email server-side before
/// authenticating. Password recovery is available via email (poll Q23).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = getIt<AuthService>();

  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await _auth.signIn(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      await getIt<SessionController>().refresh();
      if (!mounted) return;
      showToast(context, 'Welcome back!');
      context.go(AppRoutes.home);
    } on AuthFailure catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (e) {
      if (mounted) showToast(context, 'Sign in failed. $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _identifierController.text.trim();
    if (!email.contains('@')) {
      showToast(
        context,
        'Enter your university email above to reset your password',
      );
      return;
    }
    try {
      await _auth.sendPasswordReset(email);
      if (mounted) showToast(context, 'Password reset link sent to your email');
    } on AuthFailure catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  InputDecoration _dec(BuildContext context, String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.colors.textMuted),
      filled: true,
      fillColor: context.colors.surfaceAlt,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.danger, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(color: context.colors.textPrimary);
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Center(child: HorizonLogo(size: 80)),
                    const SizedBox(height: 28),
                    Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to sync your campus schedule and attendance.',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Email or Student ID',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _identifierController,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      style: textStyle,
                      decoration: _dec(context, 'name@bu.ac.bd or Student ID'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter your email or Student ID'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      style: textStyle,
                      onFieldSubmitted: (_) => _login(),
                      decoration: _dec(
                        context,
                        'Enter your password',
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: context.colors.textSecondary,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Enter your password'
                          : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: _submitting ? 'Signing in...' : 'Sign In',
                      icon: Icons.login_rounded,
                      onPressed: _submitting ? null : _login,
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: TextButton(
                        onPressed: () => context.push(AppRoutes.register),
                        child: RichText(
                          text: TextSpan(
                            text: "Don't have an account? ",
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: 'Register',
                                style: TextStyle(
                                  color: context.colors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'Developer: Rajesh Biswas (rajeshbiswas.dev)',
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
