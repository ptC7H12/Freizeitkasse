import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// Wiederverwendbare Statistik-Karte
///
/// Zeigt eine Statistik mit Label, Wert und Icon an.
/// Ideal für Dashboard und Übersichts-Screens.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: AppConstants.paddingAll16,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppConstants.borderRadius8,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppConstants.borderRadius8,
        child: card,
      );
    }

    return card;
  }
}
