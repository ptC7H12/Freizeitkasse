import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/current_event_provider.dart';
import '../../providers/participant_provider.dart';
import '../../providers/pdf_export_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/participant_excel_provider.dart';
import '../../data/database/app_database.dart';
import '../../utils/date_utils.dart';
import '../../utils/route_helpers.dart';
import 'participant_form_screen.dart';
/// import 'participant_import_screen.dart';
import '../../utils/constants.dart';
import '../../extensions/context_extensions.dart';

/// Participants List Screen
///
/// Zeigt alle Teilnehmer des aktuellen Events mit Suche und Filtern
class ParticipantsListScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const ParticipantsListScreen({super.key, this.embedded = false});

  @override
  ConsumerState<ParticipantsListScreen> createState() => _ParticipantsListScreenState();
}

class _ParticipantsListScreenState extends ConsumerState<ParticipantsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _ageFilter; // 'children', 'youth', 'adults'
  String? _genderFilter;
  String? _paymentFilter; // 'all', 'open', 'paid'
  Map<int, double> _participantPayments = {}; // participantId -> total paid

  @override
  void initState() {
    super.initState();
    _loadParticipantPayments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadParticipantPayments() async {
    final currentEvent = ref.read(currentEventProvider);
    if (currentEvent == null) {
      return;
    }

    final database = ref.read(databaseProvider);
    final payments = await (database.select(database.payments)
          ..where((tbl) => tbl.eventId.equals(currentEvent.id))
          ..where((tbl) => tbl.isActive.equals(true))
          ..where((tbl) => tbl.participantId.isNotNull()))
        .get();

    // Gruppiere Zahlungen nach Teilnehmer
    final paymentMap = <int, double>{};
    for (final payment in payments) {
      if (payment.participantId != null) {
        paymentMap[payment.participantId!] =
          (paymentMap[payment.participantId!] ?? 0) + payment.amount;
      }
    }

    setState(() {
      _participantPayments = paymentMap;
    });
  }

  List<Participant> _filterParticipants(List<Participant> participants) {
    var filtered = participants;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        final fullName = '${p.firstName} ${p.lastName}'.toLowerCase();
        final email = p.email?.toLowerCase() ?? '';
        final city = p.city?.toLowerCase() ?? '';
        return fullName.contains(query) || email.contains(query) || city.contains(query);
      }).toList();
    }

    // Age filter
    if (_ageFilter != null) {
      filtered = filtered.where((p) {
        final age = AppDateUtils.calculateAge(p.birthDate);
        switch (_ageFilter) {
          case 'children':
            return age <= 12;
          case 'youth':
            return age >= 13 && age <= 17;
          case 'adults':
            return age >= 18;
          default:
            return true;
        }
      }).toList();
    }

    // Gender filter
    if (_genderFilter != null && _genderFilter!.isNotEmpty) {
      filtered = filtered.where((p) => p.gender == _genderFilter).toList();
    }

    // Payment status filter
    if (_paymentFilter != null && _paymentFilter != 'all') {
      filtered = filtered.where((p) {
        final totalPrice = _getDisplayPrice(p);
        final totalPaid = _participantPayments[p.id] ?? 0.0;

        switch (_paymentFilter) {
          case 'open':
            return totalPaid < totalPrice; // Noch nicht vollständig bezahlt
          case 'paid':
            return totalPaid >= totalPrice; // Vollständig bezahlt
          default:
            return true;
        }
      }).toList();
    }

    return filtered;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Altersgruppe:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppConstants.spacingS),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Alle'),
                  selected: _ageFilter == null,
                  onSelected: (selected) {
                    setState(() {
                      _ageFilter = null;
                    });
                    RouteHelpers.pop(context);
                  },
                ),
                FilterChip(
                  label: const Text('Kinder (≤12)'),
                  selected: _ageFilter == 'children',
                  onSelected: (selected) {
                    setState(() {
                      _ageFilter = selected ? 'children' : null;
                    });
                    RouteHelpers.pop(context);
                  },
                ),
                FilterChip(
                  label: const Text('Jugendliche (13-17)'),
                  selected: _ageFilter == 'youth',
                  onSelected: (selected) {
                    setState(() {
                      _ageFilter = selected ? 'youth' : null;
                    });
                    RouteHelpers.pop(context);
                  },
                ),
                FilterChip(
                  label: const Text('Erwachsene (≥18)'),
                  selected: _ageFilter == 'adults',
                  onSelected: (selected) {
                    setState(() {
                      _ageFilter = selected ? 'adults' : null;
                    });
                    RouteHelpers.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacing),
            const Text('Geschlecht:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppConstants.spacingS),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Alle'),
                  selected: _genderFilter == null,
                  onSelected: (selected) {
                    setState(() {
                      _genderFilter = null;
                    });
                    RouteHelpers.pop(context);
                  },
                ),
                FilterChip(
                  label: const Text('Männlich'),
                  selected: _genderFilter == 'Männlich',
                  onSelected: (selected) {
                    setState(() {
                      _genderFilter = selected ? 'Männlich' : null;
                    });
                    RouteHelpers.pop(context);
                  },
                ),
                FilterChip(
                  label: const Text('Weiblich'),
                  selected: _genderFilter == 'Weiblich',
                  onSelected: (selected) {
                    setState(() {
                      _genderFilter = selected ? 'Weiblich' : null;
                    });
                    RouteHelpers.pop(context);
                  },
                ),
                FilterChip(
                  label: const Text('Divers'),
                  selected: _genderFilter == 'Divers',
                  onSelected: (selected) {
                    setState(() {
                      _genderFilter = selected ? 'Divers' : null;
                    });
                    RouteHelpers.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacing),
            const Text('Zahlungsstatus:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppConstants.spacingS),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Alle'),
                  selected: _paymentFilter == null || _paymentFilter == 'all',
                  onSelected: (selected) {
                    setState(() {
                      _paymentFilter = null;
                    });
                    RouteHelpers.pop(context);
                  },
                ),
                FilterChip(
                  label: const Text('Offene Zahlungen'),
                  selected: _paymentFilter == 'open',
                  onSelected: (selected) {
                    setState(() {
                      _paymentFilter = selected ? 'open' : null;
                    });
                    RouteHelpers.pop(context);
                  },
                ),
                FilterChip(
                  label: const Text('Beglichene Zahlungen'),
                  selected: _paymentFilter == 'paid',
                  onSelected: (selected) {
                    setState(() {
                      _paymentFilter = selected ? 'paid' : null;
                    });
                    RouteHelpers.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _ageFilter = null;
                _genderFilter = null;
                _paymentFilter = null;
              });
              RouteHelpers.pop(context);
            },
            child: const Text('Zurücksetzen'),
          ),
          TextButton(
            onPressed: () => RouteHelpers.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  /// Excel Export
  Future<void> _exportToExcel(List<Participant> participants) async {
    try {
      final currentEvent = ref.read(currentEventProvider);
      if (currentEvent == null) return;

      final excelService = ref.read(participantExcelServiceProvider);
      final file = await excelService.exportParticipants(
        participants: participants,
        eventName: currentEvent.name,
      );

      if (mounted) {
        context.showSuccess('Excel exportiert: ${file.path}');
      }
    } catch (e) {
      if (mounted) {
        context.showError('Fehler beim Exportieren: $e');
      }
    }
  }

  /// Excel Import
  Future<void> _importFromExcel() async {
    try {
      final currentEvent = ref.read(currentEventProvider);
      if (currentEvent == null) {
        if (mounted) {
          context.showError('Kein Event ausgewählt');
        }
        return;
      }

      final excelService = ref.read(participantExcelServiceProvider);
      final result = await excelService.importParticipants(
        eventId: currentEvent.id,
      );

      if (mounted) {
        if (result.success) {
          context.showSuccess(result.message);

          // Zeige Fehler-Details falls vorhanden
          if (result.errors.isNotEmpty) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Import-Fehler'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: result.errors.map((e) => Text('• $e')).toList(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        } else {
          context.showError(result.message);
        }
      }
    } catch (e) {
      if (mounted) {
        context.showError('Fehler beim Importieren: $e');
      }
    }
  }

  /// Download Import Template
  Future<void> _downloadTemplate() async {
    try {
      final excelService = ref.read(participantExcelServiceProvider);
      final file = await excelService.createImportTemplate();

      if (mounted) {
        context.showSuccess('Vorlage erstellt: ${file.path}');
      }
    } catch (e) {
      if (mounted) {
        context.showError('Fehler beim Erstellen der Vorlage: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final participantsAsync = ref.watch(participantsProvider);

    // Wenn embedded mode, nur den Content ohne Scaffold zurückgeben
    if (widget.embedded) {
      return _buildContent(participantsAsync);
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Teilnehmer'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: (_ageFilter != null || _genderFilter != null) ? Colors.orange : null,
            ),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _importFromExcel,
            tooltip: 'Excel importieren',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              final participantsValue = ref.read(participantsProvider).value;
              if (participantsValue != null && participantsValue.isNotEmpty) {
                _exportToExcel(participantsValue);
              } else {
                context.showError('Keine Teilnehmer zum Exportieren');
              }
            },
            tooltip: 'Excel exportieren',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final participantsValue = ref.read(participantsProvider).value;
              final currentEvent = ref.read(currentEventProvider);

              if (participantsValue == null || participantsValue.isEmpty) {
                context.showError('Keine Teilnehmer zum Exportieren');
                return;
              }

              final pdfService = ref.read(pdfExportServiceProvider);
              try {
                final filePath = await pdfService.exportParticipantsList(
                  participants: participantsValue,
                  eventName: currentEvent?.name ?? 'Veranstaltung',
                );
                if (context.mounted) {
                  context.showSuccess('PDF gespeichert: $filePath');
                }
              } catch (e) {
                if (context.mounted) {
                  context.showError('Fehler beim PDF-Export: $e');
                }
              }
            },
            tooltip: 'PDF exportieren',
          ),
        ],
      ),
      body: _buildContent(participantsAsync),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ParticipantFormScreen(),
            ),
          );
        },
        tooltip: 'Teilnehmer hinzufügen',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent(AsyncValue<List<Participant>> participantsAsync) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: AppConstants.paddingAll16,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Suche nach Name, E-Mail oder Stadt...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),

        // Filter chips
        if (_ageFilter != null || _genderFilter != null || _paymentFilter != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                if (_ageFilter != null)
                  Chip(
                    label: Text(_getAgeFilterLabel(_ageFilter!)),
                    onDeleted: () {
                      setState(() {
                        _ageFilter = null;
                      });
                    },
                  ),
                if (_genderFilter != null)
                  Chip(
                    label: Text(_genderFilter!),
                    onDeleted: () {
                      setState(() {
                        _genderFilter = null;
                      });
                    },
                  ),
                if (_paymentFilter != null)
                  Chip(
                    label: Text(_getPaymentFilterLabel(_paymentFilter!)),
                    onDeleted: () {
                      setState(() {
                        _paymentFilter = null;
                      });
                    },
                  ),
              ],
            ),
          ),

        // Participants List
        Expanded(
          child: participantsAsync.when(
            data: (participants) {
              if (participants.isEmpty) {
                return _buildEmptyState(context);
              }

              final filteredParticipants = _filterParticipants(participants);

              if (filteredParticipants.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, size: 80, color: Colors.grey),
                      const SizedBox(height: AppConstants.spacing),
                      const Text(
                        'Keine Ergebnisse gefunden',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppConstants.spacingS),
                      const Text('Versuchen Sie eine andere Suche oder Filter'),
                      const SizedBox(height: AppConstants.spacing),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                            _ageFilter = null;
                            _genderFilter = null;
                          });
                        },
                        child: const Text('Filter zurücksetzen'),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      '${filteredParticipants.length} von ${participants.length} Teilnehmern',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: AppConstants.paddingAll16,
                      itemCount: filteredParticipants.length,
                      itemBuilder: (context, index) {
                        final participant = filteredParticipants[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                participant.firstName[0].toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              '${participant.firstName} ${participant.lastName}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Geb.: ${AppDateUtils.formatGerman(participant.birthDate)} (${AppDateUtils.calculateAge(participant.birthDate)} Jahre)',
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Preis: ${_getDisplayPrice(participant).toStringAsFixed(2)} €',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ParticipantFormScreen(
                                    participantId: participant.id,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('Fehler: $error'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 100,
            color: Colors.grey,
          ),
          SizedBox(height: 24),
          Text(
            'Noch keine Teilnehmer',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Füge deinen ersten Teilnehmer hinzu.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _getAgeFilterLabel(String filter) {
    switch (filter) {
      case 'children':
        return 'Kinder (≤12)';
      case 'youth':
        return 'Jugendliche (13-17)';
      case 'adults':
        return 'Erwachsene (≥18)';
      default:
        return filter;
    }
  }

  String _getPaymentFilterLabel(String filter) {
    switch (filter) {
      case 'open':
        return 'Offene Zahlungen';
      case 'paid':
        return 'Beglichene Zahlungen';
      default:
        return filter;
    }
  }

  double _getDisplayPrice(Participant participant) {
    return participant.manualPriceOverride ?? participant.calculatedPrice;
  }
}
