import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// ============================================================================
// TABLE DEFINITIONS (entsprechen den SQLAlchemy-Modellen)
// ============================================================================

@DataClassName('Event')
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  TextColumn get location => text().withLength(max: 200).nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get eventType => text().withLength(max: 50).nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Participant')
class Participants extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId => integer().references(Events, #id)();
  TextColumn get firstName => text().withLength(min: 1, max: 100)();
  TextColumn get lastName => text().withLength(min: 1, max: 100)();
  DateTimeColumn get birthDate => dateTime()();
  TextColumn get gender => text().withLength(max: 20).nullable()();
  TextColumn get street => text().withLength(max: 200).nullable()();
  TextColumn get postalCode => text().withLength(max: 10).nullable()();
  TextColumn get city => text().withLength(max: 100).nullable()();
  TextColumn get phone => text().withLength(max: 50).nullable()();
  TextColumn get email => text().withLength(max: 100).nullable()();
  TextColumn get emergencyContactName => text().withLength(max: 200).nullable()();
  TextColumn get emergencyContactPhone => text().withLength(max: 50).nullable()();
  TextColumn get medications => text().nullable()();
  TextColumn get allergies => text().nullable()();
  TextColumn get dietaryRestrictions => text().nullable()();
  TextColumn get swimAbility => text().withLength(max: 50).nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get bildungUndTeilhabe => boolean().withDefault(const Constant(false))();
  RealColumn get calculatedPrice => real().withDefault(const Constant(0.0))();
  RealColumn get manualPriceOverride => real().nullable()();
  RealColumn get discountPercent => real().withDefault(const Constant(0.0))();
  TextColumn get discountReason => text().nullable()();
  IntColumn get roleId => integer().references(Roles, #id).nullable()();
  IntColumn get familyId => integer().references(Families, #id).nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // Computed column für full name wird in der Model-Klasse implementiert
}

@DataClassName('Family')
class Families extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId => integer().references(Events, #id)();
  TextColumn get familyName => text().withLength(min: 1, max: 200)();
  TextColumn get contactPerson => text().withLength(max: 200).nullable()();
  TextColumn get phone => text().withLength(max: 50).nullable()();
  TextColumn get email => text().withLength(max: 100).nullable()();
  TextColumn get street => text().withLength(max: 200).nullable()();
  TextColumn get postalCode => text().withLength(max: 10).nullable()();
  TextColumn get city => text().withLength(max: 100).nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Payment')
class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId => integer().references(Events, #id)();
  IntColumn get participantId => integer().references(Participants, #id).nullable()();
  IntColumn get familyId => integer().references(Families, #id).nullable()();
  RealColumn get amount => real()();
  DateTimeColumn get paymentDate => dateTime()();
  TextColumn get paymentMethod => text().withLength(max: 50).nullable()();
  TextColumn get referenceNumber => text().withLength(max: 100).nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Expense')
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId => integer().references(Events, #id)();
  TextColumn get category => text().withLength(min: 1, max: 100)();
  RealColumn get amount => real()();
  DateTimeColumn get expenseDate => dateTime()();
  TextColumn get description => text().nullable()();
  TextColumn get receiptNumber => text().withLength(max: 100).nullable()();
  TextColumn get vendor => text().withLength(max: 200).nullable()();
  TextColumn get paymentMethod => text().withLength(max: 50).nullable()();
  TextColumn get referenceNumber => text().withLength(max: 100).nullable()();
  TextColumn get paidBy => text().withLength(max: 200).nullable()();
  TextColumn get receiptFile => text().nullable()();
  BoolColumn get reimbursed => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Income')
class Incomes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId => integer().references(Events, #id)();
  TextColumn get category => text().withLength(min: 1, max: 100)();
  RealColumn get amount => real()();
  DateTimeColumn get incomeDate => dateTime()();
  TextColumn get description => text().nullable()();
  TextColumn get source => text().withLength(max: 200).nullable()();
  TextColumn get paymentMethod => text().withLength(max: 50).nullable()();
  TextColumn get referenceNumber => text().withLength(max: 100).nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Role')
class Roles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId => integer().references(Events, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get displayName => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Ruleset')
class Rulesets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId => integer().references(Events, #id)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get validFrom => dateTime()();
  DateTimeColumn get validUntil => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  TextColumn get yamlContent => text()();
  // JSON-Felder werden als TEXT gespeichert und in Dart als Map geparst (nullable, da aus YAML geparst)
  TextColumn get ageGroups => text().nullable()();
  TextColumn get roleDiscounts => text().nullable()();
  TextColumn get familyDiscount => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Setting')
class Settings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId => integer().references(Events, #id)();
  TextColumn get organizationName => text().withLength(max: 200).nullable()();
  TextColumn get organizationStreet => text().withLength(max: 200).nullable()();
  TextColumn get organizationPostalCode => text().withLength(max: 10).nullable()();
  TextColumn get organizationCity => text().withLength(max: 100).nullable()();
  TextColumn get bankName => text().withLength(max: 200).nullable()();
  TextColumn get iban => text().withLength(max: 34).nullable()();
  TextColumn get bic => text().withLength(max: 11).nullable()();
  TextColumn get invoiceFooter => text().nullable()();
  TextColumn get githubRulesetPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Task')
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId => integer().references(Events, #id)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withLength(max: 50).withDefault(const Constant('pending'))();
  TextColumn get priority => text().withLength(max: 50).withDefault(const Constant('medium'))();
  IntColumn get assignedTo => integer().references(Participants, #id).nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('ExpenseCategory')
class ExpenseCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId => integer().references(Events, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('IncomeSource')
class IncomeSources extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId => integer().references(Events, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// ============================================================================
// DATABASE CLASS
// ============================================================================

@DriftDatabase(tables: [
  Events,
  Participants,
  Families,
  Payments,
  Expenses,
  Incomes,
  ExpenseCategories,
  IncomeSources,
  Roles,
  Rulesets,
  Settings,
  Tasks,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  // ============================================================================
  // MIGRATION LOGIC (entspricht Alembic-Migrationen)
  // ============================================================================

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Migration von Version 2 zu 3: Entferne nicht benötigte Felder
        if (from < 3) {
          // Die Spalten houseNumber, country, mobile, medicalNotes, medicalInfo
          // wurden entfernt. Drift wird diese automatisch löschen.
          await m.recreateAllViews();
        }

        // Migration von Version 3 zu 4: Füge github_ruleset_path zur Settings-Tabelle hinzu
        if (from < 4) {
          await m.addColumn(settings, settings.githubRulesetPath);
        }
      },
    );
  }

  // ============================================================================
  // DATABASE CONNECTION
  // ============================================================================

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'freizeit_kassen.db'));

      return NativeDatabase.createInBackground(file);
    });
  }
}
