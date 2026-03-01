---
name: flutter-ui-standard
description: >
  UI design system authority for the XCeleration codebase. Read this skill
  whenever building, modifying, or reviewing any UI file — screens, widgets,
  or shared components. Defines token usage, component rules, the Liquid Glass
  aesthetic, spacing density, and micro-animation standards.
---

# Flutter UI Standard — XCeleration Codebase

Read this file fully before touching any widget, screen, or component file.

---

## Philosophy

- Design tokens are single-source-of-truth. Magic numbers are defects.
- If a UI element appears in more than one place, it must be a standalone widget in `lib/core/components/`.
- Glass effects must prioritize readability and contrast over visual novelty.
- Motion must feel responsive, never decorative. Every animation must serve a state change.

---

## Token System

All visual values must come from the token classes below. Never inline colors, sizes, radii, durations, or opacity values.

All token classes use `static const` values — they are plain Dart constants, not `ThemeExtension`s. Do not use `Theme.of(context)` to look up spacing, radii, opacity, or shadow values. Only `AppTypography` text styles may be referenced via `Theme.of(context).textTheme` if explicitly wired up in `ThemeData`; otherwise call `AppTypography.*` directly.

### AppTypography — `lib/core/theme/typography.dart`

Already exists. Use its constants directly — do not redefine them. Key styles:

| Token | Role |
|---|---|
| `AppTypography.displayLarge` | Hero titles |
| `AppTypography.titleSemibold` | Section headers |
| `AppTypography.bodyRegular` | Standard body text |
| `AppTypography.captionRegular` | Secondary / helper text |

Reference `AppTypography` for every `Text` widget. Never hardcode `fontSize`, `fontWeight`, or `fontFamily`.

### AppColors — `lib/core/theme/app_colors.dart`

Existing palette (already established, do not redefine):

| Token | Hex | Role |
|---|---|---|
| `backgroundColor` | `0xFFFFFDFF` | App background |
| `darkColor` | `0xFF212227` | Primary text |
| `mediumColor` | `0xFF606060` | Secondary text |
| `lightColor` | `0xFFEBEBEB` | Disabled / divider |
| `primaryColor` | `0xFFE2572B` | Actions, accent |
| `navBarColor` | `0xFFE2572B` | Navigation |
| `redColor` | `0xFFA81F15` | Error / danger |
| `selectedRoleColor` | `0xFFFBE5E1` | Selected state background |
| `unselectedRoleColor` | `0xFFF5F3FB` | Unselected state background |

**Status colors** — add these to `AppColors` if not already present:

```dart
static const Color statusSetup    = Color(0xFFFFC107); // amber
static const Color statusPreRace  = Color(0xFF2196F3); // blue
static const Color statusPostRace = Color(0xFF9C27B0); // purple
static const Color statusFinished = Color(0xFF4CAF50); // green
```

---

### AppSpacing — `lib/core/theme/app_spacing.dart`

Create this class if it does not exist. Reference it everywhere instead of raw pixel values.

```dart
abstract final class AppSpacing {
  // Micro — tight list items, badges, icon insets
  static const double xs  = 4;
  static const double sm  = 8;

  // Standard — component padding, gaps between elements
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 24;

  // Layout — screen-level margins, section gaps
  static const double xxl = 32;
  static const double xxxl = 48;
}
```

---

### AppBorderRadius — `lib/core/theme/app_border_radius.dart`

Create this class if it does not exist.

```dart
abstract final class AppBorderRadius {
  static const double xs     = 4;   // Tiny chip corners
  static const double sm     = 8;   // Icon containers, badges
  static const double md     = 12;  // Inputs, toggles
  static const double lg     = 16;  // Cards, buttons
  static const double xl     = 24;  // Glass cards, modals
  static const double full   = 999; // Pills, circular containers
}
```

---

### AppShadows — `lib/core/theme/app_shadows.dart`

Create this class if it does not exist.

