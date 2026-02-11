import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Responsive Container für Formulare
///
/// Beschränkt die Breite von Formularen auf Desktop-Geräten für bessere Lesbarkeit
/// und eine ansprechendere Darstellung
class ResponsiveFormContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveFormContainer({
    super.key,
    required this.child,
    this.maxWidth = 800,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: padding ?? AppConstants.paddingAll16,
        child: child,
      ),
    );
  }
}
