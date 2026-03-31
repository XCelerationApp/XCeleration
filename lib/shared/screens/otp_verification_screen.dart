import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gotrue/gotrue.dart' as gotrue;
import 'package:provider/provider.dart';
import 'package:xceleration/coach/races_screen/screen/races_screen.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:xceleration/core/components/page_route_animations.dart';
import 'package:xceleration/core/repositories/i_database_connection_provider.dart';
import 'package:xceleration/core/services/i_auth_service.dart';
import 'package:xceleration/core/services/i_sync_service.dart';
import 'package:xceleration/core/services/profile_service.dart';
import 'package:xceleration/core/services/service_locator.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

enum OtpMode { signup, passwordReset }

// ─── Screen ───────────────────────────────────────────────────────────────────

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.mode,
    required IAuthService authService,
    ProfileService? profileService,
  })  : _authService = authService,
        _profileService = profileService;

  final String email;
  final OtpMode mode;
  final IAuthService _authService;
  final ProfileService? _profileService;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpFocus = FocusNode();

  bool _busy = false;
  bool _obscure = true;
  bool _otpVerified = false;
  String? _otpError;
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
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _otpError = 'Enter the 6-digit code from your email');
      _shakeController.forward(from: 0);
      return;
    }
    final syncService = context.read<ISyncService>();
    setState(() {
      _busy = true;
      _otpError = null;
    });
    try {
      if (widget.mode == OtpMode.signup) {
        await widget._authService.verifyEmailOtp(widget.email, code);
        if (!mounted) return;
        try {
          final userId = widget._authService.currentUserId!;
          await ServiceLocator.get<IDatabaseConnectionProvider>()
              .openForUser(userId);
          await widget._profileService?.ensureProfileUpsert();
          await syncService.syncAll();
        } catch (_) {}
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
            RolePageRouteAnimation(child: const RacesScreen()),
            (route) => false);
      } else {
        await widget._authService.verifyPasswordResetOtp(widget.email, code);
        if (mounted) setState(() => _otpVerified = true);
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showMessageDialog(context,
            title: 'Error', message: _formatError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    if (password.length < 6) {
      setState(() => _passwordError = 'Use at least 6 characters');
      _shakeController.forward(from: 0);
      return;
    }
    setState(() {
      _busy = true;
      _passwordError = null;
    });
    try {
      await widget._authService.updatePassword(password);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. Please sign in.')),
      );
    } catch (e) {
      if (mounted) {
        DialogUtils.showMessageDialog(context,
            title: 'Error', message: _formatError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    try {
      if (widget.mode == OtpMode.signup) {
        await widget._authService.resendEmailConfirmation(widget.email);
      } else {
        await widget._authService.sendPasswordResetEmail(widget.email);
      }
      if (mounted) {
        DialogUtils.showMessageDialog(context,
            title: 'Code sent',
            message: 'A new code has been sent to ${widget.email}.');
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showMessageDialog(context,
            title: 'Error', message: _formatError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatError(Object error) {
    if (error is SocketException) {
      return 'No internet connection. Please check your connection and try again.';
    }
    if (error is TimeoutException) {
      return 'The request timed out. Please try again.';
    }
    if (error is gotrue.AuthApiException) {
      switch (error.code) {
        case 'otp_expired':
          return 'That code has expired. Tap "Resend code" to get a new one.';
        case 'token_has_been_used':
          return 'That code has already been used. Tap "Resend code" to get a new one.';
        case 'over_email_send_rate_limit':
          return 'Too many attempts. Please wait a minute and try again.';
        default:
          return error.message.isNotEmpty
              ? error.message
              : 'Invalid code. Please try again.';
      }
    }
    if (error is gotrue.AuthException) return error.message;
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mode == OtpMode.signup
        ? 'Verify your\nemail'
        : 'Reset your\npassword';
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OtpHeader(
                title: title,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: SlideTransition(
                    position: _shakeAnimation,
                    child: AnimatedSwitcher(
                      duration: AppAnimations.standard,
                      child: _otpVerified
                          ? _NewPasswordStep(
                              key: const ValueKey('password'),
                              controller: _passwordController,
                              obscure: _obscure,
                              error: _passwordError,
                              busy: _busy,
                              onToggleObscure: () =>
                                  setState(() => _obscure = !_obscure),
                              onPasswordChanged: (_) {
                                if (_passwordError != null) {
                                  setState(() => _passwordError = null);
                                }
                              },
                              onSubmit: _updatePassword,
                            )
                          : _OtpInputStep(
                              key: const ValueKey('otp'),
                              email: widget.email,
                              controller: _otpController,
                              focusNode: _otpFocus,
                              error: _otpError,
                              busy: _busy,
                              onChanged: (val) {
                                if (_otpError != null) {
                                  setState(() => _otpError = null);
                                }
                                if (val.length == 6) _verifyOtp();
                              },
                              onVerify: _verifyOtp,
                              onResend: _busy ? null : _resend,
                            ),
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

class _OtpHeader extends StatelessWidget {
  const _OtpHeader({required this.title, required this.onBack});

  final String title;
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
          Text(
            title,
            style: AppTypography.displaySmall.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.darkColor,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── OTP input step ───────────────────────────────────────────────────────────

class _OtpInputStep extends StatelessWidget {
  const _OtpInputStep({
    super.key,
    required this.email,
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.busy,
    required this.onChanged,
    required this.onVerify,
    required this.onResend,
  });

  final String email;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final bool busy;
  final ValueChanged<String> onChanged;
  final VoidCallback onVerify;
  final VoidCallback? onResend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.lightColor, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'We sent a 6-digit code to:',
            style: AppTypography.bodyRegular
                .copyWith(color: AppColors.mediumColor),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            email,
            style: AppTypography.bodyRegular.copyWith(
              color: AppColors.darkColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _OtpTextField(
            controller: controller,
            focusNode: focusNode,
            error: error,
            disabled: busy,
            onChanged: onChanged,
            onSubmitted: (_) => onVerify(),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _SubmitButton(
            label: 'Verify',
            busy: busy,
            enabled: !busy,
            onPressed: onVerify,
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: TextButton(
              onPressed: onResend,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: AppColors.primaryColor,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Resend code',
                style: AppTypography.smallBodySemibold
                    .copyWith(color: AppColors.primaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── New password step (password-reset only) ──────────────────────────────────

class _NewPasswordStep extends StatelessWidget {
  const _NewPasswordStep({
    super.key,
    required this.controller,
    required this.obscure,
    required this.error,
    required this.busy,
    required this.onToggleObscure,
    required this.onPasswordChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool obscure;
  final String? error;
  final bool busy;
  final VoidCallback onToggleObscure;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.lightColor, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Identity confirmed. Choose a new password.',
            style: AppTypography.bodyRegular
                .copyWith(color: AppColors.mediumColor),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _PasswordField(
            controller: controller,
            obscure: obscure,
            error: error,
            disabled: busy,
            onChanged: onPasswordChanged,
            onSubmitted: (_) => onSubmit(),
            onToggleObscure: onToggleObscure,
          ),
          const SizedBox(height: AppSpacing.xxl),
          _SubmitButton(
            label: 'Update Password',
            busy: busy,
            enabled: !busy,
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

// ─── OTP text field ───────────────────────────────────────────────────────────

class _OtpTextField extends StatefulWidget {
  const _OtpTextField({
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.disabled,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final bool disabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  State<_OtpTextField> createState() => _OtpTextFieldState();
}

class _OtpTextFieldState extends State<_OtpTextField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(
        () => setState(() => _focused = widget.focusNode.hasFocus));
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.error != null;
    final borderColor = hasError
        ? AppColors.primaryColor
        : _focused
            ? AppColors.primaryColor
            : AppColors.borderColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: AppAnimations.fast,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
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
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            enabled: !widget.disabled,
            autocorrect: false,
            enableSuggestions: false,
            style: AppTypography.displaySmall.copyWith(
              color: AppColors.darkColor,
              letterSpacing: AppSpacing.md,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              hintText: '------',
            ),
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

// ─── Password field ───────────────────────────────────────────────────────────

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.error,
    required this.disabled,
    required this.onChanged,
    required this.onSubmitted,
    required this.onToggleObscure,
  });

  final TextEditingController controller;
  final bool obscure;
  final String? error;
  final bool disabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onToggleObscure;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _focused = false;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
        () => setState(() => _focused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.error != null;
    final borderColor = hasError
        ? AppColors.primaryColor
        : _focused
            ? AppColors.primaryColor
            : AppColors.borderColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NEW PASSWORD',
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
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
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
                  focusNode: _focusNode,
                  obscureText: widget.obscure,
                  textInputAction: TextInputAction.done,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  enabled: !widget.disabled,
                  autocorrect: false,
                  enableSuggestions: false,
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
              TextButton(
                onPressed: widget.onToggleObscure,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  foregroundColor: AppColors.mediumColor,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  widget.obscure ? 'Show' : 'Hide',
                  style: AppTypography.smallBodySemibold
                      .copyWith(color: AppColors.mediumColor),
                ),
              ),
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
    required this.label,
    required this.busy,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;

  static final _activeDecoration = BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.primaryColor, AppColors.primaryGradientEnd],
    ),
    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
    boxShadow: [
      BoxShadow(
        color: AppColors.primaryColor
            .withValues(alpha: AppOpacity.strong + 0.05),
        blurRadius: 18,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static final _disabledDecoration = BoxDecoration(
    color: AppColors.lightColor,
    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: AppAnimations.standard,
            decoration: enabled ? _activeDecoration : _disabledDecoration,
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: busy ? null : onPressed,
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
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
                          key: ValueKey(label),
                          label,
                          style: AppTypography.buttonText.copyWith(
                            color: enabled
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