```dart
abstract final class AppShadows {
  /// Subtle card lift — most common.
  static const List<BoxShadow> low = [
    BoxShadow(
      color: Color(0x14000000), // black at 8%
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// Glass surface depth.
  static const List<BoxShadow> glass = [
    BoxShadow(
      color: Color(0x1A000000), // black at 10%
      blurRadius: 40,
      offset: Offset(0, 20),
    ),
  ];

  /// Elevated action elements.
  static const List<BoxShadow> high = [
    BoxShadow(
      color: Color(0x29000000), // black at 16%
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}
```

---

### AppOpacity — `lib/core/theme/app_opacity.dart`

Create this class if it does not exist.

```dart
abstract final class AppOpacity {
  static const double faint   = 0.05; // Very subtle tints
  static const double light   = 0.10; // Icon badge backgrounds
  static const double medium  = 0.20; // Accent backgrounds
  static const double strong  = 0.30; // Borders, dividers
  static const double solid   = 0.50; // Disabled overlays
  static const double glass   = 0.85; // Glass card surface
  static const double border  = 0.70; // Glass card border
}
```

---

### AppAnimations — `lib/core/theme/app_animations.dart`

Create this class if it does not exist.

```dart
abstract final class AppAnimations {
  // Durations
  static const Duration instant  = Duration(milliseconds: 100);
  static const Duration fast     = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration slow     = Duration(milliseconds: 400);
  static const Duration reveal   = Duration(milliseconds: 350);

  // Curves
  static const Curve enter  = Curves.easeOut;
  static const Curve exit   = Curves.easeIn;
  static const Curve spring = Curves.easeInOutCubic;
}
```

---

## The Liquid Glass Aesthetic

### What It Is

Liquid Glass is a layered surface system that creates depth through translucency, blur, and soft borders — not drop shadows alone. It must always pass a contrast check. If text is unreadable, the glass opacity is too low.

### When to Use Glass

| Surface | Use Glass? |
|---|---|
| Modals, sheets | Yes — primary use case |
| Card overlays on an image background | Yes |
| Standard content cards on a flat background | No — use opaque card |
| List items | No — compact mode uses opaque rows |
| Input fields | No — glass is visually noisy behind text input |

### Glass Rules

1. **Blur**: `sigmaX: 20, sigmaY: 20` (standard), `sigmaX: 10, sigmaY: 10` (subtle).
2. **Surface fill**: `Colors.white.withValues(alpha: AppOpacity.glass)` — never fully transparent.
3. **Border**: 1px stroke, `Colors.white.withValues(alpha: AppOpacity.border)`.
4. **Border radius**: `AppBorderRadius.xl` (24) for cards, `AppBorderRadius.lg` (16) for inline glass.
5. **Shadow**: `AppShadows.glass` for full glass cards, `AppShadows.low` for inline elements.
6. **Never stack two glass surfaces** — only the foremost element may use `BackdropFilter`.
7. **Performance**: Never use `BackdropFilter` inside `ListView.builder`, `SliverList`, or any widget that is rebuilt per-item in a scrolling list. `BackdropFilter` forces a rasterization pass on every frame it is visible — applying it to 20+ list items will cause dropped frames. Glass is only for static overlays, modals, headers, and fixed-position surfaces.

### Best Practice: Glass Card

```dart
// lib/core/components/glass_card.dart
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.borderRadius = AppBorderRadius.xl,
    this.blurSigma = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: AppOpacity.glass),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: AppOpacity.border),
              width: 1,
            ),
            boxShadow: AppShadows.glass,
          ),
          child: child,
        ),
      ),
    );
  }
}
```

---

## Component-Driven Development

### Rule

If a UI pattern appears in more than one place, extract it. No duplication. No exceptions.

### Location

All shared components live in `lib/core/components/`. Feature-specific reusable widgets live in `lib/features/<feature>/widgets/`.

### God Widget Rule

A widget file must not exceed **300 lines** of UI code (same limit as controllers). When a `build()` method passes **50 lines**, extract a named sub-widget. Sub-widgets receive only the data they render — they do not call `context.watch` unless they own a distinct rebuild concern.

