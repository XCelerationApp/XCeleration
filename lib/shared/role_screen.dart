import 'package:flutter/material.dart';
import '../coach/bib_conflict_resolution/screen/conflict_resolution_screen.dart';
import '../coach/races_screen/screen/races_screen.dart';
import '../spectator/races_screen/screen/spectator_races_screen.dart';
import '../assistant/race_timer/screen/timing_screen.dart';
import '../assistant/bib_number_recorder/screen/bib_number_screen.dart';
import '../assistant/bib_number_recorder/controller/bib_number_controller.dart';
import '../assistant/shared/services/assistant_storage_service.dart';
import '../assistant/shared/services/demo_race_generator_impl.dart';
import '../core/services/device_connection_factory_impl.dart';
import '../core/services/post_frame_scheduler.dart';
import '../core/services/tutorial_manager.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_border_radius.dart';
import '../core/theme/app_opacity.dart';
import '../core/theme/app_animations.dart';
import '../core/theme/typography.dart';
import '../core/components/page_route_animations.dart';
import '../core/services/auth_service.dart';
import '../core/services/profile_service.dart';
import '../core/services/remote_api_client.dart';
import 'screens/sign_in_screen.dart';

// ─── Role data ────────────────────────────────────────────────────────────────

class _RoleData {
  const _RoleData({
    required this.label,
    required this.description,
    required this.onPressed,
  });

  final String label;
  final String description;
  final VoidCallback onPressed;
}

// ─── Speed-lines decoration ───────────────────────────────────────────────────

class _SpeedLinesPainter extends CustomPainter {
  const _SpeedLinesPainter(this.opacity);
  final double opacity;

  // (startX, y, strokeWidth) — each line runs from startX to the right edge
  static const _specs = [
    (80.0, 30.0, 2.5), (30.0, 56.0, 2.0), (0.0, 82.0, 1.5),
    (50.0, 108.0, 1.0), (100.0, 134.0, 2.0), (20.0, 160.0, 2.5),
    (70.0, 186.0, 1.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..strokeCap = StrokeCap.round;
    for (final (x1, y, w) in _specs) {
      p
        ..color = Colors.white.withValues(alpha: opacity)
        ..strokeWidth = w;
      canvas.drawLine(Offset(x1, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_SpeedLinesPainter old) => old.opacity != opacity;
}

// ─── Role row (on gradient) ───────────────────────────────────────────────────

class _RoleRow extends StatefulWidget {
  const _RoleRow({required this.data, required this.isLast, required this.index});
  final _RoleData data;
  final bool isLast;
  final int index;

  @override
  State<_RoleRow> createState() => _RoleRowState();
}

class _RoleRowState extends State<_RoleRow> {
  bool _pressed = false;
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 120 + widget.index * 80), () {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  void _onTapUp(_) {
    setState(() => _pressed = false);
    widget.data.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: AppAnimations.slow,
      curve: AppAnimations.enter,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: _onTapUp,
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedOpacity(
          opacity: _pressed ? 0.75 : 1.0,
          duration: AppAnimations.fast,
          child: AnimatedSlide(
            offset: _pressed ? const Offset(0.01, 0) : Offset.zero,
            duration: AppAnimations.fast,
            child: _buildRow(),
          ),
        ),
      ),
    );
  }

  Widget _buildRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      decoration: BoxDecoration(
        border: widget.isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
      ),
      child: Row(
        children: [
          Expanded(child: _buildText()),
          const SizedBox(width: AppSpacing.md),
          _buildChevron(),
        ],
      ),
    );
  }

  Widget _buildText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.data.label,
          style: AppTypography.titleLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          widget.data.description,
          style: AppTypography.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildChevron() {
    return AnimatedContainer(
      duration: AppAnimations.fast,
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: _pressed ? 0.8 : 0.35),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '›',
        style: AppTypography.bodyRegular.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w300,
          height: 1,
        ),
      ),
    );
  }
}

// ─── Sub-role card (inside assistant bottom sheet) ────────────────────────────

class _SubRoleCard extends StatefulWidget {
  const _SubRoleCard({
    required this.label,
    required this.description,
    required this.onPressed,
    required this.index,
  });

  final String label;
  final String description;
  final VoidCallback onPressed;
  final int index;

  @override
  State<_SubRoleCard> createState() => _SubRoleCardState();
}

