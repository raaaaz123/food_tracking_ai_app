import 'package:flutter/material.dart';

class DotIndicator extends StatelessWidget {
  final bool isActive;
  final Color? activeColor;
  final Color? inactiveColor;

  const DotIndicator({
    super.key,
    this.isActive = false,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isActive ? 16 : 8,
      height: 8,
      decoration: BoxDecoration(
        color:
            isActive
                ? (activeColor ?? Theme.of(context).primaryColor)
                : (inactiveColor ?? Colors.grey.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
