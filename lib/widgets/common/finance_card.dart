import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';

/// Wiederverwendbare Finanz-Karte
///
/// Zeigt finanzielle Beträge mit Farb-Kodierung an.
/// Verwendet für Einnahmen, Ausgaben, Salden etc.
class FinanceCard extends StatelessWidget {
  final String label;
  final double amount;
  final String? subtitle;
  final Color color;
  final bool isBold;
  final VoidCallback? onTap;

  const FinanceCard({
    required this.label,
    required this.amount,
    this.subtitle,
    required this.color,
    this.isBold = false,
    this.onTap,
    super.key,
  });

  /// Factory: Einnahmen-Karte (grün)
  factory FinanceCard.income({
    required String label,
    required double amount,
    String? subtitle,
    bool isBold = false,
  }) {
    return FinanceCard(
      label: label,
      amount: amount,
      subtitle: subtitle,
      color: AppConstants.successColor,
      isBold: isBold,
    );
  }

  /// Factory: Ausgaben-Karte (rot/pink)
  factory FinanceCard.expense({
    required String label,
    required double amount,
    String? subtitle,
    bool isBold = false,
  }) {
    return FinanceCard(
      label: label,
      amount: amount,
      subtitle: subtitle,
      color: const Color(0xFFE91E63),
      isBold: isBold,
    );
  }

  /// Factory: Saldo-Karte (blau)
  factory FinanceCard.balance({
    required String label,
    required double amount,
    String? subtitle,
    bool isBold = true,
  }) {
    return FinanceCard(
      label: label,
      amount: amount,
      subtitle: subtitle,
      color: AppConstants.primaryColor,
      isBold: isBold,
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: AppConstants.paddingAll16,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppConstants.borderRadius8,
        border: isBold ? Border.all(color: color, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.8),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            NumberFormat.currency(locale: 'de_DE', symbol: '€').format(amount),
            style: TextStyle(
              fontSize: 24,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.6),
              ),
            ),
          ],
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
