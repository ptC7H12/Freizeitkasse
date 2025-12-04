# Freizeitkasse - AI Assistant Guide (OPTIMIZED)

## 🤖 AI Assistant Context

You are assisting with the Freizeitkasse Flutter app development.

**Your primary goals:**
1. Follow the CRITICAL RULES (15 mandatory rules) without exception
2. Use established patterns (Repository, Form, List screens)
3. Maintain code quality (AppLogger, AppConstants, Extensions)
4. Ensure responsive design (desktop + mobile)

**When uncertain:**
- Check Quick Reference tables first
- Ask for clarification rather than guessing
- Log decisions with AppLogger



## ⚠️ CRITICAL RULES (ALWAYS ENFORCE)

### Code Quality - MANDATORY
1. **Logging**: `AppLogger.debug/info/error()` - NEVER `print()` or `developer.log()`
2. **Constants**: `AppConstants.spacing/colors/padding` - NEVER hardcoded values
3. **UI Feedback**: `context.showSuccess/Error()` - NEVER direct ScaffoldMessenger
4. **Navigation**: `context.pushScreen()` or `RouteHelpers.push()` - AVOID direct Navigator
5. **Exceptions**: Specific types (`ValidationException`, `NotFoundException`) - NEVER generic `Exception`
6. **Responsive**: Wrap ALL forms with `ResponsiveFormContainer`
7. **Context Safety**: ALWAYS check `context.mounted` after async before UI operations
8. **Error Logging**: ALWAYS `AppLogger.error()` before showing user feedback

### Business Logic - MANDATORY
9. **Event Context**: Most operations require `currentEventProvider`
10. **Auto-Calculation**: Price calculated automatically - DON'T set `calculated_price` manually
11. **Soft Delete**: Use `is_active=false` instead of hard delete
12. **Build Runner**: Run `dart run build_runner build` after DB schema changes

### UI/UX - MANDATORY
13. **Responsive Design**: Test BOTH desktop (>800px) AND mobile (≤800px)
14. **Button Consistency**: Use SAME button patterns across platforms (Extended FAB everywhere)
15. **German UI**: All user-facing strings in German

---

## 🏗️ Architecture Quick Reference

### Stack
- **Framework**: Flutter 3.x + Dart
- **Database**: SQLite + Drift ORM (type-safe)
- **State**: Riverpod (StreamProvider for reactive data)
- **UI**: Material Design 3

### Layer Pattern
```
UI (Screens/Widgets) 
  ↓ 
State (Riverpod Providers) 
  ↓
Business Logic (Services/Repositories) 
  ↓ 
Data (Drift Database)
```

### Key Directories
```
lib/
├── data/
│   ├── database/app_database.dart          # 12 tables
│   └── repositories/_repository.dart      # CRUD + business logic
├── providers/_provider.dart               # Riverpod state
├── screens/                                # UI organized by feature
├── widgets/                                # Reusable components
├── services/                               # Business logic (price calc, PDF, Excel)
├── utils/                                  # Helpers (logger, constants, ui_helpers, etc.)
└── extensions/                             # Context, String, DateTime extensions
```

---

## 📊 Database Schema (12 Tables)

| Table | Key Fields | Notes |
|-------|-----------|-------|
| **Events** | name, start_date, end_date | One active per session |
| **Participants** | event_id, family_id, role_id, birth_date, calculated_price | Main entity, auto-price-calc |
| **Families** | event_id, family_name | For family discounts |
| **Payments** | event_id, participant_id OR family_id, amount | Linked to participant OR family |
| **Expenses** | event_id, category, amount | Dynamic categories via ExpenseCategories |
| **ExpenseCategories** | event_id, name, is_system | User-editable via Settings |
| **Incomes** | event_id, source, amount | Dynamic sources via IncomeSources |
| **IncomeSources** | event_id, name, is_system | User-editable via Settings |
| **Rulesets** | event_id, yaml_content, valid_from | YAML pricing rules |
| **Roles** | event_id, name | For role-based discounts |
| **Tasks** | event_id, title, status, priority | Task management |
| **Settings** | key, value | App-wide config |

