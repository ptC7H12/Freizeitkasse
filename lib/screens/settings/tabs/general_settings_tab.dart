import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/constants.dart';
import '../../../utils/logger.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/current_event_provider.dart';
import '../../../extensions/context_extensions.dart';

/// Tab 1: Allgemeine Einstellungen
///
/// Organisation, Bankdaten, Verwendungszweck prefix, Fußzeile
class GeneralSettingsTab extends ConsumerStatefulWidget {
  const GeneralSettingsTab({super.key});

  @override
  ConsumerState<GeneralSettingsTab> createState() => _GeneralSettingsTabState();
}

class _GeneralSettingsTabState extends ConsumerState<GeneralSettingsTab> {
  // Form Controllers
  final _organizationController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _ibanController = TextEditingController();
  final _bicController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _subjectController = TextEditingController();
  final _footerController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _organizationController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _ibanController.dispose();
    _bicController.dispose();
    _accountHolderController.dispose();
    _subjectController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final currentEvent = ref.read(currentEventProvider);
    if (currentEvent == null) {
      return;
    }

    final repository = ref.read(settingsRepositoryProvider);
    final settings = await repository.getOrCreateSettings(currentEvent.id);

    if (mounted) {
      setState(() {
        _organizationController.text = settings.organizationName ?? '';
        _addressController.text = settings.organizationAddress ?? '';
        _contactController.text = settings.contactInfo ?? '';
        _ibanController.text = settings.iban ?? '';
        _bicController.text = settings.bic ?? '';
        _accountHolderController.text = settings.bankName ?? '';
        _subjectController.text = settings.verwendungszweckPrefix ?? '';
        _footerController.text = settings.invoiceFooter ?? '';
      });
    }
  }

  Future<void> _saveSettings() async {
    final currentEvent = ref.read(currentEventProvider);
    if (currentEvent == null) {
      if (mounted) {
        context.showError('Kein Event ausgewählt');
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(settingsRepositoryProvider);
      await repository.updateSettings(
        eventId: currentEvent.id,
        organizationName: _organizationController.text.trim().isEmpty
            ? null
            : _organizationController.text.trim(),
        organizationAddress: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        contactInfo: _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
        iban: _ibanController.text.trim().isEmpty
            ? null
            : _ibanController.text.trim(),
        bic: _bicController.text.trim().isEmpty
            ? null
            : _bicController.text.trim(),
        bankName: _accountHolderController.text.trim().isEmpty
            ? null
            : _accountHolderController.text.trim(),
        verwendungszweckPrefix: _subjectController.text.trim().isEmpty
            ? null
            : _subjectController.text.trim(),
        invoiceFooter: _footerController.text.trim().isEmpty
            ? null
            : _footerController.text.trim(),
      );

      if (mounted) {
        context.showSuccess('Einstellungen erfolgreich gespeichert');
      }
    } catch (e, stack) {
      AppLogger.error('Fehler beim Speichern der allgemeinen Einstellungen', error: e, stackTrace: stack);
      if (mounted) {
        context.showError('Fehler beim Speichern: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppConstants.paddingAll16,
      children: [
        // Organisation Card
        Card(
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.business, color: Color(0xFF2196F3)),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Organisation',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing),
                TextFormField(
                  controller: _organizationController,
                  decoration: const InputDecoration(
                    labelText: 'Organisationsname',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: AppConstants.spacingS),
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                    labelText: 'Kontaktdaten (E-Mail, Telefon)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.contact_mail),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacing),

        // Bankdaten Card
        Card(
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Color(0xFF4CAF50)),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Bankdaten',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing),
                TextFormField(
                  controller: _ibanController,
                  decoration: const InputDecoration(
                    labelText: 'IBAN',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),
                TextFormField(
                  controller: _bicController,
                  decoration: const InputDecoration(
                    labelText: 'BIC',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),
                TextFormField(
                  controller: _accountHolderController,
                  decoration: const InputDecoration(
                    labelText: 'Kontoinhaber',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Verwendungszweck prefix',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.subject),
                    hintText: 'z.B. Sommerfreizeit 2024',
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacing),

        // Sonstiges Card
        Card(
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description, color: Color(0xFFFF9800)),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Sonstiges',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing),
                TextFormField(
                  controller: _footerController,
                  decoration: const InputDecoration(
                    labelText: 'Fußzeile',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.text_fields),
                    hintText: 'z.B. Mit freundlichen Grüßen...',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacing),

        // Speichern Button
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _saveSettings,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(_isLoading ? 'Wird gespeichert...' : 'Speichern'),
          style: ElevatedButton.styleFrom(
            padding: AppConstants.paddingAll16,
          ),
        ),
      ],
    );
  }
}
