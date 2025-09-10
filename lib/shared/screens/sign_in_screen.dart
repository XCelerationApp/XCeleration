import 'dart:math' as math;
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xceleration/core/services/auth_service.dart';
import 'package:xceleration/core/services/sync_service.dart';
import 'package:xceleration/core/services/profile_service.dart';
import 'package:xceleration/core/components/page_route_animations.dart';
import 'package:xceleration/coach/races_screen/screen/races_screen.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/core/components/animated_primary_button.dart';
import 'package:xceleration/core/components/glass_card.dart';
import 'package:gotrue/gotrue.dart' as gotrue;

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _obscure = true;
  bool _busy = false;
  late final AnimationController _floatController;
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _floatController =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_isLogin) {
        final resp = await AuthService.instance.signInWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
        if (mounted && resp.session != null) {
          // Run a sync after sign-in and navigate to coach screen
          try {
            await ProfileService.instance.ensureProfileUpsert();
            await SyncService.instance.syncAll();
          } catch (_) {}
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            RolePageRouteAnimation(child: const RacesScreen()),
            (route) => false,
          );
        }
      } else {
        final resp = await AuthService.instance.signUpWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
        // If confirmation is disabled, session should be returned. If not, fallback: sign in immediately.
        if (resp.session == null) {
          await AuthService.instance.signInWithEmailPassword(
            _emailController.text.trim(),
            _passwordController.text,
          );
        }
        if (mounted) {
          try {
            await ProfileService.instance.ensureProfileUpsert();
            await SyncService.instance.syncAll();
          } catch (_) {}
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            RolePageRouteAnimation(child: const RacesScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      final message = _formatAuthError(e);
      // Helpful UX: if account already exists while in Sign Up, switch to Sign In
      if (e is gotrue.AuthApiException && e.code == 'user_already_exists') {
        if (mounted) setState(() => _isLogin = true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatAuthError(Object error) {
    // Network/connectivity
    if (error is SocketException) {
      return 'No internet connection. Please check your connection and try again.';
    }
    if (error is TimeoutException) {
      return 'The request timed out. Please try again.';
    }

    // Supabase Auth specific
    if (error is gotrue.AuthWeakPasswordException) {
      final reasons = error.reasons.join(', ');
      return 'Password too weak: $reasons';
    }
    if (error is gotrue.AuthApiException) {
      switch (error.code) {
        case 'user_already_exists':
          return 'An account with this email already exists. Please sign in instead.';
        case 'invalid_credentials':
          return 'Incorrect email or password. Please try again.';
        case 'email_not_confirmed':
          return 'Please confirm your email first. Check your inbox for a verification link.';
        case 'over_email_send_rate_limit':
          return 'Too many attempts. Please wait a minute and try again.';
        case 'signup_disabled':
          return 'Sign ups are currently disabled. Please contact support.';
        default:
          // Fallback to server message if helpful
          return error.message.isNotEmpty
              ? error.message
              : 'Authentication failed. Please try again.';
      }
    }
    if (error is gotrue.AuthException) {
      return error.message;
    }

    // Unknown
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = AppColors.primaryColor;

    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.backgroundColor),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // Floating decorative elements
            // Positioned.fill(
            //   child: IgnorePointer(
            //     ignoring: true,
            //     child: AnimatedBuilder(
            //       animation: _floatController,
            //       builder: (context, _) {
            //         final t = _floatController.value * 2 * math.pi;
            //         return Stack(
            //           children: [
            //             _floatingCircle(
            //               alignment: Alignment(-0.8, -0.6),
            //               size: 70,
            //               verticalShift: math.sin(t) * 12,
            //             ),
            //             _floatingCircle(
            //               alignment: const Alignment(0.8, 0.3),
            //               size: 90,
            //               verticalShift: math.sin(t + 1.8) * 16,
            //             ),
            //             _floatingCircle(
            //               alignment: const Alignment(-0.3, 0.8),
            //               size: 50,
            //               verticalShift: math.sin(t + 3.2) * 10,
            //             ),
            //           ],
            //         );
            //       },
            //     ),
            //   ),
            // ),

            // Content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _busy ? 0.9 : 1,
                    child: GlassCard(
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                      child: AbsorbPointer(
                        absorbing: _busy,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _isLogin ? 'Sign in' : 'Create account',
                                style: AppTypography.titleLarge.copyWith(
                                  color: const Color(0xFF2C2C2C),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Email
                              _buildLabeledField(
                                label: 'Email',
                                focusNode: _emailFocusNode,
                                child: TextFormField(
                                  focusNode: _emailFocusNode,
                                  controller: _emailController,
                                  decoration: _inputDecoration(
                                    label: 'Email',
                                    hint: 'Enter your email',
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  smartDashesType: SmartDashesType.disabled,
                                  smartQuotesType: SmartQuotesType.disabled,
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Email is required'
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Password
                              _buildLabeledField(
                                label: 'Password',
                                hintBelow: 'Use at least 6 characters',
                                focusNode: _passwordFocusNode,
                                child: TextFormField(
                                  focusNode: _passwordFocusNode,
                                  controller: _passwordController,
                                  decoration: _inputDecoration(
                                    label: 'Password',
                                    hint: 'Enter your password',
                                    suffix: IconButton(
                                      tooltip: _obscure
                                          ? 'Show password'
                                          : 'Hide password',
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                  obscureText: _obscure,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  smartDashesType: SmartDashesType.disabled,
                                  smartQuotesType: SmartQuotesType.disabled,
                                  validator: (v) => (v == null || v.length < 6)
                                      ? 'Use at least 6 characters'
                                      : null,
                                  onFieldSubmitted: (_) =>
                                      _busy ? null : _submit(),
                                ),
                              ),

                              if (_isLogin) ...[
                                const SizedBox(height: 6),
                                Center(
                                  child: TextButton(
                                    onPressed: () async {
                                      if (_emailController.text.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Enter email to reset password'),
                                          ),
                                        );
                                        return;
                                      }
                                      await AuthService.instance
                                          .sendPasswordResetEmail(
                                              _emailController.text.trim());
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Password reset email sent'),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('Forgot password?'),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 12),

                              // Submit button with loading state
                              AnimatedPrimaryButton(
                                text: _isLogin ? 'Sign in' : 'Create account',
                                onPressed: _busy ? null : _submit,
                                isLoading: _busy,
                                color: primary,
                                textStyle: AppTypography.buttonText
                                    .copyWith(color: Colors.white),
                              ),

                              const SizedBox(height: 8),

                              Center(
                                child: TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () =>
                                          setState(() => _isLogin = !_isLogin),
                                  child: Text(
                                    _isLogin
                                        ? "Don't have an account? Sign up"
                                        : 'Have an account? Sign in',
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(color: Colors.grey[700]),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Floating background circle
  Widget _floatingCircle({
    required Alignment alignment,
    required double size,
    required double verticalShift,
  }) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(0, verticalShift),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  // Labeled field wrapper with subtle scale on focus and optional hint below
  Widget _buildLabeledField({
    required String label,
    required Widget child,
    FocusNode? focusNode,
    String? hintBelow,
  }) {
    final hasFocus = focusNode?.hasFocus ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedScale(
          scale: hasFocus ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: child,
        ),
        if (hintBelow != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              hintBelow,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    Widget? suffix,
  }) {
    final borderRadius = BorderRadius.circular(16);
    const borderWidth = 2.0;
    return InputDecoration(
      hintText: hint,
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8F8F8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide:
            const BorderSide(color: Color(0xFFE5E5E5), width: borderWidth),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide:
            const BorderSide(color: Color(0xFFE5E5E5), width: borderWidth),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide:
            const BorderSide(color: AppColors.primaryColor, width: borderWidth),
      ),
      helperText: null,
      suffixIcon: suffix,
    );
  }
}
