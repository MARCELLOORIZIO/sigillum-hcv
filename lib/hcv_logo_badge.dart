import 'package:flutter/material.dart';

class HCVLogoBadge extends StatelessWidget {
  final double size;
  final bool compact;

  const HCVLogoBadge({
    super.key,
    this.size = 42,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final outer = size;
    final inner = size * 0.52;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.58),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.22),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: outer,
            height: outer,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: 0.785398,
                  child: Container(
                    width: outer * 0.74,
                    height: outer * 0.74,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: 0.785398,
                  child: Container(
                    width: inner * 0.74,
                    height: inner * 0.74,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white,
                        width: 2.4,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SIGILLUM',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 2.2,
                    height: 1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'HUMAN VERIFIED',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                    letterSpacing: 1.4,
                    height: 1,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
