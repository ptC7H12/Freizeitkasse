# MGBFreizeitplaner - Technical Documentation for AI Assistants

## Project Overview

**MGBFreizeitplaner** is a comprehensive event management application for youth camps and retreats, built with Flutter for cross-platform deployment (iOS, macOS, Windows). It manages participants, families, payments, expenses, incomes, tasks, roles, and pricing rulesets.

**Original Stack:** Python/FastAPI + Jinja2 + HTMX + SQLite (web app)
**Current Stack:** Flutter + Dart + Drift ORM + Riverpod + SQLite (standalone desktop/mobile app)

**Key Domain:** German youth camp financial management with complex pricing rules based on age groups, family discounts, and role-based discounts.

---

## Architecture Overview

### Technology Stack

- **Framework:** Flutter 3.x
- **Language:** Dart
- **Database:** SQLite with Drift ORM (type-safe SQL)
- **State Management:** Riverpod (Provider pattern)
- **UI Framework:** Material Design 3
- **Charts:** fl_chart for financial visualizations
- **PDF Generation:** pdf package
- **Excel:** excel package for import/export
- **Logging:** logger package for structured logging
- **Localization:** German (de_DE)

### Architecture Pattern

```
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                             │
│              (Screens + Widgets)                             │
│         lib/screens/* + lib/widgets/*                        │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    State Management                          │
│                  (Riverpod Providers)                        │
│                   lib/providers/*                            │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                   Business Logic                             │
│          (Services + Repositories)                           │
│      lib/services/* + lib/data/repositories/*                │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    Data Layer                                │
│              (Drift Database + Models)                       │
│                lib/data/database/*                           │
└─────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
flutter_app/
├── lib/
│   ├── data/
│   │   ├── database/
│   │   │   └── app_database.dart          # Main database definition (12 tables)
│   │   └── repositories/
│   │       ├── participant_repository.dart # Participant CRUD + price calculation
│   │       ├── family_repository.dart      # Family CRUD
│   │       ├── payment_repository.dart     # Payment CRUD
│   │       ├── expense_repository.dart     # Expense CRUD + category stats
│   │       ├── income_repository.dart      # Income CRUD + source stats
│   │       ├── category_repository.dart    # Expense/Income category management
│   │       ├── ruleset_repository.dart     # Ruleset CRUD + YAML validation
│   │       ├── role_repository.dart        # Role CRUD + usage tracking
│   │       └── task_repository.dart        # Task CRUD + status tracking
│   │
│   ├── providers/
│   │   ├── database_provider.dart          # Database singleton
│   │   ├── current_event_provider.dart     # Current selected event state
│   │   ├── participant_provider.dart       # Participant state + streams
│   │   ├── family_provider.dart            # Family state
│   │   ├── payment_provider.dart           # Payment state
│   │   ├── expense_provider.dart           # Expense state + statistics
│   │   ├── income_provider.dart            # Income state + statistics
│   │   ├── category_provider.dart          # Expense/Income category providers
│   │   ├── ruleset_provider.dart           # Ruleset state
│   │   ├── role_provider.dart              # Role state + counts
│   │   ├── task_provider.dart              # Task state + filters
│   │   ├── excel_import_provider.dart      # Excel import service
│   │   └── pdf_export_provider.dart        # PDF export service
│   │
│   ├── screens/
│   │   ├── auth/
│   │   │   └── event_selection_screen.dart # Event selection (replaces login)
│   │   ├── dashboard/
│   │   │   └── dashboard_screen.dart       # Main overview with statistics
│   │   ├── participants/
│   │   │   ├── participants_list_screen.dart   # List with search/filters
│   │   │   ├── participant_form_screen.dart    # Create/Edit form (700+ lines)
│   │   │   └── participant_import_screen.dart  # Excel import UI
│   │   ├── families/
│   │   │   ├── families_list_screen.dart       # Family list
│   │   │   └── family_form_screen.dart         # Family create/edit
│   │   ├── payments/
│   │   │   ├── payments_list_screen.dart       # Payment list
│   │   │   └── payment_form_screen.dart        # Payment create/edit
│   │   ├── expenses/
│   │   │   ├── expenses_list_screen.dart       # Expense list with categories
│   │   │   └── expense_form_screen.dart        # Expense create/edit
│   │   ├── incomes/
│   │   │   ├── incomes_list_screen.dart        # Income list with sources
│   │   │   └── income_form_screen.dart         # Income create/edit
│   │   ├── rulesets/
│   │   │   ├── rulesets_list_screen.dart       # Ruleset list with active indicator
│   │   │   └── ruleset_form_screen.dart        # YAML editor with validation
│   │   ├── roles/
│   │   │   ├── roles_list_screen.dart          # Role list with participant counts
│   │   │   └── role_form_screen.dart           # Role create/edit
│   │   ├── tasks/
│   │   │   └── tasks_screen.dart               # Task management (integrated form)
│   │   ├── settings/
│   │   │   ├── settings_screen.dart            # Settings overview
│   │   │   └── categories_management_screen.dart # Manage expense/income categories
│   │   └── cash_status/
│   │       └── cash_status_screen.dart         # Financial overview with charts
│   │
│   ├── widgets/
│   │   ├── responsive_form_container.dart      # Responsive form width constraint
│   │   └── forms/
│   │       └── price_preview_widget.dart       # Live price calculation (reactive)
│   │
│   ├── services/
│   │   ├── price_calculator_service.dart       # Price calculation logic
│   │   ├── ruleset_parser_service.dart         # YAML parsing & validation
│   │   ├── excel_import_service.dart           # Excel import logic
│   │   └── pdf_export_service.dart             # PDF generation
│   │
│   ├── utils/
│   │   ├── logger.dart                         # Centralized logging (AppLogger)
│   │   ├── constants.dart                      # App-wide constants (colors, spacing, etc.)
│   │   ├── ui_helpers.dart                     # SnackBar, Dialog, responsive helpers
│   │   ├── route_helpers.dart                  # Navigation helpers
│   │   ├── exceptions.dart                     # Custom exception types (15+ types)
│   │   ├── validators.dart                     # Form validators (email, IBAN, etc.)
│   │   └── date_utils.dart                     # German date formatting + age calc
│   │
│   ├── extensions/
│   │   ├── context_extensions.dart             # BuildContext extensions (theme, navigation, etc.)
│   │   ├── string_extensions.dart              # String utilities (validation, formatting)
│   │   └── date_time_extensions.dart           # DateTime helpers (German formatting, age)
│   │
│   └── main.dart                               # App entry point
│
├── pubspec.yaml                                # Dependencies
└── TECHNICAL_README.md                         # This file
```

