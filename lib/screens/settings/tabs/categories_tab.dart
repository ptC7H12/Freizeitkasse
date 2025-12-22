import 'package:flutter/material.dart';
import '../../../utils/constants.dart';
import '../../../extensions/context_extensions.dart';
import '../categories_management_screen.dart';

/// Tab 3: Kategorien
///
/// Ausgaben- und Einnahmen-Kategorien
class CategoriesTab extends StatelessWidget {
  const CategoriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppConstants.paddingAll16,
      children: [
        Card(
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.category, color: Color(0xFF2196F3)),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Kategorien verwalten',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing),
                const Text(
                  'Verwalten Sie Ausgaben- und Einnahmen-Kategorien für eine bessere Organisation Ihrer Finanzen.',
                ),
                const SizedBox(height: AppConstants.spacing),
                ElevatedButton.icon(
                  onPressed: () {
                    context.pushScreen(const CategoriesManagementScreen());
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Kategorien bearbeiten'),
                  style: ElevatedButton.styleFrom(
                    padding: AppConstants.paddingAll16,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacing),

        // Info Card
        Card(
          color: Colors.blue[50],
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Hinweis',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingS),
                const Text(
                  'Kategorien helfen Ihnen, Ihre Einnahmen und Ausgaben zu organisieren und auszuwerten. '
                  'Sie können beliebig viele Kategorien erstellen und anpassen.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
