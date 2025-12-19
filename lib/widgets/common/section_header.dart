import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// Wiederverwendbarer Section-Header
///
/// Zeigt einen formatierten Header für Abschnitte an.
/// Unterstützt optionale Icons und verschiedene Stile.
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final double? iconSize;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;

  const SectionHeader({
    required this.title,
    this.icon,
    this.iconColor,
    this.iconSize,
    this.textStyle,
    this.padding,
    super.key,
  });

  /// Factory: Großer Header mit Icon (für Hauptabschnitte)
  factory SectionHeader.large({
    required String title,
    required IconData icon,
    Color? iconColor,
  }) {
    return SectionHeader(
      title: title,
      icon: icon,
      iconColor: iconColor ?? AppConstants.primaryColor,
      iconSize: 24,
      textStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      padding: const EdgeInsets.only(bottom: AppConstants.spacing),
    );
  }

  /// Factory: Mittlerer Header mit Icon (für Unterabschnitte)
  factory SectionHeader.medium({
    required String title,
    IconData? icon,
    Color? iconColor,
  }) {
    return SectionHeader(
      title: title,
      icon: icon,
      iconColor: iconColor,
      iconSize: 24,
      textStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
    );
  }

  /// Factory: Kleiner Header ohne Icon (für Formulare)
  factory SectionHeader.small({
    required String title,
  }) {
    return SectionHeader(
      title: title,
      textStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      padding: const EdgeInsets.only(
        bottom: AppConstants.spacing,
        top: AppConstants.spacingS,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;

    if (icon != null) {
      // Header mit Icon
      content = Row(
        children: [
          Container(
            padding: AppConstants.paddingAll8,
            decoration: BoxDecoration(
              color: (iconColor ?? AppConstants.primaryColor).withValues(alpha: 0.1),
              borderRadius: AppConstants.borderRadius8,
            ),
            child: Icon(
              icon,
              color: iconColor ?? AppConstants.primaryColor,
              size: iconSize ?? 24,
            ),
          ),
          const SizedBox(width: AppConstants.spacingM),
          Text(
            title,
            style: textStyle ??
                const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      );
    } else {
      // Nur Text
      content = Text(
        title,
        style: textStyle ??
            const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
      );
    }

    if (padding != null) {
      return Padding(
        padding: padding!,
        child: content,
      );
    }

    return content;
  }
}
