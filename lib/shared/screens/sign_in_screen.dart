import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:xceleration/core/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:xceleration/core/services/i_sync_service.dart';
import 'package:xceleration/core/services/profile_service.dart';
import 'package:xceleration/core/components/page_route_animations.dart';
import 'package:xceleration/coach/races_screen/screen/races_screen.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/core/services/connectivity_service.dart';
import 'package:gotrue/gotrue.dart' as gotrue;


// ─── Screen ───────────────────────────────────────────────────────────────────

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required IAuthService authService,
    ConnectivityService? connectivityService,
    required ProfileService profileService,
  })  : _authService = authService,
        _connectivityService = connectivityService,
        _profileService = profileService;

  final IAuthService _authService;
  final ConnectivityService? _connectivityService;
  final ProfileService _profileService;

  @override
  State<SignInScreen> createState() => _SignInScreenState();

}

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  ConnectivityService get _connectivity =>
      widget._connectivityService ?? const ConnectivityService();

  bool _isLogin = true;
  bool _obscure = true;
  bool _busy = false;
  String? _emailError;
  String? _passwordError;

  late final AnimationController _shakeController;
  late final Animation<Offset> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
          tween: Tween(begin: Offset.zero, end: const Offset(-0.025, 0)),
          weight: 1),
      TweenSequenceItem(
          tween: Tween(
              begin: const Offset(-0.025, 0), end: const Offset(0.025, 0)),
          weight: 2),
      TweenSequenceItem(
          tween: Tween(
              begin: const Offset(0.025, 0), end: const Offset(-0.015, 0)),
          weight: 2),
      TweenSequenceItem(
          tween: Tween(
              begin: const Offset(-0.015, 0), end: const Offset(0.015, 0)),
          weight: 2),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(0.015, 0), end: Offset.zero),
          weight: 1),
    ]).animate(_shakeController);

    _emailController.addListener(_onTextChanged);
    _passwordController.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _shakeController.dispose();
    _emailController
      ..removeListener(_onTextChanged)
      ..dispose();
    _passwordController
      ..removeListener(_onTextChanged)
      ..dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool _validate() {
    String? emailErr;
    String? passErr;
    if (_emailController.text.trim().isEmpty) {
      emailErr = 'Email is required';
    } else if (!RegExp(r'\S+@\S+\.\S+').hasMatch(_emailController.text)) {
      emailErr = 'Enter a valid email';
    }
    if (_passwordController.text.length < 6) {
      passErr = 'Use at least 6 characters';
    }
    setState(() {
      _emailError = emailErr;
      _passwordError = passErr;
    });
    if (emailErr != null || passErr != null) {
      _shakeController.forward(from: 0);
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    final syncService = context.read<ISyncService>();
    if (!await _connectivity.isOnline()) {
      if (!mounted) return;
      DialogUtils.showMessageDialog(context,
          title: 'No internet connection',
          message: 'Please check your connection and try again.');
      return;
    }
    setState(() => _busy = true);
    try {
      if (_isLogin) {
        final resp = await widget._authService.signInWithEmailPassword(
            _emailController.text.trim(), _passwordController.text);
        if (mounted && resp.session != null) {
          try {
            await widget._profileService.ensureProfileUpsert();
            await syncService.syncAll();
          } catch (_) {}
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
              RolePageRouteAnimation(child: const RacesScreen()),
              (route) => false);
        }
      } else {
        final resp = await widget._authService.signUpWithEmailPassword(
            _emailController.text.trim(), _passwordController.text);
        if (resp.session == null) {
          await widget._authService.signInWithEmailPassword(
              _emailController.text.trim(), _passwordController.text);
        }
        if (mounted) {
          try {
            await widget._profileService.ensureProfileUpsert();
            await syncService.syncAll();
          } catch (_) {}
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
              RolePageRouteAnimation(child: const RacesScreen()),
              (route) => false);
        }
      }
    } catch (e) {
      if (e is gotrue.AuthApiException && e.code == 'user_already_exists') {
        if (mounted) setState(() => _isLogin = true);
      }
      if (!mounted) return;
      DialogUtils.showMessageDialog(context,
          title: 'Error', message: _formatAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatAuthError(Object error) {
    if (error is SocketException) {
      return 'No internet connection. Please check your connection and try again.';
    }
    if (error is TimeoutException) {
      return 'The request timed out. Please try again.';
    }
    if (error is gotrue.AuthWeakPasswordException) {
      return 'Password too weak: ${error.reasons.join(', ')}';
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
          return error.message.isNotEmpty
              ? error.message
              : 'Authentication failed. Please try again.';
      }
    }
    if (error is gotrue.AuthException) {
      final msg = error.message;
      if (msg.contains('Failed host lookup') ||
          msg.contains('nodename nor servname')) {
        return 'Could not reach the server. Please try again later.';
      }
      if (msg.contains('SocketException') || msg.contains('ClientException')) {
        return 'No internet connection. Please check your connection and try again.';
      }
      return msg;
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      DialogUtils.showMessageDialog(context,
          title: 'Email required',
          message:
              'Enter your email address above, then tap Forgot Password.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget._authService
          .sendPasswordResetEmail(_emailController.text.trim());
      if (mounted) {
        DialogUtils.showMessageDialog(context,
            title: 'Reset email sent',
            message:
                "We've sent a password reset link to ${_emailController.text.trim()}.");
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showMessageDialog(context,
            title: 'Error', message: _formatAuthError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _switchMode() => setState(() {
        _isLogin = !_isLogin;
        _emailError = null;
        _passwordError = null;
      });

  @override
  Widget build(BuildContext context) {
    final canSubmit = _emailController.text.trim().isNotEmpty &&
        _passwordController.text.length >= 6 &&
        !_busy;
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SignInHeader(
                isLogin: _isLogin,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: SlideTransition(
                    position: _shakeAnimation,
                    child: _FormBody(
                      isLogin: _isLogin,
                      emailController: _emailController,
                      passwordController: _passwordController,
                      emailFocus: _emailFocus,
                      passwordFocus: _passwordFocus,
                      emailError: _emailError,
                      passwordError: _passwordError,
                      obscure: _obscure,
                      busy: _busy,
                      canSubmit: canSubmit,
                      onEmailChanged: (_) =>
                          setState(() => _emailError = null),
                      onPasswordChanged: (_) =>
                          setState(() => _passwordError = null),
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      onSubmit: _submit,
                      onForgotPassword:
                          _busy ? null : _handleForgotPassword,
                      onSwitchMode: _busy ? null : _switchMode,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _SignInHeader extends StatelessWidget {
  const _SignInHeader({required this.isLogin, required this.onBack});

  final bool isLogin;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onBack,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left,
                    color: AppColors.primaryColor, size: 22),
                Text('Back',
                    style: AppTypography.smallBodySemibold
                        .copyWith(color: AppColors.primaryColor)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AnimatedSwitcher(
            duration: AppAnimations.standard,
            child: Align(
              key: ValueKey('title_$isLogin'),
              alignment: Alignment.centerLeft,
              child: Text(
                isLogin ? 'Sign in to\nXCeleration' : 'Create your\naccount',
                style: AppTypography.displaySmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkColor,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Form body ────────────────────────────────────────────────────────────────

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.isLogin,
    required this.emailController,
    required this.passwordController,
    required this.emailFocus,
    required this.passwordFocus,
    required this.emailError,
    required this.passwordError,
    required this.obscure,
    required this.busy,
    required this.canSubmit,
    required this.onEmailChanged,
    required this.onPasswordChanged,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onForgotPassword,
    required this.onSwitchMode,
  });

  final bool isLogin;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final String? emailError;
  final String? passwordError;
  final bool obscure;
  final bool busy;
  final bool canSubmit;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onToggleObscure;
  final VoidCallback? onSubmit;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onSwitchMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
            top: BorderSide(color: AppColors.lightColor, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthTextField(
            controller: emailController,
            focusNode: emailFocus,
            label: 'Email',
            error: emailError,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onChanged: onEmailChanged,
            onSubmitted: (_) => passwordFocus.requestFocus(),
            disabled: busy,
          ),
          const SizedBox(height: AppSpacing.lg),
          _AuthTextField(
            controller: passwordController,
            focusNode: passwordFocus,
            label: 'Password',
            error: passwordError,
            obscureText: obscure,
            textInputAction: TextInputAction.done,
            onChanged: onPasswordChanged,
            onSubmitted: (_) => onSubmit?.call(),
            disabled: busy,
            suffix: TextButton(
              onPressed: onToggleObscure,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md),
                foregroundColor: AppColors.mediumColor,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                obscure ? 'Show' : 'Hide',
                style: AppTypography.smallBodySemibold
                    .copyWith(color: AppColors.mediumColor),
              ),
            ),
          ),
          if (isLogin) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onForgotPassword,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: AppColors.primaryColor,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Forgot password?',
                  style: AppTypography.smallBodySemibold
                      .copyWith(color: AppColors.primaryColor),
                ),
              ),
            ),
          ],
          SizedBox(height: isLogin ? AppSpacing.xl : AppSpacing.xxl),
          _SubmitButton(
            isLogin: isLogin,
            canSubmit: canSubmit,
            busy: busy,
            onPressed: onSubmit,
          ),
          const SizedBox(height: AppSpacing.xl),
          _ModeToggle(isLogin: isLogin, onSwitch: onSwitchMode),
        ],
      ),
    );
  }
}

// ─── Labeled text field ───────────────────────────────────────────────────────

class _AuthTextField extends StatefulWidget {
  const _AuthTextField({
    required this.controller,
    required this.focusNode,
    required this.label,
    this.error,
    this.onChanged,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
    this.disabled = false,
    this.suffix,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String? error;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool disabled;
  final Widget? suffix;

  @override
  State<_AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<_AuthTextField> {
  bool _focused = false;

  void _onFocusChange() =>
      setState(() => _focused = widget.focusNode.hasFocus);

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.error != null;
    final active = _focused || hasError;
    final borderColor =
        active ? AppColors.primaryColor : AppColors.borderColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: AppTypography.smallCaption.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: hasError ? AppColors.primaryColor : AppColors.mediumColor,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AnimatedContainer(
          duration: AppAnimations.fast,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(AppBorderRadius.md),
            border: Border.all(color: borderColor, width: 1.5),
            color: widget.disabled
                ? AppColors.lightColor.withValues(alpha: AppOpacity.light)
                : Colors.white,
            boxShadow: _focused && !hasError
                ? [
                    BoxShadow(
                      color: AppColors.primaryColor
                          .withValues(alpha: AppOpacity.faint * 2),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  onSubmitted: widget.onSubmitted,
                  onChanged: widget.onChanged,
                  enabled: !widget.disabled,
                  autocorrect: false,
                  enableSuggestions: false,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  style: AppTypography.bodyRegular
                      .copyWith(color: AppColors.darkColor),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
              ),
              if (widget.suffix != null) widget.suffix!,
            ],
          ),
        ),
        AnimatedSize(
          duration: AppAnimations.fast,
          curve: AppAnimations.enter,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    widget.error!,
                    style: AppTypography.smallCaption.copyWith(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─── Submit button ────────────────────────────────────────────────────────────

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.isLogin,
    required this.canSubmit,
    required this.busy,
    required this.onPressed,
  });

  final bool isLogin;
  final bool canSubmit;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Stack(
        children: [
          AnimatedOpacity(
            opacity: canSubmit ? 1.0 : 0.0,
            duration: AppAnimations.standard,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryColor, AppColors.primaryGradientEnd],
                ),
                borderRadius:
                    BorderRadius.circular(AppBorderRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryColor
                        .withValues(alpha: AppOpacity.strong + 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: canSubmit ? 0.0 : 1.0,
            duration: AppAnimations.standard,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.lightColor,
                borderRadius:
                    BorderRadius.circular(AppBorderRadius.lg),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius:
                  BorderRadius.circular(AppBorderRadius.lg),
              child: Center(
                child: AnimatedSwitcher(
                  duration: AppAnimations.fast,
                  child: busy
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          key: const ValueKey('label'),
                          isLogin ? 'Sign In' : 'Create Account',
                          style: AppTypography.buttonText.copyWith(
                            color: canSubmit
                                ? Colors.white
                                : AppColors.mediumColor,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mode toggle ──────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.isLogin, required this.onSwitch});

  final bool isLogin;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isLogin
              ? "Don't have an account? "
              : 'Already have an account? ',
          style: AppTypography.smallBodyRegular
              .copyWith(color: AppColors.mediumColor),
        ),
        GestureDetector(
          onTap: onSwitch,
          child: Text(
            isLogin ? 'Create one' : 'Sign in',
            style: AppTypography.smallBodySemibold
                .copyWith(color: AppColors.primaryColor),
          ),
        ),
      ],
    );
  }
}