### Best Practice: Standardized List Item

This pattern covers the most common data-heavy list row in the app. It uses compact-mode tokens and implicit animations.

**When to use `StatefulWidget` for press effects:** Use `StatefulWidget` with `GestureDetector` + `AnimatedContainer` when you need a custom animated press highlight (colored background, scale). Use `InkWell` (which is `StatelessWidget`-compatible) when the standard Material ripple is acceptable and no custom animation is needed. For list items in XCeleration, the custom press color matches the brand — use `StatefulWidget`.

```dart
// lib/core/components/standard_list_item.dart
class StandardListItem extends StatefulWidget {
  const StandardListItem({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isCompact = false,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Compact mode: tighter padding for data-dense screens.
  final bool isCompact;

  @override
  State<StandardListItem> createState() => _StandardListItemState();
}

class _StandardListItemState extends State<StandardListItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final hPad = widget.isCompact ? AppSpacing.sm : AppSpacing.lg;
    final vPad = widget.isCompact ? AppSpacing.xs : AppSpacing.md;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.spring,
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.primaryColor.withValues(alpha: AppOpacity.faint)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        child: Row(
          children: [
            widget.leading,
            SizedBox(width: widget.isCompact ? AppSpacing.sm : AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: AppTypography.bodyRegular),
                  if (widget.subtitle != null) ...[
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.subtitle!,
                      style: AppTypography.captionRegular.copyWith(
                        color: AppColors.mediumColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.trailing != null) ...[
              SizedBox(width: AppSpacing.sm),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
```

---

## Adaptive Density

### Rule

Density is set per-screen, not per-widget. The widget responds to a boolean `isCompact` flag — the screen decides the mode.

| Mode | Horizontal padding | Vertical padding | Gap between items | When to use |
|---|---|---|---|---|
| **Generous** | `AppSpacing.lg` (16) | `AppSpacing.md` (12) | `AppSpacing.lg` (16) | Settings, forms, onboarding, headers |
| **Standard** | `AppSpacing.lg` (16) | `AppSpacing.sm` (8) | `AppSpacing.md` (12) | Most content screens |
| **Compact** | `AppSpacing.sm` (8) | `AppSpacing.xs` (4) | `AppSpacing.xs` (4) | Data-heavy tables, runner lists, timing screens |

### How to Apply

Pass density context down from the screen level, not from deep inside a component tree:

```dart
// In a timing screen with a dense runner list:
RunnerListItem(
  runner: runner,
  isCompact: true, // Screen decides density
)
```

Never hardcode dense values inside a shared component. The component is density-aware; the screen picks the mode.

---

## Micro-Animations

### Rule

All meaningful UI state transitions should be animated unless performance or clarity would suffer. Static jumps are not acceptable in production UI. All animations use the token durations and curves from `AppAnimations`.

### Required Animation Patterns

| Trigger | Animation | Duration | Widget |
|---|---|---|---|
| Element enters screen | `AnimatedOpacity` 0 → 1, staggered | `AppAnimations.reveal` | List items, cards |
| User taps interactive element | `AnimatedContainer` — scale or bg color change | `AppAnimations.fast` | Buttons, list rows |
| Loading → content transition | `AnimatedSwitcher` | `AppAnimations.standard` | Any async content |
| State badge changes | `AnimatedContainer` — color + border | `AppAnimations.standard` | Status indicators |
| Icon or size change | `AnimatedScale` | `AppAnimations.fast` | Toggle icons, FAB |
| Collapsible section | `AnimatedSize` | `AppAnimations.standard` | Instruction cards, drawers |

### Example: Staggered List Reveal