**Conventions:**
- Soft delete: `is_active` boolean
- Foreign keys: `{entity}_id`
- Timestamps: `created_at`, `updated_at` (auto)

---

## 💰 Price Calculation Logic

**File**: `lib/services/price_calculator_service.dart`

**Algorithm** (NON-STACKING discounts):
1. Get base price from age group in active ruleset
2. Calculate role discount (from base)
3. Calculate family discount (from base)
4. Apply both discounts independently (NOT cumulative)

**Triggered by**: Participant create/update in `participant_repository.dart`

**Ruleset YAML Structure**:
```yaml
age_groups:
  - name: "Kinder"
    min_age: 0
    max_age: 12
    base_price: 150.00

role_discounts:
  - role_name: "Mitarbeiter"
    discount_percent: 50.0

family_discount:
  min_children: 2
  discount_percent_per_child:
    - children_count: 2
      discount_percent: 10.0
```

---

## 🎨 Code Quality Utilities

### AppLogger (`lib/utils/logger.dart`)
```dart
AppLogger.debug('Message', data);
AppLogger.info('Important event');
AppLogger.warning('Issue detected', context);
AppLogger.error('Failed', error: e, stackTrace: stack);
```

### AppConstants (`lib/utils/constants.dart`)
```dart
// Spacing
AppConstants.spacing        // 16.0
AppConstants.spacingS       // 8.0
AppConstants.spacingL       // 24.0

// Padding
AppConstants.paddingAll16
AppConstants.paddingHorizontal

// Colors
AppConstants.primaryColor
AppConstants.successColor

// Responsive
AppConstants.maxFormWidth   // 800.0
```

### Context Extensions (`lib/extensions/context_extensions.dart`)
```dart
// Theme
context.theme / .textTheme / .colorScheme

// Screen
context.screenWidth / .isMobile / .isDesktop

// Navigation
context.pushScreen(Screen())
context.popScreen(result)

// Feedback
context.showSuccess('Message')
context.showError('Error')
context.showConfirm(title: 'Title', message: 'Msg')
```

### UIHelpers (`lib/utils/ui_helpers.dart`)
```dart
UIHelpers.showSuccessSnackbar(context, 'Success');
UIHelpers.showDeleteConfirmDialog(context, itemName: 'John');
UIHelpers.isMobile(context);
```

### String Extensions (`lib/extensions/string_extensions.dart`)
```dart
text.isBlank / .isNotBlank
text.isValidEmail / .isValidIBAN
text.capitalize / .toTitleCase
text.formatIban
```

### DateTime Extensions (`lib/extensions/date_time_extensions.dart`)
```dart
date.toGermanDate          // 01.01.2025
date.isToday / .isThisWeek
date.age                   // Years
date.addDays(7)
```

### Custom Exceptions (`lib/utils/exceptions.dart`)
```dart
AppException
├── DatabaseException
│   ├── NotFoundException
│   └── ConstraintViolationException
├── ValidationException
├── BusinessRuleException
│   ├── PriceCalculationException
│   └── RulesetParseException
└── ImportExportException

// Usage
throw NotFoundException('Participant', id);
throw ValidationException('Invalid email');
```

---

## 🔄 Standard Patterns

### Repository Pattern
```dart
class XxxRepository {
  // Reactive
  Stream<List<Xxx>> watchXxxByEvent(int eventId)
  
  // Fetch
  Future<Xxx?> getXxxById(int id)
  Future<List<Xxx>> getXxxByEvent(int eventId)
  
  // CRUD
  Future<int> createXxx({required params})
  Future<bool> updateXxx({required int id, ...})
  Future<bool> deleteXxx(int id)  // Soft delete
  
  // Stats
  Future<Map<String, dynamic>> getStatistics(int eventId)
}
```