---

## Database Schema (12 Tables)

All tables are defined in `lib/data/database/app_database.dart` using Drift annotations.

### Core Tables

1. **Events** - Veranstaltungen
   - `id`, `name`, `start_date`, `end_date`, `location`, `description`
   - One event active per session (selected in `current_event_provider`)

2. **Participants** - Teilnehmer (Main entity)
   - `id`, `event_id`, `first_name`, `last_name`, `birth_date`, `gender`
   - Address: `street`, `house_number`, `postal_code`, `city`, `country`
   - Contact: `email`, `phone`, `mobile`
   - Emergency: `emergency_contact_name`, `emergency_contact_phone`
   - Medical: `medical_info`, `allergies`, `medications`, `dietary_restrictions`, `swim_ability`
   - Pricing: `calculated_price`, `manual_price_override`, `discount_percent`
   - Relations: `family_id`, `role_id`
   - Soft delete: `is_active`

3. **Families** - Familien
   - `id`, `event_id`, `family_name`, contact info, address
   - Used for family discount calculations

4. **Payments** - Zahlungen
   - `id`, `event_id`, `amount`, `payment_date`, `payment_method`
   - Can be linked to `participant_id` OR `family_id` (not both)
   - Soft delete: `is_active`

5. **Expenses** - Ausgaben
   - `id`, `event_id`, `category`, `amount`, `expense_date`
   - Optional: `description`, `vendor`, `receipt_number`, `payment_method`
   - Categories: Dynamically managed via ExpenseCategories table
   - Soft delete: `is_active`

6. **ExpenseCategories** - Ausgaben-Kategorien (NEW)
   - `id`, `event_id`, `name`, `description`, `sort_order`
   - `is_system` - System categories (cannot be deleted)
   - `is_active` - Soft delete flag
   - Default categories: Verpflegung, Unterkunft, Transport, Material, Personal, Versicherung, Sonstiges
   - Users can create/edit/delete custom categories via Settings

7. **Incomes** - Einnahmen
   - `id`, `event_id`, `source`, `amount`, `income_date`
   - Optional: `description`, `reference_number`, `payment_method`
   - Sources: Dynamically managed via IncomeSources table
   - Soft delete: `is_active`

8. **IncomeSources** - Einnahmen-Quellen (NEW)
   - `id`, `event_id`, `name`, `description`, `sort_order`
   - `is_system` - System sources (cannot be deleted)
   - `is_active` - Soft delete flag
   - Default sources: Teilnehmerbeitrag, Spende, Zuschuss, Sponsoring, Merchandise, Sonstiges
   - Users can create/edit/delete custom sources via Settings

9. **Rulesets** - Regelwerke (Pricing rules)
   - `id`, `event_id`, `name`, `yaml_content`, `valid_from`, `description`
   - Contains YAML definition of age groups, role discounts, family discounts
   - Active ruleset determined by `valid_from` date
   - Soft delete: `is_active`

10. **Roles** - Rollen
    - `id`, `event_id`, `name`, `description`
    - Examples: Mitarbeiter, Leitung, Küche, Technik
    - Used in rulesets for role-based discounts

11. **Tasks** - Aufgaben
    - `id`, `event_id`, `title`, `description`, `status`, `priority`, `due_date`
    - Optional: `assigned_to` (participant_id)
    - Status: pending, in_progress, completed
    - Priority: 1 (low), 2 (medium), 3 (high)

12. **Settings** - Einstellungen
    - `id`, `key`, `value`
    - App-wide configuration

---

## Code Quality Standards

This section documents the code quality patterns and utilities implemented to ensure consistency, maintainability, and best practices across the codebase.

### Logging Infrastructure

**Location:** `lib/utils/logger.dart`

**Purpose:** Centralized, structured logging for the entire application.

**Usage:**
```dart
import '../utils/logger.dart';

AppLogger.debug('Participant loaded', participant);
AppLogger.info('Price calculated: $price');
AppLogger.warning('Ruleset validation issue', validationData);
AppLogger.error('Database operation failed', error: e, stackTrace: stack);
```

**Key Features:**
- Automatic log level filtering (debug in dev, warning in production)
- Structured log output with timestamps and caller info
- Stack trace support for errors
- Pretty-printed output with colors (in debug mode)

**Rules:**
- **NEVER** use `print()` or `developer.log()` directly
- **ALWAYS** use `AppLogger` for all logging
- Use appropriate log levels: `debug` for development info, `info` for important events, `warning` for issues, `error` for exceptions

### Constants Management

**Location:** `lib/utils/constants.dart`

**Purpose:** Eliminate magic numbers and ensure UI consistency.