```dart
class _AnimatedListItem extends StatefulWidget {
  const _AnimatedListItem({required this.child, required this.index});
  final Widget child;
  final int index;

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) setState(() => _opacity = 1);
    });
    // Limit: only use this pattern for lists with ≤ 20 visible items.
    // For longer lists, switch to AnimationController + Interval or SliverAnimatedList
    // to avoid scheduling many parallel timers.
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: AppAnimations.reveal,
      curve: AppAnimations.enter,
      child: widget.child,
    );
  }
}
```

### Forbidden Animation Patterns

- Do not use `Future.delayed` for stagger delays longer than `index * 60ms` — beyond that, users wait.
- Do not animate layout properties (width, height) without `AnimatedContainer` or `AnimatedSize` — never use setState with a raw resize.
- Do not animate color without using `AnimatedContainer`'s `decoration` parameter or `ColorTween`.
- Do not use `AnimatedBuilder` when an implicit animation widget (`AnimatedOpacity`, `AnimatedScale`, etc.) covers the use case.

---

## Process: Touching a UI File

Follow this sequence whenever you modify or create a UI file.

### Step 1 — Token Audit

Before writing any new values, scan the file for:
- Raw color literals (`Color(0xFF...)`, `Colors.*`) not from `AppColors`
- Raw pixel values for padding, radius, or spacing not from token classes
- Raw opacity values not from `AppOpacity`

Flag each with:

```dart
// TODO(ui): replace magic number with AppSpacing / AppBorderRadius / AppOpacity token
```

### Step 2 — Component Audit

Check whether any widget subtree in the file is duplicated elsewhere. If yes, extract it to `lib/core/components/` and replace both usages with the new component.

### Step 3 — Animation Audit

Check every state change for missing animation. Apply the table in the Micro-Animations section.

### Step 4 — Glass Audit

If a surface uses `BackdropFilter` or `BoxDecoration` with opacity, verify it follows the Glass Rules section. Never leave a glass surface without a border and shadow.

### Step 5 — Density Audit

If the screen is data-heavy (lists with 10+ items, timing data, scoring tables), apply compact mode. Pass `isCompact: true` to the relevant components.

### Step 6 — Verify

```sh
flutter analyze
flutter test
```

Both must pass before the file is considered done.

---

## Non-Negotiables

Check every item before every pull request, and before marking any UI file as complete.

### Tokens

- [ ] No raw `Color(0xFF...)` literals — all colors from `AppColors`
- [ ] No raw pixel values for padding or margin — all spacing from `AppSpacing`
- [ ] No raw pixel values for border radius — all radii from `AppBorderRadius`
- [ ] No raw opacity values — all opacity from `AppOpacity`
- [ ] No hardcoded shadow definitions — all shadows from `AppShadows`
- [ ] No hardcoded animation durations or curves — all from `AppAnimations`

### Components

- [ ] No UI pattern is duplicated across two or more files
- [ ] All shared components live in `lib/core/components/` or `lib/features/<x>/widgets/`
- [ ] No widget file exceeds 300 lines
- [ ] No `build()` method exceeds 50 lines without extracting a named sub-widget
- [ ] Sub-widgets receive only the data they render — no unauthorized `context.watch` calls

### Glass

- [ ] Every `BackdropFilter` surface has a `ClipRRect` parent
- [ ] Every glass surface has a 1px white border
- [ ] Every glass surface has a shadow from `AppShadows`
- [ ] No glass surface is applied to list rows or input fields
- [ ] Text on glass surfaces passes contrast check (readable without squinting)

### Density

- [ ] Data-heavy screens (timing, runner lists) use compact mode
- [ ] Compact mode is set at the screen level, not inside the component
- [ ] No component hardcodes padding — it must accept `isCompact` or equivalent

### Animations

- [ ] Every state change is animated — no static jumps
- [ ] List items use staggered `AnimatedOpacity` on initial render
- [ ] Interactive elements respond to press with `AnimatedContainer` or `AnimatedScale`
- [ ] `AnimatedSwitcher` wraps all async loading → content transitions
- [ ] No stagger delay exceeds `index * 60ms`

### Quality

- [ ] `flutter analyze` passes with zero warnings
- [ ] `flutter test` passes