### Form Screen Pattern
```dart
class XxxFormScreen extends ConsumerStatefulWidget {
  final int? xxxId; // null=create, value=edit
  
  @override
  ConsumerState<XxxFormScreen> createState() => _XxxFormScreenState();
}

class _XxxFormScreenState extends ConsumerState<XxxFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  @override
  void initState() {
    super.initState();
    if (widget.xxxId != null) _loadXxx();
  }
  
  Future<void> _saveXxx() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      final repo = ref.read(xxxRepositoryProvider);
      widget.xxxId == null 
        ? await repo.createXxx(...)
        : await repo.updateXxx(id: widget.xxxId!, ...);
      
      if (context.mounted) {
        context.showSuccess('Gespeichert');
        RouteHelpers.pop(context);
      }
    } on ValidationException catch (e) {
      if (context.mounted) context.showError(e.message);
    } on DatabaseException catch (e) {
      AppLogger.error('Save failed', error: e);
      if (context.mounted) context.showError('Datenbankfehler');
    } catch (e, stack) {
      AppLogger.error('Unexpected error', error: e, stackTrace: stack);
      if (context.mounted) context.showError('Fehler aufgetreten');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.xxxId == null ? 'Neu' : 'Bearbeiten')),
      body: ResponsiveFormContainer(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: AppConstants.paddingAll16,
            children: [
              TextFormField(...),
              SizedBox(height: AppConstants.spacing),
              FilledButton(onPressed: _saveXxx, child: Text('Speichern')),
            ],
          ),
        ),
      ),
    );
  }
}
```

### List Screen Pattern
```dart
class XxxListScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<XxxListScreen> createState() => _XxxListScreenState();
}

class _XxxListScreenState extends ConsumerState<XxxListScreen> {
  String _searchQuery = '';
  
  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(xxxProvider);
    
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(icon: Icon(Icons.add), onPressed: () => context.pushScreen(XxxFormScreen())),
        ],
      ),
      body: Column([
        SearchBar(...),
        Expanded(
          child: itemsAsync.when(
            data: (items) => ListView.builder(...),
            loading: () => CircularProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),
        ),
      ]),
    );
  }
}
```

### Error Handling Pattern
```dart
// Repository Level
Future<int> createXxx({required String name}) async {
  try {
    if (name.trim().isEmpty) {
      throw InvalidInputException('name', 'Name erforderlich');
    }
    
    final id = await _database.into(_database.xxxs).insert(...);
    AppLogger.info('Created xxx', id);
    return id;
  } on AppException {
    rethrow;
  } catch (e, stack) {
    AppLogger.error('Create failed', error: e, stackTrace: stack);
    throw DatabaseException('Datenbankfehler', originalError: e);
  }
}

// UI Level - see Form Screen Pattern above
```

---

## 🗺️ Navigation Structure

### Menu Groups
**📊 VERWALTUNG**
- Dashboard
- Teilnehmer & Familien (Tabs)
- Aufgaben

**💰 FINANZEN**
- ZahlungseingÃ¤nge
- Sonstige Einnahmen
- Ausgaben
- Kassenstand

**⚙️ EINSTELLUNGEN**
- Einstellungen (Tabs: Allgemein | Regelwerk | Kategorien | App-Info)

### Desktop vs Mobile
- **Desktop (>800px)**: Blue sidebar (280px) always visible
- **Mobile (≤800px)**: Drawer (swipe-in)
- **Both**: Use same `_buildDrawer()` method

---

## 🎯 Common Tasks

### Add Field to Participant
1. Update `Participants` table in `app_database.dart`
2. Run `dart run build_runner build`
3. Update `createParticipant`/`updateParticipant` in `participant_repository.dart`
4. Add field to `participant_form_screen.dart`
5. Update list screen if needed

### Create New CRUD Entity
1. Add table to `app_database.dart` ’ run build_runner
2. Create `{entity}_repository.dart` with standard methods
3. Create `{entity}_provider.dart` with StreamProvider
4. Create `{entity}_list_screen.dart` and `{entity}_form_screen.dart`
5. Add to navigation in `dashboard_screen.dart`

### Manage Categories/Sources
**Location**: Settings ’ Categories Management
- Create/edit/delete custom categories
- Drag-to-reorder
- System categories (is_system=true) protected
- Separate tabs for Expenses/Incomes