**Categories:**
```dart
// Colors
AppConstants.primaryColor       // Color(0xFF2196F3) - Material Blue
AppConstants.secondaryColor     // Color(0xFF4CAF50) - Green
AppConstants.successColor       // Colors.green
AppConstants.errorColor         // Colors.red

// Spacing
AppConstants.spacing            // 16.0
AppConstants.spacingXS          // 4.0
AppConstants.spacingS           // 8.0
AppConstants.spacingM           // 12.0
AppConstants.spacingL           // 24.0
AppConstants.spacingXL          // 32.0

// Padding
AppConstants.paddingAll16       // EdgeInsets.all(16)
AppConstants.paddingAll8        // EdgeInsets.all(8)
AppConstants.paddingHorizontal  // EdgeInsets.symmetric(horizontal: 16)
AppConstants.paddingVertical    // EdgeInsets.symmetric(vertical: 16)

// Border Radius
AppConstants.borderRadius8      // BorderRadius.circular(8)
AppConstants.borderRadius12     // BorderRadius.circular(12)
AppConstants.borderRadius16     // BorderRadius.circular(16)

// Elevations
AppConstants.elevationLow       // 2.0
AppConstants.elevationMedium    // 4.0
AppConstants.elevationHigh      // 8.0

// Responsive Breakpoints
AppConstants.maxFormWidth       // 800.0 - Max width for forms on desktop
AppConstants.mobileBreakpoint   // 600.0
AppConstants.tabletBreakpoint   // 900.0

// Domain Constants
AppConstants.paymentMethods     // List<String> of all payment methods
AppConstants.swimAbilities      // List<String> of swim ability levels
AppConstants.genders            // List<String> of gender options
```

**Rules:**
- **NEVER** use hardcoded numbers for spacing, colors, or UI measurements
- **ALWAYS** use AppConstants for consistent values
- Define new constants in AppConstants when adding new UI patterns
- Group related constants together with clear comments

### UI Helpers

**Location:** `lib/utils/ui_helpers.dart`

**Purpose:** Reduce code duplication for common UI operations.

**Available Helpers:**

```dart
// SnackBars (with icons and proper colors)
UIHelpers.showSuccessSnackbar(context, 'Operation successful');
UIHelpers.showErrorSnackbar(context, 'An error occurred');
UIHelpers.showInfoSnackbar(context, 'Information message');
UIHelpers.showWarningSnackbar(context, 'Warning message');

// Dialogs
final confirmed = await UIHelpers.showConfirmDialog(
  context: context,
  title: 'Confirm Action',
  message: 'Are you sure?',
);

final deleted = await UIHelpers.showDeleteConfirmDialog(
  context: context,
  itemName: 'Participant "John Doe"',
);

// Responsive Helpers
final isMobile = UIHelpers.isMobile(context);
final isTablet = UIHelpers.isTablet(context);
final isDesktop = UIHelpers.isDesktop(context);
```

**Rules:**
- **NEVER** create SnackBars directly with ScaffoldMessenger
- **ALWAYS** use UIHelpers for SnackBars and Dialogs
- Use confirm dialogs for destructive actions
- Use showDeleteConfirmDialog specifically for delete operations

### Navigation Helpers

**Location:** `lib/utils/route_helpers.dart`

**Purpose:** Consistent navigation patterns across the app.

**Available Methods:**

```dart
// Basic navigation
RouteHelpers.push(context, TargetScreen());
RouteHelpers.pop(context, optionalResult);

// Replace current route
RouteHelpers.pushReplacement(context, NewScreen());

// Remove all previous routes
RouteHelpers.pushAndRemoveUntil(context, HomeScreen());

// Animated navigation
RouteHelpers.pushWithSlideTransition(context, Screen(), direction: SlideDirection.left);
RouteHelpers.pushWithFadeTransition(context, Screen());
```

**Rules:**
- **PREFER** RouteHelpers over direct Navigator calls
- Use descriptive navigation methods
- Use animations for better UX when appropriate

### Context Extensions

**Location:** `lib/extensions/context_extensions.dart`

**Purpose:** Simplify common BuildContext operations.

**Available Extensions:**

```dart
// Theme Access
context.theme              // ThemeData
context.textTheme          // TextTheme
context.colorScheme        // ColorScheme
context.primaryColor       // Color
context.secondaryColor     // Color

// MediaQuery
context.screenWidth        // double
context.screenHeight       // double
context.isMobile           // bool
context.isTablet           // bool
context.isDesktop          // bool

// Navigation (simplified)
context.pushScreen(TargetScreen());
context.popScreen(result);
context.pushReplacementScreen(NewScreen());

// SnackBars (simplified)
context.showSuccess('Success message');
context.showError('Error message');
context.showInfo('Info message');
context.showWarning('Warning message');

// Dialogs (simplified)
final confirmed = await context.showConfirm(
  title: 'Confirm',
  message: 'Are you sure?',
);
```

**Rules:**
- **PREFER** context extensions for cleaner code
- Use `context.showSuccess()` instead of `UIHelpers.showSuccessSnackbar(context, ...)`
- Use `context.pushScreen()` instead of `RouteHelpers.push(context, ...)`
- Extensions make code more readable and concise

### String Extensions

**Location:** `lib/extensions/string_extensions.dart`

**Purpose:** Common string operations and validations.

**Available Extensions:**

```dart
// Validation
text.isBlank               // isEmpty after trim
text.isNotBlank            // !isBlank
text.isValidEmail          // Email regex validation
text.isValidIBAN           // German IBAN validation
text.isNumeric             // Only digits

// Formatting
text.capitalize            // First letter uppercase
text.toTitleCase          // Each word capitalized
text.removeWhitespace     // Remove all whitespace
text.formatIban           // Format as DE12 3456 7890 1234 5678 90

// Parsing
text.toInt()              // Parse to int with default
text.toDouble()           // Parse to double with default
```

**Rules:**
- Use string extensions for validation before submitting forms
- Use formatIban for displaying IBAN in forms
- Prefer `text.isBlank` over `text.trim().isEmpty`

### DateTime Extensions

**Location:** `lib/extensions/date_time_extensions.dart`

