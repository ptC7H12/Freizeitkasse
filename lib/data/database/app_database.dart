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
  TextColumn get address => text().withLength(max: 500).nullable()();
  TextColumn get phone => text().withLength(max: 50).nullable()();
  TextColumn get email => text().withLength(max: 100).nullable()();
  TextColumn get emergencyContactName => text().withLength(max: 200).nullable()();
  TextColumn get emergencyContactPhone => text().withLength(max: 50).nullable()();
  TextColumn get medications => text().nullable()();
  TextColumn get allergies => text().nullable()();
  TextColumn get dietaryRestrictions => text().nullable()();
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
  TextColumn get address => text().withLength(max: 500).nullable()();
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
  TextColumn get organizationAddress => text().withLength(max: 500).nullable()();
  TextColumn get bankName => text().withLength(max: 200).nullable()();
  TextColumn get iban => text().withLength(max: 34).nullable()();
  TextColumn get bic => text().withLength(max: 11).nullable()();
  TextColumn get verwendungszweckPrefix => text().withLength(max: 100).nullable()();
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
  int get schemaVersion => 6;

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

        // Migration von Version 4 zu 5: Mache Rulesets-Felder nullable
        if (from < 5) {
          // SQLite unterstützt kein ALTER COLUMN, daher müssen wir die Tabelle neu erstellen
          // 1. Erstelle temporäre Tabelle mit altem Schema
          await customStatement('''
            CREATE TABLE rulesets_backup (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              event_id INTEGER NOT NULL,
              name TEXT NOT NULL,
              description TEXT,
              valid_from INTEGER NOT NULL,
              valid_until INTEGER,
              is_active INTEGER DEFAULT 0,
              yaml_content TEXT NOT NULL,
              age_groups TEXT,
              role_discounts TEXT,
              family_discount TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

          // 2. Kopiere Daten in Backup-Tabelle
          await customStatement('''
            INSERT INTO rulesets_backup
            SELECT id, event_id, name, description, valid_from, valid_until, is_active,
                   yaml_content, age_groups, role_discounts, family_discount, created_at, updated_at
            FROM rulesets
          ''');

          // 3. Lösche alte Tabelle
          await m.deleteTable('rulesets');

          // 4. Erstelle neue Tabelle mit nullable Feldern
          await m.createTable(rulesets);

          // 5. Kopiere Daten zurück
          await customStatement('''
            INSERT INTO rulesets (id, event_id, name, description, valid_from, valid_until, is_active,
                                  yaml_content, age_groups, role_discounts, family_discount, created_at, updated_at)
            SELECT id, event_id, name, description, valid_from, valid_until, is_active,
                   yaml_content, age_groups, role_discounts, family_discount, created_at, updated_at
            FROM rulesets_backup
          ''');

          // 6. Lösche Backup-Tabelle
          await customStatement('DROP TABLE rulesets_backup');
        }

        // Migration von Version 5 zu 6: Konsolidiere Adressfelder
        if (from < 6) {
          // ===== Participants Tabelle =====
          // 1. Backup erstellen
          await customStatement('''
            CREATE TABLE participants_backup AS SELECT * FROM participants
          ''');

          // 2. Alte Tabelle löschen
          await m.deleteTable('participants');

          // 3. Neue Tabelle mit 'address' Feld erstellen
          await m.createTable(participants);

          // 4. Daten migrieren (street, postalCode, city -> address)
          await customStatement('''
            INSERT INTO participants (
              id, event_id, first_name, last_name, birth_date, gender, address, phone, email,
              emergency_contact_name, emergency_contact_phone, medications, allergies,
              dietary_restrictions, notes, bildung_und_teilhabe, calculated_price,
              manual_price_override, discount_percent, discount_reason, role_id, family_id,
              is_active, deleted_at, created_at, updated_at
            )
            SELECT
              id, event_id, first_name, last_name, birth_date, gender,
              TRIM(
                COALESCE(street, '') ||
                CASE WHEN street IS NOT NULL AND (postal_code IS NOT NULL OR city IS NOT NULL) THEN ', ' ELSE '' END ||
                COALESCE(postal_code, '') ||
                CASE WHEN postal_code IS NOT NULL AND city IS NOT NULL THEN ' ' ELSE '' END ||
                COALESCE(city, '')
              ),
              phone, email, emergency_contact_name, emergency_contact_phone, medications,
              allergies, dietary_restrictions, notes, bildung_und_teilhabe, calculated_price,
              manual_price_override, discount_percent, discount_reason, role_id, family_id,
              is_active, deleted_at, created_at, updated_at
            FROM participants_backup
          ''');

          // 5. Backup löschen
          await customStatement('DROP TABLE participants_backup');

          // ===== Families Tabelle =====
          // 1. Backup erstellen
          await customStatement('''
            CREATE TABLE families_backup AS SELECT * FROM families
          ''');

          // 2. Alte Tabelle löschen
          await m.deleteTable('families');

          // 3. Neue Tabelle mit 'address' Feld erstellen
          await m.createTable(families);

          // 4. Daten migrieren (street, postalCode, city -> address)
          await customStatement('''
            INSERT INTO families (
              id, event_id, family_name, contact_person, phone, email, address,
              created_at, updated_at
            )
            SELECT
              id, event_id, family_name, contact_person, phone, email,
              TRIM(
                COALESCE(street, '') ||
                CASE WHEN street IS NOT NULL AND (postal_code IS NOT NULL OR city IS NOT NULL) THEN ', ' ELSE '' END ||
                COALESCE(postal_code, '') ||
                CASE WHEN postal_code IS NOT NULL AND city IS NOT NULL THEN ' ' ELSE '' END ||
                COALESCE(city, '')
              ),
              created_at, updated_at
            FROM families_backup
          ''');

          // 5. Backup löschen
          await customStatement('DROP TABLE families_backup');

          // ===== Settings Tabelle =====
          // 1. Backup erstellen
          await customStatement('''
            CREATE TABLE settings_backup AS SELECT * FROM settings
          ''');

          // 2. Alte Tabelle löschen
          await m.deleteTable('settings');

          // 3. Neue Tabelle mit 'organization_address' Feld erstellen
          await m.createTable(settings);

          // 4. Daten migrieren (organizationStreet, organizationPostalCode, organizationCity -> organizationAddress)
          await customStatement('''
            INSERT INTO settings (
              id, event_id, organization_name, organization_address, bank_name, iban, bic,
              verwendungszweck_prefix, invoice_footer, github_ruleset_path,
              created_at, updated_at
            )
            SELECT
              id, event_id, organization_name,
              TRIM(
                COALESCE(organization_street, '') ||
                CASE WHEN organization_street IS NOT NULL AND (organization_postal_code IS NOT NULL OR organization_city IS NOT NULL) THEN ', ' ELSE '' END ||
                COALESCE(organization_postal_code, '') ||
                CASE WHEN organization_postal_code IS NOT NULL AND organization_city IS NOT NULL THEN ' ' ELSE '' END ||
                COALESCE(organization_city, '')
              ),
              bank_name, iban, bic, "verwendungszweckPrefix", invoice_footer, "githubRulesetPath",
              created_at, updated_at
            FROM settings_backup
          ''');

          // 5. Backup löschen
          await customStatement('DROP TABLE settings_backup');
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