### Add Utility Helper
1. **Static methods**: Add to `lib/utils/{purpose}_helper.dart`
2. **Extensions**: Add to `lib/extensions/{type}_extensions.dart`
3. Document in this README
4. Use throughout codebase

---

##  Quick Reference

### File Lookup
| Need | File |
|------|------|
| Price calculation | `lib/services/price_calculator_service.dart` |
| Participant form | `lib/screens/participants/participant_form_screen.dart` |
| Database schema | `lib/data/database/app_database.dart` |
| Financial stats | `lib/data/repositories/expense_repository.dart` |
| PDF export | `lib/services/pdf_export_service.dart` |
| Excel import | `lib/services/excel_import_service.dart` |
| YAML ruleset | `lib/services/ruleset_parser_service.dart` |
| Add constant | `lib/utils/constants.dart` |
| Add logging | Import `lib/utils/logger.dart` |
| Manage categories | `lib/screens/settings/categories_management_screen.dart` |

### German Terminology
| German | English |
|--------|---------|
| Teilnehmer | Participant |
| Familie | Family |
| Zahlung | Payment |
| Ausgabe | Expense |
| Einnahme | Income |
| Regelwerk | Ruleset |
| Rolle | Role |
| Aufgabe | Task |
| Kassenstand | Cash balance |

### Common Mistakes - DON'T vs DO
| DON'T |  DO |
|----------|-------|
| `EdgeInsets.all(16)` | `AppConstants.paddingAll16` |
| `SizedBox(height: 16)` | `SizedBox(height: AppConstants.spacing)` |
| `Color(0xFF2196F3)` | `AppConstants.primaryColor` |
| `ScaffoldMessenger.of(context).showSnackBar(...)` | `context.showSuccess()` |
| `Navigator.push(...)` | `context.pushScreen()` |
| `print('debug')` | `AppLogger.debug('debug')` |
| `throw Exception('error')` | `throw ValidationException('error')` |
| Form without wrapper | Wrap with `ResponsiveFormContainer` |

---

## Responsive Design Checklist

Before committing UI changes:
- [ ] Desktop view tested (>800px)
- [ ] Mobile view tested (‰¤800px)
- [ ] Buttons use same pattern (Extended FAB everywhere)
- [ ] Navigation consistent in both views
- [ ] Forms use `ResponsiveFormContainer`
- [ ] Lists use adaptive patterns

### Layout Breakpoint
```dart
final isDesktop = MediaQuery.of(context).size.width >= 800;
```

---

## Development

### Run App
```bash
flutter pub get
dart run build_runner build
flutter run -d windows  # or macos, ios
```

### Database Location
- **Windows**: `%APPDATA%\com.example\mgbfreizeitplaner\databases\`
- **macOS**: `~/Library/Application Support/com.example.mgbfreizeitplaner/databases/`

### Reset Database
Delete database file and restart app.

---

## State Management (Riverpod)

### Provider Types
```dart
// Singleton
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

// Mutable state
final currentEventProvider = StateNotifierProvider<CurrentEventNotifier, Event?>(...)

// Reactive data
final participantsProvider = StreamProvider<List<Participant>>((ref) {
  return repository.watchParticipantsByEvent(eventId);
});

// Async fetch
final totalExpensesProvider = FutureProvider<double>((ref) async {...});
```

### Usage Pattern
```dart
final dataAsync = ref.watch(xxxProvider);

dataAsync.when(
  data: (data) => /* Build UI */,
  loading: () => CircularProgressIndicator(),
  error: (error, stack) => Text('Error: $error'),
);
```

---

## Key Concepts

### Reactive Updates
All list screens use `StreamProvider` ’ automatic UI updates when DB changes. No manual refresh needed.

### Price Recalculation
Auto-triggered on:
- Participant create/update
- Family assignment change
- Role assignment change
- Manual price override

NOT triggered on ruleset/family member count changes (requires manual migration).

### Soft Delete
Most entities use `is_active` flag instead of hard delete. Allows data recovery.

### Categories Management
Expense/Income categories are user-editable via Settings. System categories (is_system=true) cannot be deleted.

---

**END OF OPTIMIZED DOCUMENTATION**
