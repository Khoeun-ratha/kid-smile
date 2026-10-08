import 'package:flutter/material.dart';

/// Coarse device classes the layouts adapt to.
enum ScreenClass {
  /// Very little height — a phone held sideways.
  short,

  /// A phone held upright.
  phone,

  /// Tablets, desktops and big browser windows.
  large,
}

ScreenClass screenClassOf(Size size) {
  if (size.height < 500) return ScreenClass.short;
  if (size.shortestSide >= 600) return ScreenClass.large;
  return ScreenClass.phone;
}

extension ResponsiveContext on BuildContext {
  ScreenClass get screenClass => screenClassOf(MediaQuery.sizeOf(this));
  bool get isShortScreen => screenClass == ScreenClass.short;
  bool get isLargeScreen => screenClass == ScreenClass.large;
}

/// Keeps the OS text-size setting working, but within limits the layouts
/// were designed for, so very large settings can't push buttons and
/// tiles past their edges.
class ClampTextScale extends StatelessWidget {
  final Widget child;
  final double min;
  final double max;

  const ClampTextScale({
    super.key,
    required this.child,
    this.min = 0.9,
    this.max = 1.3,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(
          minScaleFactor: min,
          maxScaleFactor: max,
        ),
      ),
      child: child,
    );
  }
}