class _SubRoleCardState extends State<_SubRoleCard> {
  bool _pressed = false;
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  void _onTapUp(_) {
    setState(() => _pressed = false);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: AppAnimations.reveal,
      curve: AppAnimations.enter,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: _onTapUp,
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.975 : 1.0,
          duration: AppAnimations.fast,
          curve: AppAnimations.spring,
          child: _buildCard(),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return AnimatedContainer(
      duration: AppAnimations.fast,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        // TODO(ui): #fafafa is not in AppColors — closest is backgroundColor
        color: _pressed
            ? AppColors.primaryColor.withValues(alpha: AppOpacity.faint)
            : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(
          color: _pressed ? AppColors.primaryColor : AppColors.lightColor,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: AppTypography.headerSemibold.copyWith(
                    color: AppColors.darkColor,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.description,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.mediumColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AnimatedContainer(
            duration: AppAnimations.fast,
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _pressed ? AppColors.primaryColor : AppColors.lightColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '›',
              style: AppTypography.bodySmall.copyWith(
                color: _pressed ? Colors.white : AppColors.mediumColor,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Assistant screen ─────────────────────────────────────────────────────────

class _AssistantScreen extends StatefulWidget {
  const _AssistantScreen();

  @override
  State<_AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<_AssistantScreen> {
  late final List<_RoleData> _roles;

  @override
  void initState() {
    super.initState();
    _roles = [
      _RoleData(
        label: 'Timer',
        description: "Tap to record each runner's finish time as they cross the line",
        onPressed: _onTimer,
      ),
      _RoleData(
        label: 'Bib Recorder',
        description: "Enter bib numbers in finishing order. Syncs with the coach's device.",
        onPressed: _onRecorder,
      ),
    ];
  }

  void _onTimer() => Navigator.of(context).push(
        InitialPageRouteAnimation(child: const TimingScreen()),
      );

  void _onRecorder() => Navigator.of(context).push(
        InitialPageRouteAnimation(
          child: BibNumberScreen(
            controller: BibNumberController(
              storage: AssistantStorageService.instance,
              tutorialManager: TutorialManager(),
              demoRaceGenerator: const DemoRaceGeneratorImpl(),
              deviceConnectionFactory: const DeviceConnectionFactoryImpl(),
              scheduler: const PostFrameScheduler(),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _gradientBg,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                bottom: 0,
                right: 0,
                child: CustomPaint(
                  size: const Size(200, 200),
                  painter: const _SpeedLinesPainter(0.10),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  Expanded(child: _buildRoleList()),
                ],
              ),
              SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    InitialPageRouteAnimation(
                      child: const ConflictResolutionScreen(),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.all(14),
                    minimumSize: const Size(300, 50),
                  ),
                  child: const Text(
                    '[DEV] Conflict Resolution Prototype',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: AppOpacity.medium),
                borderRadius: BorderRadius.circular(AppBorderRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '‹',
                    style: AppTypography.smallBodySemibold.copyWith(
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Back',
                    style: AppTypography.smallBodySemibold.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'I am a…',
            style: AppTypography.bodyRegular.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          for (var i = 0; i < _roles.length; i++)
            _RoleRow(
              data: _roles[i],
              isLast: i == _roles.length - 1,
              index: i,
            ),
        ],
      ),
    );
  }
}

// ─── Gradient background ──────────────────────────────────────────────────────

const _gradientBg = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment(0.17, -1),
    end: Alignment(-0.17, 1),
    colors: [AppColors.primaryColor, AppColors.darkPrimaryColor],
  ),
);

// ─── Role selection screen ────────────────────────────────────────────────────

class RoleScreen extends StatefulWidget {
  const RoleScreen({super.key});

  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  late final List<_RoleData> _roles;

  @override
  void initState() {
    super.initState();
    _roles = [
      _RoleData(
        label: 'Coach',
        description: 'Create races, manage your team, and review results',
        onPressed: _onCoach,
      ),
      _RoleData(
        label: 'Assistant',
        description: 'Record times or bib numbers at the finish line',
        onPressed: _onAssistant,
      ),
      _RoleData(
        label: 'Spectator',
        description: 'Follow live results and track your athletes',
        onPressed: _onSpectator,
      ),
    ];
  }

  void _onCoach() {
    if (!AuthService.instance.isSignedIn) {
      Navigator.of(context).push(
        InitialPageRouteAnimation(
          child: SignInScreen(
            authService: AuthService.instance,
            profileService: ProfileService(
              remoteApi: RemoteApiClient(),
              auth: AuthService.instance,
            ),
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      InitialPageRouteAnimation(child: const RacesScreen()),
    );
  }

  void _onAssistant() => Navigator.of(context).push(
        InitialPageRouteAnimation(child: const _AssistantScreen()),
      );

  void _onSpectator() => Navigator.of(context).push(
        InitialPageRouteAnimation(child: const SpectatorRacesScreen()),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _gradientBg,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                bottom: 0,
                right: 0,
                child: CustomPaint(
                  size: const Size(200, 200),
                  painter: const _SpeedLinesPainter(0.10),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  Expanded(child: _buildRoleList()),
                ],
              ),
              Positioned(
                bottom: AppSpacing.sm,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        InitialPageRouteAnimation(
                          child: const ConflictResolutionScreen(),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.all(14),
                        minimumSize: const Size(300, 50),
                      ),
                      child: const Text(
                        '[DEV] Conflict Resolution Prototype',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'XCeleration',
            style: AppTypography.displayLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: -3,
              height: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'I am a…',
            style: AppTypography.bodyRegular.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          for (var i = 0; i < _roles.length; i++)
            _RoleRow(
              data: _roles[i],
              isLast: i == _roles.length - 1,
              index: i,
            ),
        ],
      ),
    );
  }
}
