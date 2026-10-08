import 'package:flutter/material.dart';

import 'animations.dart';

/// Chunky, toy-like button: a glossy gradient pill with a raised "3D" lip
/// underneath, or a white pill with a colored border when [outlined].
class KidButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool outlined;

  /// Swaps the icon for a spinner and ignores taps while true.
  final bool loading;

  const KidButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final darker = Color.lerp(color, Colors.black, 0.22)!;
    final foreground = outlined ? color : Colors.white;
    return Semantics(
      button: true,
      label: label,
      child: Bouncy(
        onTap: loading ? null : onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            color: outlined ? Colors.white : null,
            gradient: outlined
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.lerp(color, Colors.white, 0.25)!, color],
                  ),
            borderRadius: BorderRadius.circular(30),
            border: outlined ? Border.all(color: color, width: 2.5) : null,
            boxShadow: [
              // Solid offset shadow reads as the button's raised edge.
              BoxShadow(
                color: outlined ? color.withValues(alpha: 0.35) : darker,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: foreground,
                  ),
                )
              else
                Icon(icon, color: foreground, size: 28),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: foreground,
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