**Purpose:** Date operations and German formatting.

**Available Extensions:**

```dart
// Formatting
date.toGermanDate          // 01.01.2025
date.toGermanDateTime      // 01.01.2025 14:30
date.toIsoDate             // 2025-01-01

// Date checks
date.isToday               // bool
date.isYesterday           // bool
date.isTomorrow            // bool
date.isThisWeek            // bool
date.isThisMonth           // bool
date.isThisYear            // bool
date.isInPast              // bool
date.isInFuture            // bool

// Date manipulation
date.addDays(7)            // Add days
date.subtractDays(3)       // Subtract days
date.addMonths(2)          // Add months
date.addYears(1)           // Add years
date.startOfDay            // 00:00:00
date.endOfDay              // 23:59:59
date.firstDayOfMonth       // First day
date.lastDayOfMonth        // Last day

// Calculations
date.age                   // Age in years
date.differenceInDays(other)   // Days between
date.differenceInMonths(other) // Months between
```

**Rules:**
- **ALWAYS** use `.toGermanDate` for displaying dates in UI
- Use date checks (isToday, isThisWeek) for filtering
- Use date manipulation methods instead of manual Duration arithmetic

### Custom Exceptions

**Location:** `lib/utils/exceptions.dart`

**Purpose:** Type-safe error handling with specific exception types.

**Exception Hierarchy:**

```dart
AppException (abstract base)
├── DatabaseException
│   ├── NotFoundException
│   └── ConstraintViolationException
├── ValidationException
│   └── InvalidInputException
├── BusinessRuleException
│   ├── PriceCalculationException
│   └── RulesetParseException
├── ImportExportException
│   ├── ExcelImportException
│   └── PdfExportException
├── NetworkException
└── PermissionException
```

**Usage:**

```dart
// Throwing exceptions
throw NotFoundException('Participant', participantId);
throw ValidationException('Invalid email', fieldErrors: {'email': 'Invalid format'});
throw BusinessRuleException('Age must be within event dates');

// Catching exceptions
try {
  await repository.getParticipantById(id);
} on NotFoundException catch (e) {
  context.showError('Participant not found');
} on DatabaseException catch (e) {
  AppLogger.error('Database error', error: e);
  context.showError('Database operation failed');
} catch (e) {
  context.showError('Unexpected error: $e');
}

// Helper function
final appError = toAppException(error, context: 'Participant creation');
```

**Rules:**
- **PREFER** specific exception types over generic Exception
- Use NotFoundException for missing database records
- Use ValidationException for form validation errors
- Always log exceptions before showing user feedback
- Use toAppException helper to convert unknown errors

### Responsive Design

**Location:** `lib/widgets/responsive_form_container.dart`

**Purpose:** Ensure forms don't span entire screen on desktop.

**Usage:**

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: ResponsiveFormContainer(
      maxWidth: 800, // Optional, defaults to AppConstants.maxFormWidth
      child: ListView(
        children: [
          // Your form fields here
        ],
      ),
    ),
  );
}
```

**Rules:**
- **ALWAYS** wrap form ListView with ResponsiveFormContainer
- Use default maxWidth (800px) for most forms
- Adjust maxWidth only if design requires different constraint
- Container automatically centers content on desktop

---

## Key Business Logic

### Price Calculation (`price_calculator_service.dart`)

**Location:** `lib/services/price_calculator_service.dart` (~350 lines)

**Purpose:** Calculate participant price based on age, role, and family status.

**Algorithm:**
1. Check file cash_status.py for calculation logic in the Folder "OLD"
2. Get base price from age group in ruleset
3. Apply role discount (if participant has role)
4. Apply family discount (based on number of children in family)
5. Discounts are NON-STACKING (both calculated from base price, not cumulative)

**Key Method:**
```dart
static double calculateParticipantPrice({
  required int age,
  String? roleName,
  required Map<String, dynamic> rulesetData,
  int familyChildrenCount = 1,
})
```

**Called by:** `participant_repository.dart` on create/update

### Ruleset YAML Structure

**Location:** `lib/services/ruleset_parser_service.dart` (~400 lines)

**YAML Format:**
```yaml
name: "Sommerfreizeit 2024"
valid_from: 2024-01-01

age_groups:
  - name: "Kinder"
    min_age: 0
    max_age: 12
    base_price: 150.00
  - name: "Jugendliche"
    min_age: 13
    max_age: 17
    base_price: 180.00
  - name: "Erwachsene"
    min_age: 18
    max_age: 999
    base_price: 200.00

role_discounts:
  - role_name: "Mitarbeiter"
    discount_percent: 50.0
  - role_name: "Leitung"
    discount_percent: 100.0

family_discount:
  min_children: 2
  discount_percent_per_child:
    - children_count: 2
      discount_percent: 10.0
    - children_count: 3
      discount_percent: 15.0
```

**Validation:** Performed in `ruleset_repository.dart` before save

---

## State Management Patterns

### Riverpod Provider Types Used

1. **Provider** - For singletons (services, repositories)
   ```dart
   final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());
   ```

2. **StateNotifier + StateNotifierProvider** - For mutable state
   ```dart
   final currentEventProvider = StateNotifierProvider<CurrentEventNotifier, Event?>(...)
   ```

3. **StreamProvider** - For reactive data (database streams)
   ```dart
   final participantsProvider = StreamProvider<List<Participant>>((ref) {
     return repository.watchParticipantsByEvent(eventId);
   });
   ```

4. **FutureProvider** - For async data fetching
   ```dart
   final totalExpensesProvider = FutureProvider<double>((ref) async {...});
   ```

### Common Pattern

```dart
// In screen:
final participantsAsync = ref.watch(participantsProvider);

