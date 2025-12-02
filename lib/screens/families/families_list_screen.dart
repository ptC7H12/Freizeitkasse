import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import '../../providers/family_provider.dart';
import '../../providers/current_event_provider.dart';
import '../../providers/database_provider.dart';
import '../../data/database/app_database.dart' as db;
import '../../utils/constants.dart';
import 'family_form_screen.dart';
import '../../widgets/responsive_scaffold.dart';

/// Families List Screen
class FamiliesListScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const FamiliesListScreen({super.key, this.embedded = false});

  @override
  ConsumerState<FamiliesListScreen> createState() => _FamiliesListScreenState();
}

class _FamiliesListScreenState extends ConsumerState<FamiliesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _paymentFilter; // 'all', 'open', 'paid'
  Map<int, double> _familyPayments = {}; // familyId -> total paid
  Map<int, double> _familyExpectedPrices = {}; // familyId -> expected total

  @override
  void initState() {
    super.initState();
    _loadFamilyPayments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFamilyPayments() async {
    final currentEvent = ref.read(currentEventProvider);
    if (currentEvent == null) {
      return;
    }

    final database = ref.read(databaseProvider);

    // Lade alle Zahlungen für Familien
    final payments = await (database.select(database.payments)
          ..where((tbl) => tbl.eventId.equals(currentEvent.id))
          ..where((tbl) => tbl.isActive.equals(true))
          ..where((tbl) => tbl.familyId.isNotNull()))
        .get();

    // Gruppiere Zahlungen nach Familie
    final paymentMap = <int, double>{};
    for (final payment in payments) {
      if (payment.familyId != null) {
        paymentMap[payment.familyId!] =
          (paymentMap[payment.familyId!] ?? 0) + payment.amount;
      }
    }

    // Lade alle Teilnehmer und berechne erwartete Preise pro Familie
    final participants = await (database.select(database.participants)
          ..where((tbl) => tbl.eventId.equals(currentEvent.id))
          ..where((tbl) => tbl.isActive.equals(true))
          ..where((tbl) => tbl.familyId.isNotNull()))
        .get();

    final expectedPriceMap = <int, double>{};
    for (final participant in participants) {
      if (participant.familyId != null) {
        final price = participant.manualPriceOverride ?? participant.calculatedPrice;
        expectedPriceMap[participant.familyId!] =
          (expectedPriceMap[participant.familyId!] ?? 0) + price;
      }
    }

    setState(() {
      _familyPayments = paymentMap;
      _familyExpectedPrices = expectedPriceMap;
    });
  }

  List<db.Family> _filterFamilies(List<db.Family> families) {
    var filtered = families;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((f) {
        final familyName = f.familyName.toLowerCase();
        final contactPerson = (f.contactPerson ?? '').toLowerCase();
        final email = (f.email ?? '').toLowerCase();
        final city = (f.city ?? '').toLowerCase();
        return familyName.contains(query) ||
            contactPerson.contains(query) ||
            email.contains(query) ||
            city.contains(query);
      }).toList();
    }

    // Payment status filter
    if (_paymentFilter != null && _paymentFilter != 'all') {
      filtered = filtered.where((f) {
        final expectedPrice = _familyExpectedPrices[f.id] ?? 0.0;
        final totalPaid = _familyPayments[f.id] ?? 0.0;

        switch (_paymentFilter) {
          case 'open':
            return totalPaid < expectedPrice; // Noch nicht vollständig bezahlt
          case 'paid':
            return totalPaid >= expectedPrice; // Vollständig bezahlt
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
                    Navigator.pop(context);
                  },
                ),
                FilterChip(
                  label: const Text('Offene Zahlungen'),
                  selected: _paymentFilter == 'open',
                  onSelected: (selected) {
                    setState(() {
                      _paymentFilter = selected ? 'open' : null;
                    });
                    Navigator.pop(context);
                  },
                ),
                FilterChip(
                  label: const Text('Beglichene Zahlungen'),
                  selected: _paymentFilter == 'paid',
                  onSelected: (selected) {
                    setState(() {
                      _paymentFilter = selected ? 'paid' : null;
                    });
                    Navigator.pop(context);
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
                _paymentFilter = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Zurücksetzen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final familiesAsync = ref.watch(familiesProvider);

    // Wenn embedded mode, nur den Content ohne Scaffold zurückgeben
    if (widget.embedded) {
      return _buildContent(familiesAsync);
    }

    return ResponsiveScaffold(
      title: 'Familien',
      selectedIndex: 2,
      actions: [
        IconButton(
          icon: Icon(
            Icons.filter_list,
            color: _paymentFilter != null ? Colors.orange : null,
          ),
          onPressed: _showFilterDialog,
          tooltip: 'Filter',
        ),
      ],
      body: _buildContent(familiesAsync),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const FamilyFormScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Familie'),
      ),
    );
  }

  Widget _buildContent(AsyncValue<List<db.Family>> familiesAsync) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: AppConstants.paddingAll16,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Suche nach Familienname, Kontaktperson, E-Mail...',
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
        if (_paymentFilter != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
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

        // Families List
        Expanded(
          child: familiesAsync.when(
            data: (families) {
              if (families.isEmpty) {
                return _buildEmptyState();
              }

              final filteredFamilies = _filterFamilies(families);

              if (filteredFamilies.isEmpty) {
                return _buildNoResultsState();
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      '${filteredFamilies.length} von ${families.length} Familien',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: AppConstants.paddingAll16,
                      itemCount: filteredFamilies.length,
                      itemBuilder: (context, index) {
                        final family = filteredFamilies[index];
                        final expectedPrice = _familyExpectedPrices[family.id] ?? 0.0;
                        final totalPaid = _familyPayments[family.id] ?? 0.0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.family_restroom),
                            ),
                            title: Text(
                              family.familyName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (family.contactPerson != null)
                                  Text('Kontakt: ${family.contactPerson}'),
                                const SizedBox(height: 4),
                                Text(
                                  'Erwartet: ${expectedPrice.toStringAsFixed(2)} € | '
                                  'Bezahlt: ${totalPaid.toStringAsFixed(2)} €',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: totalPaid >= expectedPrice ? Colors.green : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => FamilyFormScreen(
                                    familyId: family.id,
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
            error: (error, stack) => Center(child: Text('Fehler: $error')),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.family_restroom, size: 100, color: Colors.grey),
          SizedBox(height: 24),
          Text(
            'Noch keine Familien',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Füge deine erste Familie hinzu.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
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
                _paymentFilter = null;
              });
            },
            child: const Text('Filter zurücksetzen'),
          ),
        ],
      ),
    );
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
}
