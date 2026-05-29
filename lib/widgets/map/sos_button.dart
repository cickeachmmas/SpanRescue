// ═══════════════════════════════════════════════════════
// sos_button.dart — زر SOS النابض
// ═══════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SOSButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Animation<double> animation;

  const SOSButton({
    super.key,
    required this.onPressed,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // هالة خارجية نابضة
            Transform.scale(
              scale: animation.value,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentRed.withOpacity(0.15),
                ),
              ),
            ),
            // الزر الرئيسي
            GestureDetector(
              onTap: onPressed,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentRed,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentRed.withOpacity(0.5),
                      blurRadius: 16,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