participantsAsync.when(
  data: (participants) => /* Build UI with data */,
  loading: () => CircularProgressIndicator(),
  error: (error, stack) => Text('Error: $error'),
);
```

---

## Repository Pattern

### Standard Repository Methods

All repositories in `lib/data/repositories/*` follow this pattern:

```dart
class XxxRepository {
  final AppDatabase _database;

  // Stream (reactive)
  Stream<List<Xxx>> watchXxxByEvent(int eventId)

  // Single fetch
  Future<Xxx?> getXxxById(int id)
  Future<List<Xxx>> getXxxByEvent(int eventId)

  // CRUD
  Future<int> createXxx({required params...})
  Future<bool> updateXxx({required int id, optional params...})
  Future<bool> deleteXxx(int id)  // Usually soft delete

  // Statistics/Aggregations
  Future<Map<String, dynamic>> getXxxStatistics(int eventId)
}
```

### Special Repository Features

**participant_repository.dart:**
- Auto-calculates price on create/update
- Validates age against event dates
- Handles family member count for discounts

**expense_repository.dart & income_repository.dart:**
- Category/Source aggregations
- Date range filtering
- Search by description/vendor/notes

**ruleset_repository.dart:**
- YAML validation before save
- Active ruleset determination by date
- Template generation

**role_repository.dart:**
- Prevents deletion if role is in use
- Tracks participant counts

**task_repository.dart:**
- Overdue task detection
- Upcoming tasks (next 7 days)
- Status and priority filtering

---

## UI Patterns

### Form Screens

**Pattern:** All form screens follow this structure (using new patterns):

```dart
import '../utils/constants.dart';
import '../utils/ui_helpers.dart';
import '../utils/route_helpers.dart';
import '../utils/logger.dart';
import '../extensions/context_extensions.dart';
import '../widgets/responsive_form_container.dart';

class XxxFormScreen extends ConsumerStatefulWidget {
  final int? xxxId; // null = create, value = edit

  @override
  ConsumerState<XxxFormScreen> createState() => _XxxFormScreenState();
}

class _XxxFormScreenState extends ConsumerState<XxxFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.xxxId != null) {
      _loadXxx(); // Load existing data
    }
  }

  Future<void> _saveXxx() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final repository = ref.read(xxxRepositoryProvider);
      if (widget.xxxId == null) {
        await repository.createXxx(...);
        AppLogger.info('Xxx created successfully');
      } else {
        await repository.updateXxx(id: widget.xxxId!, ...);
        AppLogger.info('Xxx updated successfully', widget.xxxId);
      }

      if (context.mounted) {
        context.showSuccess(
          widget.xxxId == null ? 'Erstellt' : 'Aktualisiert'
        );
        RouteHelpers.pop(context);
      }
    } catch (e, stack) {
      AppLogger.error('Save operation failed', error: e, stackTrace: stack);
      if (context.mounted) {
        context.showError('Fehler: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.xxxId == null ? 'Neu' : 'Bearbeiten'),
      ),
      body: ResponsiveFormContainer(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: AppConstants.paddingAll16,
            children: [
              TextFormField(
                controller: _controller,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              SizedBox(height: AppConstants.spacing),
              // More fields...
              FilledButton(
                onPressed: _saveXxx,
                child: const Text('Speichern'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### List Screens

**Pattern:** List screens with search/filter:

```dart
class XxxListScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<XxxListScreen> createState() => _XxxListScreenState();
}

class _XxxListScreenState extends ConsumerState<XxxListScreen> {
  String _searchQuery = '';
  String? _filter;

  List<Xxx> _filterItems(List<Xxx> items) {
    // Apply search and filters
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(xxxProvider);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(icon: Icon(Icons.filter_list), onPressed: _showFilter),
          IconButton(icon: Icon(Icons.add), onPressed: () => navigate to form),
        ],
      ),
      body: Column([
        SearchBar(...),
        FilterChips(...),
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

---

## Navigation Structure

### Menu Organization (Desktop & Mobile)

The menu is organized into three logical groups:

**📊 VERWALTUNG (Administration)**
- Dashboard
- Teilnehmer & Familien (Participants & Families - combined with tabs)
- Aufgaben (Tasks)

**💰 FINANZEN (Finance)**
- Zahlungseingänge (Payment Receipts)
- Sonstige Einnahmen (Other Income)
- Ausgaben (Expenses)
- Kassenstand (Cash Status)

**⚙️ EINSTELLUNGEN (Settings)**
- Einstellungen (includes Regelwerke management in Tab 2)

### Screen Hierarchy

```
EventSelectionScreen (/)
  └─> DashboardScreen
       │
       ├─> [VERWALTUNG]
       │   ├─> ParticipantsFamiliesScreen (Tabs: Participants | Families)
       │   │    ├─> Tab 1: ParticipantsListScreen
       │   │    │    ├─> ParticipantFormScreen (create/edit)
       │   │    │    └─> ParticipantImportScreen (Excel)
       │   │    └─> Tab 2: FamiliesListScreen
       │   │         └─> FamilyFormScreen
       │   └─> TasksScreen (integrated form dialog)
       │
       ├─> [FINANZEN]
       │   ├─> PaymentsListScreen
       │   │    └─> PaymentFormScreen
       │   ├─> IncomesListScreen
       │   │    └─> IncomeFormScreen
       │   ├─> ExpensesListScreen
       │   │    └─> ExpenseFormScreen
       │   └─> CashStatusScreen (charts + PDF export)
       │
       └─> [EINSTELLUNGEN]
            └─> SettingsScreen (Tabs: Allgemein | Regelwerk | Kategorien | App-Info)
                 ├─> Tab 1: General settings
                 ├─> Tab 2: RulesetsManagementScreen (Regelwerk)
                 │    └─> RulesetFormScreen (YAML editor)
                 ├─> Tab 3: CategoriesManagementScreen
                 │    ├─> Expenses tab (create/edit/delete/reorder)
                 │    └─> Incomes tab (create/edit/delete/reorder)
                 └─> Tab 4: App Info
```

### Notes
- **Rollen (Roles):** No longer in main navigation - roles are derived from Regelwerke (rulesets)
- **Desktop:** Uses custom blue sidebar (280px) with grouped navigation
- **Mobile:** Uses Drawer with same grouped structure and blue theme
- **Terminology:** "Zahlungen" → "Zahlungseingänge" for clarity

**Navigation Pattern (NEW):**
```dart
// PREFERRED: Use RouteHelpers or context extensions
RouteHelpers.push(context, XxxScreen());
// OR
context.pushScreen(XxxScreen());

// LEGACY: Direct Navigator (avoid in new code)
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => XxxScreen()),
);
```

---

## Important Conventions

### Naming Patterns

- **Repositories:** `{entity}_repository.dart` → `XxxRepository` class
- **Providers:** `{entity}_provider.dart` → Multiple providers exported
- **Screens:** `{entity}_list_screen.dart` / `{entity}_form_screen.dart`
- **Services:** `{purpose}_service.dart` → Static methods or singleton

### Database Conventions

- **Table names:** Plural (participants, families, payments)
- **Class names:** Singular (Participant, Family, Payment)
- **Soft delete:** `is_active` boolean (default true)
- **Timestamps:** `created_at`, `updated_at` (auto-managed)
- **Foreign keys:** `{entity}_id` (e.g., `event_id`, `family_id`)

### German Terminology

- **Teilnehmer** = Participant
- **Familie** = Family
- **Zahlung** = Payment
- **Ausgabe** = Expense
- **Einnahme** = Income
- **Regelwerk** = Ruleset
- **Rolle** = Role
- **Aufgabe** = Task
- **Kassenstand** = Cash balance

---

## Common Tasks Guide

### Adding a New Field to Participant

1. **Database:** Update `Participants` table in `app_database.dart`
2. **Generate:** Run `flutter pub run build_runner build`
3. **Repository:** Update `createParticipant` and `updateParticipant` in `participant_repository.dart`
4. **Form:** Add field to `participant_form_screen.dart`
5. **Display:** Update `participants_list_screen.dart` if needed

### Creating a New CRUD Entity

1. **Database table:** Add to `app_database.dart`
2. **Repository:** Create `{entity}_repository.dart` with standard methods
3. **Provider:** Create `{entity}_provider.dart` with StreamProvider
4. **List screen:** Create `{entity}_list_screen.dart`
5. **Form screen:** Create `{entity}_form_screen.dart`
6. **Navigation:** Add to `dashboard_screen.dart` drawer

### Modifying Price Calculation

**File:** `lib/services/price_calculator_service.dart`

**Note:** Price is recalculated on every participant create/update in `participant_repository.dart`

**Affected areas:**
- `calculateParticipantPrice()` - Main calculation
- `_getBasePriceByAge()` - Age group lookup
- `_getRoleDiscount()` - Role discount lookup
- `_getFamilyDiscount()` - Family discount calculation

### Adding New Report/Export

1. **PDF:** Add method to `pdf_export_service.dart`
2. **Excel:** Add method to `excel_import_service.dart`
3. **UI:** Add export button to relevant screen
4. **Provider:** Use `pdfExportServiceProvider` or `excelImportServiceProvider`

### Managing Expense/Income Categories

**Location:** Settings → Categories Management

**Features:**
- Create new categories/sources
- Edit existing (name, description)
- Delete custom categories (system categories protected)
- Drag-to-reorder for custom sorting
- Separate tabs for Expenses and Incomes

**System Categories (cannot be deleted):**
- Expenses: Verpflegung, Unterkunft, Transport, Material, Personal, Versicherung, Sonstiges
- Incomes: Teilnehmerbeitrag, Spende, Zuschuss, Sponsoring, Merchandise, Sonstiges

**Technical:**
- Repository: `lib/data/repositories/category_repository.dart`
- Provider: `lib/providers/category_provider.dart`
- Screen: `lib/screens/settings/categories_management_screen.dart`
- Database: `ExpenseCategories` and `IncomeSources` tables

### Adding a New Utility Helper

1. **Determine type:**
   - Static methods → Add to appropriate helper in `lib/utils/`
   - Instance methods on existing type → Add extension in `lib/extensions/`

2. **For utils:** Add to existing file or create new `{purpose}_helper.dart`
3. **For extensions:** Add to existing extension or create new `{type}_extensions.dart`
4. **Document:** Add to Code Quality Standards section in TECHNICAL_README.md
5. **Test:** Verify usage across codebase

### Adding a New Constant

1. **Open:** `lib/utils/constants.dart`
2. **Find category:** Colors, Spacing, Padding, BorderRadius, etc.
3. **Add constant:** Follow naming pattern (e.g., `spacingXXL`, `paddingSymmetric12`)
4. **Document:** Add comment if non-obvious
5. **Use:** Import and use throughout codebase

---

## Testing the App

### Run on Windows (IntelliJ/VS Code)

```bash
cd flutter_app
flutter pub get
flutter pub run build_runner build
flutter run -d windows
```

### Run on macOS

```bash
flutter run -d macos
```

### Run on iOS Simulator

```bash
flutter run -d "iPhone 14 Pro"
```

### Database Location

- **Windows:** `%APPDATA%\com.example\mgbfreizeitplaner\databases\`
- **macOS:** `~/Library/Application Support/com.example.mgbfreizeitplaner/databases/`
- **iOS:** App sandbox documents directory

### Reset Database

Delete the database file and restart the app. Database will be recreated with schema.

---

## Performance Considerations

### Reactive Updates

All list screens use `StreamProvider` which automatically updates UI when database changes. No manual refresh needed.

### Price Recalculation

Participant prices are recalculated on:
1. Participant create/update
2. Family assignment change
3. Role assignment change
4. Manual price override

**NOT recalculated when:**
- Ruleset changes (would need manual migration)
- Family member count changes (would need batch update)

### Pagination

Currently NOT implemented. All lists load full data. If lists grow large (>1000 items), consider:
- Adding pagination to repositories
- Using `limit` and `offset` in Drift queries
- Implementing infinite scroll in list screens

---

## Error Handling Patterns

### Repository Level (NEW)

```dart
import '../utils/exceptions.dart';
import '../utils/logger.dart';

Future<int> createXxx({required String name, required int eventId}) async {
  try {
    // Input validation
    if (name.trim().isEmpty) {
      throw InvalidInputException('name', 'Name darf nicht leer sein');
    }

    // Business rule validation
    final existing = await _getXxxByName(name, eventId);
    if (existing != null) {
      throw ValidationException('Name bereits vergeben');
    }

    // Database operation
    final id = await _database.into(_database.xxxs).insert(...);
    AppLogger.info('Xxx created successfully', id);
    return id;
  } on AppException {
    rethrow; // Pass app exceptions to UI
  } catch (e, stack) {
    AppLogger.error('Failed to create xxx', error: e, stackTrace: stack);
    throw DatabaseException(
      'Datenbankfehler beim Erstellen',
      originalError: e,
    );
  }
}
```

### UI Level (NEW)

```dart
import '../utils/logger.dart';
import '../utils/route_helpers.dart';
import '../utils/exceptions.dart';
import '../extensions/context_extensions.dart';

Future<void> _saveXxx() async {
  if (!_formKey.currentState!.validate()) return;

  try {
    final repository = ref.read(xxxRepositoryProvider);
    await repository.createXxx(
      name: _nameController.text.trim(),
      eventId: eventId,
    );

    if (context.mounted) {
      context.showSuccess('Erfolgreich erstellt');
      RouteHelpers.pop(context);
    }
  } on ValidationException catch (e) {
    // Validation errors - show to user
    if (context.mounted) {
      context.showError(e.message);
    }
  } on NotFoundException catch (e) {
    // Not found errors
    if (context.mounted) {
      context.showError('Datensatz nicht gefunden');
    }
  } on DatabaseException catch (e) {
    // Database errors
    AppLogger.error('Database operation failed', error: e);
    if (context.mounted) {
      context.showError('Datenbankfehler: ${e.message}');
    }
  } catch (e, stack) {
    // Unexpected errors
    AppLogger.error('Unexpected error in _saveXxx', error: e, stackTrace: stack);
    if (context.mounted) {
      context.showError('Ein unerwarteter Fehler ist aufgetreten');
    }
  }
}
```

### Exception Type Usage

- **NotFoundException**: Database record not found
- **ValidationException**: Form or business rule validation failed
- **InvalidInputException**: Specific field validation failed
- **DatabaseException**: Database operation failed
- **ConstraintViolationException**: SQL constraint violated (UNIQUE, FOREIGN KEY)
- **BusinessRuleException**: Business logic violation
- **PriceCalculationException**: Price calculation error
- **RulesetParseException**: YAML parsing error
- **ExcelImportException**: Excel import error
- **PdfExportException**: PDF generation error

### Best Practices

1. **ALWAYS** log errors before showing to user
2. **PREFER** specific exception types over generic Exception
3. **ALWAYS** check `context.mounted` before showing UI feedback after async operations
4. **NEVER** expose technical error details to users in production
5. Use `toAppException` helper to convert unknown errors to AppException

---

## Dependencies (pubspec.yaml)

### Core
- `flutter_riverpod` - State management
- `drift` - SQLite ORM
- `sqlite3_flutter_libs` - SQLite binaries
- `path_provider` - File system paths
- `logger` - Structured logging (NEW)

### UI
- `intl` - Internationalization & formatting
- `fl_chart` - Charts
- `file_picker` - File selection dialogs

### Data
- `excel` - Excel import/export
- `pdf` - PDF generation
- `yaml` - YAML parsing

### Dev
- `build_runner` - Code generation
- `drift_dev` - Drift code generator

---

## Quick Reference: Finding Files

**"I need to modify participant price calculation"**
→ `lib/services/price_calculator_service.dart`

**"I need to add a field to participant form"**
→ `lib/screens/participants/participant_form_screen.dart`

**"I need to change database schema"**
→ `lib/data/database/app_database.dart` → then run `build_runner`

**"I need to add financial statistics"**
→ `lib/data/repositories/expense_repository.dart` or `income_repository.dart`

**"I need to modify dashboard stats"**
→ `lib/screens/dashboard/dashboard_screen.dart`

**"I need to change PDF export format"**
→ `lib/services/pdf_export_service.dart`

**"I need to add Excel import column"**
→ `lib/services/excel_import_service.dart` → `_parseRow()` method

**"I need to modify YAML ruleset structure"**
→ `lib/services/ruleset_parser_service.dart`

**"I need to add new chart to cash status"**
→ `lib/screens/cash_status/cash_status_screen.dart`

**"I need to change participant search logic"**
→ `lib/screens/participants/participants_list_screen.dart` → `_filterParticipants()`

**"I need to add a new constant for UI consistency"**
→ `lib/utils/constants.dart` → Add to appropriate section

**"I need to add logging to a service"**
→ Import `lib/utils/logger.dart` → Use `AppLogger.debug/info/error()`

**"I need to manage expense/income categories"**
→ Settings → Categories Management → `lib/screens/settings/categories_management_screen.dart`

**"I need to add a new exception type"**
→ `lib/utils/exceptions.dart` → Extend AppException hierarchy

**"I need to add a context extension"**
→ `lib/extensions/context_extensions.dart` → Add extension method

**"I need to make a form responsive"**
→ Wrap ListView with `ResponsiveFormContainer` from `lib/widgets/responsive_form_container.dart`

---


## Responsive Design & Platform Consistency

### Critical Rule: Desktop AND Mobile Views

**⚠️ WICHTIG: Bei ALLEN UI-Änderungen IMMER beide Ansichten berücksichtigen!**

Jede UI-Änderung muss für **Desktop (>800px) UND Mobile (≤800px)** durchdacht werden:

### Layout-Breakpoint
```dart
final isDesktop = MediaQuery.of(context).size.width >= 800;
```

### Common Patterns

**Navigation:**
- Desktop: Sidebar (280px) immer sichtbar
- Mobile: Drawer (swipe-in)
- Beide nutzen gleiche `_buildDrawer()` Methode

**Forms:**
- Desktop: Max. 800px Breite, zentriert
- Mobile: Volle Breite
- Lösung: `ResponsiveFormContainer` verwenden

**Buttons:**
- Desktop & Mobile: Gleiche Button-Konzepte verwenden
  - Extended FABs mit Icon + Label
  - NICHT in Mobile IconButton und in Desktop Extended FAB

**Lists:**
- Desktop: Hover-Effekte mit Trailing Buttons
- Mobile: Swipe-to-Action (links/rechts)
- Lösung: `AdaptiveListItem` verwenden

### Checklist für UI-Änderungen

Vor dem Commit prüfen:
- [ ] Desktop Ansicht getestet (>800px)
- [ ] Mobile Ansicht getestet (≤800px)
- [ ] Buttons folgen gleichem Konzept
- [ ] Navigation in beiden Views konsistent
- [ ] Forms sind responsive (ResponsiveFormContainer)
- [ ] Listen nutzen adaptive Patterns (AdaptiveListItem)

### Beispiele für Inkonsistenzen (VERMEIDEN):

❌ **FALSCH:**
```dart
// Mobile: IconButton im AppBar
actions: [
  if (!isDesktop) IconButton(icon: Icon(Icons.add), ...)
]

// Desktop: Extended FAB
floatingActionButton: isDesktop
    ? FloatingActionButton.extended(...)
    : null
```

✅ **RICHTIG:**
```dart
// Beide nutzen Extended FAB
floatingActionButton: FloatingActionButton.extended(
  icon: Icon(Icons.add),
  label: Text('Neu'),
  ...
)
```

---

## AI Assistant Tips

### Critical Rules (ALWAYS)

1. **Use AppLogger for all logging** - NEVER use `print()` or `developer.log()`
2. **Use AppConstants for all UI values** - NEVER hardcode spacing, colors, or measurements
3. **Use context extensions for SnackBars** - NEVER use ScaffoldMessenger directly
4. **Use RouteHelpers or context.pushScreen()** - PREFER over direct Navigator calls
5. **Wrap forms with ResponsiveFormContainer** - ALL form screens must be responsive
6. **Check context.mounted** - ALWAYS check before UI operations after async
7. **Use custom exceptions** - PREFER specific AppException types over generic Exception
8. **Log before showing errors** - ALWAYS log with AppLogger.error before showing to user

### Code Quality Patterns

9. **Import order**: utils → extensions → widgets → screens
10. **Error handling**: Use try-catch with specific exception types
11. **Validation**: Use string extensions (isBlank, isValidEmail, etc.)
12. **Date formatting**: Use date.toGermanDate for display
13. **State management**: Use Riverpod StreamProvider for reactive data
14. **Soft delete**: Most entities use `is_active` instead of hard delete

### Business Logic

15. **current_event_provider** - Most operations require an active event
16. **Price calculation is automatic** - Don't manually set `calculated_price`
17. **Categories are editable** - Expense/Income categories managed via Settings
18. **System categories protected** - Categories with isSystem=true cannot be deleted

### Database & Build

19. **Database changes require build_runner** - Run `dart run build_runner build` after modifying `app_database.dart`
20. **Streams are reactive** - No manual refresh needed in UI (StreamProvider handles it)
21. **Check for null safety** - Dart null safety is enforced throughout

### UI & UX

22. **German terminology** - UI strings are in German, keep consistency
23. **Material Design 3** - Use Material 3 widgets (FilledButton, Card with elevation, etc.)
24. **Consistent spacing** - Use AppConstants.spacing, spacingS, spacingL, etc.
25. **Responsive design** - Forms max 800px wide on desktop, full width on mobile

### File Organization

26. **Follow naming patterns**: `{entity}_repository.dart`, `{entity}_provider.dart`, `{entity}_list_screen.dart`
27. **New features**: Repository → Provider → Screen → Navigation
28. **Utilities first**: Create helpers in utils/ before duplicating code
29. **Extensions for reuse**: Add to extensions/ when extending existing types
30. **Constants for consistency**: Add to AppConstants when introducing new values

### Common Mistakes to Avoid

❌ **DON'T** use `EdgeInsets.all(16)` → ✅ Use `AppConstants.paddingAll16`
❌ **DON'T** use `SizedBox(height: 16)` → ✅ Use `SizedBox(height: AppConstants.spacing)`
❌ **DON'T** use `Color(0xFF2196F3)` → ✅ Use `AppConstants.primaryColor`
❌ **DON'T** use `ScaffoldMessenger.of(context).showSnackBar(...)` → ✅ Use `context.showSuccess()`
❌ **DON'T** use `Navigator.push(...)` → ✅ Use `context.pushScreen()` or `RouteHelpers.push()`
❌ **DON'T** use `print('debug')` → ✅ Use `AppLogger.debug('debug')`
❌ **DON'T** throw `Exception('error')` → ✅ Use specific exception types (ValidationException, etc.)
❌ **DON'T** forget ResponsiveFormContainer → ✅ Wrap all form ListViews

