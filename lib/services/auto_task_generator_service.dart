import '../data/database/app_database.dart';
import '../data/repositories/participant_repository.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/payment_repository.dart';
import '../data/repositories/income_repository.dart';
import '../data/repositories/role_repository.dart';
import '../data/repositories/family_repository.dart';
import '../data/repositories/task_repository.dart';
import '../data/repositories/ruleset_repository.dart';
import '../utils/logger.dart';
import 'price_calculator_service.dart';

/// Model class for a generated task
class GeneratedTask {
  final String taskType;
  final int referenceId;
  final String title;
  final String description;
  final String? link;
  final DateTime? dueDate;
  final String priority;
  final Map<String, dynamic>? metadata;

  GeneratedTask({
    required this.taskType,
    required this.referenceId,
    required this.title,
    required this.description,
    this.link,
    this.dueDate,
    this.priority = 'medium',
    this.metadata,
  });
}

/// Service for automatically generating tasks based on data analysis
class AutoTaskGeneratorService {
  final AppDatabase _database;
  final ParticipantRepository _participantRepo;
  final ExpenseRepository _expenseRepo;
  final PaymentRepository _paymentRepo;
  final IncomeRepository _incomeRepo;
  final RoleRepository _roleRepo;
  final FamilyRepository _familyRepo;
  final TaskRepository _taskRepo;
  final RulesetRepository _rulesetRepo;
  final PriceCalculatorService _priceCalculator;

  AutoTaskGeneratorService({
    required AppDatabase database,
    required ParticipantRepository participantRepo,
    required ExpenseRepository expenseRepo,
    required PaymentRepository paymentRepo,
    required IncomeRepository incomeRepo,
    required RoleRepository roleRepo,
    required FamilyRepository familyRepo,
    required TaskRepository taskRepo,
    required RulesetRepository rulesetRepo,
    required PriceCalculatorService priceCalculator,
  })  : _database = database,
        _participantRepo = participantRepo,
        _expenseRepo = expenseRepo,
        _paymentRepo = paymentRepo,
        _incomeRepo = incomeRepo,
        _roleRepo = roleRepo,
        _familyRepo = familyRepo,
        _taskRepo = taskRepo,
        _rulesetRepo = rulesetRepo,
        _priceCalculator = priceCalculator;

  /// Generate all automatic tasks for an event
  Future<Map<String, List<GeneratedTask>>> generateAllTasks(int eventId, Event event) async {
    AppLogger.info('Generating all automatic tasks for event $eventId');

    // Get completed tasks for filtering
    final completedTasks = await _taskRepo.getCompletedTasksByEvent(eventId);

    final tasks = <String, List<GeneratedTask>>{
      'bildung_teilhabe': [],
      'expense_reimbursement': [],
      'outstanding_payments': [],
      'manual_price_override': [],
      'overdue_payments': [],
      'income_subsidy_mismatch': [],
      'family_subsidy_mismatch': [],
      'role_count_exceeded': [],
      'birthday_gifts': [],
      'kitchen_team_gift': [],
      'familienfreizeit_non_member_check': [],
    };

    // Generate each task type
    tasks['bildung_teilhabe'] = await _generateBildungTeilhabeTasks(eventId, completedTasks);
    tasks['expense_reimbursement'] = await _generateExpenseReimbursementTasks(eventId, completedTasks);
    tasks['outstanding_payments'] = await _generateOutstandingPaymentTasks(eventId, completedTasks);
    tasks['manual_price_override'] = await _generateManualPriceOverrideTasks(eventId, completedTasks);
    tasks['overdue_payments'] = await _generateOverduePaymentTasks(eventId, event, completedTasks);
    tasks['income_subsidy_mismatch'] = await _generateIncomeSubsidyMismatchTasks(eventId, completedTasks);
    tasks['family_subsidy_mismatch'] = await _generateFamilySubsidyMismatchTasks(eventId, completedTasks);
    tasks['role_count_exceeded'] = await _generateRoleCountExceededTasks(eventId, completedTasks);
    tasks['birthday_gifts'] = await _generateBirthdayGiftsTasks(eventId, event, completedTasks);
    tasks['kitchen_team_gift'] = await _generateKitchenTeamGiftTasks(eventId, completedTasks);
    tasks['familienfreizeit_non_member_check'] = await _generateFamilienfreizeitCheckTasks(eventId, event, completedTasks);

    final totalTasks = tasks.values.fold<int>(0, (sum, list) => sum + list.length);
    AppLogger.info('Generated $totalTasks automatic tasks for event $eventId');

    return tasks;
  }

  /// 1. Bildung & Teilhabe IDs (must be applied for)
  Future<List<GeneratedTask>> _generateBildungTeilhabeTasks(
    int eventId,
    Set<CompletedTaskKey> completedTasks,
  ) async {
    final participants = await _participantRepo.getParticipantsByEvent(eventId);
    final tasks = <GeneratedTask>[];

    for (final participant in participants) {
      if (participant.bildungUndTeilhabe && participant.isActive) {
        if (!_isTaskCompleted(completedTasks, 'bildung_teilhabe', participant.id)) {
          tasks.add(GeneratedTask(
            taskType: 'bildung_teilhabe',
            referenceId: participant.id,
            title: '${participant.firstName} ${participant.lastName}',
            description: 'Bildung & Teilhabe beantragen',
            priority: 'high',
          ));
        }
      }
    }

    return tasks;
  }

  /// 2. Expense reimbursement (unreimbursed expenses)
  Future<List<GeneratedTask>> _generateExpenseReimbursementTasks(
    int eventId,
    Set<CompletedTaskKey> completedTasks,
  ) async {
    final expenses = await _expenseRepo.getExpensesByEvent(eventId);
    final tasks = <GeneratedTask>[];

    for (final expense in expenses) {
      if (!expense.reimbursed && expense.paidBy != null && expense.paidBy!.isNotEmpty) {
        if (!_isTaskCompleted(completedTasks, 'expense_reimbursement', expense.id)) {
          tasks.add(GeneratedTask(
            taskType: 'expense_reimbursement',
            referenceId: expense.id,
            title: expense.description ?? 'Ausgabe',
            description: '${expense.amount.toStringAsFixed(2)}€ - Bezahlt von: ${expense.paidBy}',
            priority: 'medium',
            metadata: {'amount': expense.amount},
          ));
        }
      }
    }

    return tasks;
  }

  /// 3. Outstanding payments (participants with outstanding payments)
  Future<List<GeneratedTask>> _generateOutstandingPaymentTasks(
    int eventId,
    Set<CompletedTaskKey> completedTasks,
  ) async {
    final participants = await _participantRepo.getParticipantsByEvent(eventId);
    final tasks = <GeneratedTask>[];

    for (final participant in participants) {
      if (!participant.isActive) continue;

      final finalPrice = participant.manualPriceOverride ?? participant.calculatedPrice;
      final totalPaid = await _paymentRepo.getTotalPaidByParticipant(participant.id);
      final outstanding = finalPrice - totalPaid;

      if (outstanding > 0.01) {
        if (!_isTaskCompleted(completedTasks, 'outstanding_payment', participant.id)) {
          tasks.add(GeneratedTask(
            taskType: 'outstanding_payment',
            referenceId: participant.id,
            title: '${participant.firstName} ${participant.lastName}',
            description: 'Ausstehend: ${outstanding.toStringAsFixed(2)}€ (von ${finalPrice.toStringAsFixed(2)}€)',
            priority: 'medium',
            metadata: {'amount': outstanding, 'finalPrice': finalPrice},
          ));
        }
      }
    }

    return tasks;
  }

  /// 4. Manual price overrides (check manual price adjustments)
  Future<List<GeneratedTask>> _generateManualPriceOverrideTasks(
    int eventId,
    Set<CompletedTaskKey> completedTasks,
  ) async {
    final participants = await _participantRepo.getParticipantsByEvent(eventId);
    final tasks = <GeneratedTask>[];

    for (final participant in participants) {
      if (participant.manualPriceOverride != null && participant.isActive) {
        if (!_isTaskCompleted(completedTasks, 'manual_price_override', participant.id)) {
          tasks.add(GeneratedTask(
            taskType: 'manual_price_override',
            referenceId: participant.id,
            title: '${participant.firstName} ${participant.lastName}',
            description: 'Manueller Preis: ${participant.manualPriceOverride!.toStringAsFixed(2)}€ (statt ${participant.calculatedPrice.toStringAsFixed(2)}€)',
            priority: 'low',
          ));
        }
      }
    }

    return tasks;
  }

  /// 5. Overdue payments (payments overdue based on event start date)
  Future<List<GeneratedTask>> _generateOverduePaymentTasks(
    int eventId,
    Event event,
    Set<CompletedTaskKey> completedTasks,
  ) async {
    final tasks = <GeneratedTask>[];

    // Payment deadline is 14 days before event start
    final paymentDeadline = event.startDate.subtract(const Duration(days: 14));

    if (DateTime.now().isAfter(paymentDeadline)) {
      // Get outstanding payments
      final outstandingTasks = await _generateOutstandingPaymentTasks(eventId, completedTasks);

      for (final task in outstandingTasks) {
        if (!_isTaskCompleted(completedTasks, 'overdue_payment', task.referenceId)) {
          tasks.add(GeneratedTask(
            taskType: 'overdue_payment',
            referenceId: task.referenceId,
            title: task.title,
            description: '${task.description} - ÜBERFÄLLIG!',
            priority: 'high',
            metadata: task.metadata,
          ));
        }
      }
    }

    return tasks;
  }

  /// 6. Income subsidy mismatch (role subsidy vs actual discounts)
  Future<List<GeneratedTask>> _generateIncomeSubsidyMismatchTasks(
    int eventId,
    Set<CompletedTaskKey> completedTasks,
  ) async {
    final tasks = <GeneratedTask>[];

    // Get active ruleset
    final ruleset = await _rulesetRepo.getActiveRulesetByEvent(eventId);
    if (ruleset == null) return tasks;

    // Get all roles with incomes
    final roles = await _roleRepo.getRolesByEvent(eventId);
    final incomes = await _incomeRepo.getIncomesByEvent(eventId);

    for (final role in roles) {
      // Sum up incomes for this role
      final roleIncomes = incomes.where((i) => i.description?.contains(role.displayName) ?? false);
      final totalSubsidy = roleIncomes.fold<double>(0, (sum, income) => sum + income.amount);

      if (totalSubsidy == 0) continue;

      // Calculate expected discounts
      final participants = await _participantRepo.getParticipantsByEvent(eventId);
      final roleParticipants = participants.where((p) => p.roleId == role.id && p.isActive);

      double expectedDiscounts = 0.0;
      // TODO: Calculate expected role discounts using PriceCalculatorService

      // Check for significant difference (> 1€)
      final difference = totalSubsidy - expectedDiscounts;
      if (difference.abs() > 1.0) {
        if (!_isTaskCompleted(completedTasks, 'income_subsidy_mismatch', role.id)) {
          final status = difference > 0 ? 'zu viel' : 'zu wenig';
          tasks.add(GeneratedTask(
            taskType: 'income_subsidy_mismatch',
            referenceId: role.id,
            title: 'Zuschuss-Differenz: ${role.displayName}',
            description: 'Zuschuss: ${totalSubsidy.toStringAsFixed(2)}€ | Rabatte: ${expectedDiscounts.toStringAsFixed(2)}€ | Differenz: ${difference.abs().toStringAsFixed(2)}€ ($status)',
            priority: 'medium',
            metadata: {
              'difference': difference,
              'totalSubsidy': totalSubsidy,
              'expectedDiscounts': expectedDiscounts,
            },
          ));
        }
      }
    }

    return tasks;
  }

  /// 7. Family subsidy mismatch (family subsidy vs family discounts)
  Future<List<GeneratedTask>> _generateFamilySubsidyMismatchTasks(
    int eventId,
    Set<CompletedTaskKey> completedTasks,
  ) async {
    final tasks = <GeneratedTask>[];

    // Get incomes with "Kinderzuschuss"
    final incomes = await _incomeRepo.getIncomesByEvent(eventId);
    final familySubsidyIncome = incomes
        .where((i) => i.description?.toLowerCase().contains('kinderzuschuss') ?? false)
        .fold<double>(0, (sum, income) => sum + income.amount);

    if (familySubsidyIncome == 0) return tasks;

    // TODO: Calculate expected family discounts
    final expectedFamilyDiscounts = 0.0;

    final difference = familySubsidyIncome - expectedFamilyDiscounts;
    if (difference.abs() > 1.0) {
      if (!_isTaskCompleted(completedTasks, 'family_subsidy_mismatch', eventId)) {
        final status = difference > 0 ? 'zu viel' : 'zu wenig';
        tasks.add(GeneratedTask(
          taskType: 'family_subsidy_mismatch',
          referenceId: eventId,
          title: 'Kinderzuschuss-Differenz (Familienrabatte)',
          description: 'Zuschuss: ${familySubsidyIncome.toStringAsFixed(2)}€ | Familienrabatte: ${expectedFamilyDiscounts.toStringAsFixed(2)}€ | Differenz: ${difference.abs().toStringAsFixed(2)}€ ($status)',
          priority: 'medium',
          metadata: {
            'difference': difference,
            'totalSubsidy': familySubsidyIncome,
            'expectedDiscounts': expectedFamilyDiscounts,
          },
        ));
      }
    }

    return tasks;
  }

  /// 8. Role count exceeded (too many participants assigned to a role)
  Future<List<GeneratedTask>> _generateRoleCountExceededTasks(
    int eventId,
    Set<CompletedTaskKey> completedTasks,
  ) async {
    final tasks = <GeneratedTask>[];

    // Get active ruleset
    final ruleset = await _rulesetRepo.getActiveRulesetByEvent(eventId);
    if (ruleset == null) return tasks;

    // TODO: Parse ruleset and check role counts
    // This requires parsing the YAML ruleset and checking max_count per role

    return tasks;
  }

  /// 9. Birthday gifts (children with birthdays during the event)
  Future<List<GeneratedTask>> _generateBirthdayGiftsTasks(
    int eventId,
    Event event,
    Set<CompletedTaskKey> completedTasks,
  ) async {
    final tasks = <GeneratedTask>[];
    final participants = await _participantRepo.getParticipantsByEvent(eventId);

    final birthdayChildren = <Map<String, dynamic>>[];

    for (final participant in participants) {
      if (!participant.isActive) continue;

      final birthMonth = participant.birthDate.month;
      final birthDay = participant.birthDate.day;

      try {
        final birthdayThisYear = DateTime(event.startDate.year, birthMonth, birthDay);

        if (birthdayThisYear.isAfter(event.startDate) &&
            birthdayThisYear.isBefore(event.endDate.add(const Duration(days: 1)))) {
          birthdayChildren.add({
            'name': '${participant.firstName} ${participant.lastName}',
            'date': birthdayThisYear,
          });
        }
      } catch (e) {
        // Invalid date (e.g., Feb 29 in non-leap year)
        AppLogger.warning('Invalid birthday date for participant ${participant.id}');
      }
    }

    if (birthdayChildren.isNotEmpty && !_isTaskCompleted(completedTasks, 'birthday_gifts', eventId)) {
      birthdayChildren.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

      final namesList = birthdayChildren
          .map((child) =>
              '${child['name']} (${_formatDate(child['date'] as DateTime)})')
          .join(', ');

      tasks.add(GeneratedTask(
        taskType: 'birthday_gifts',
        referenceId: eventId,
        title: 'Geschenke für ${birthdayChildren.length} Geburtstagskind(er)',
        description: 'Geburtstagskinder während der Freizeit: $namesList',
        priority: 'medium',
        metadata: {'count': birthdayChildren.length},
      ));
    }

    return tasks;
  }

  /// 10. Kitchen team gift (gift for kitchen team)
  Future<List<GeneratedTask>> _generateKitchenTeamGiftTasks(
    int eventId,
    Set<CompletedTaskKey> completedTasks,
  ) async {
    final tasks = <GeneratedTask>[];
    final roles = await _roleRepo.getRolesByEvent(eventId);

    // Find kitchen role (kueche, küche, kitchen)
    final kitchenRole = roles.firstWhere(
      (r) => ['kueche', 'küche', 'kitchen'].contains(r.name.toLowerCase()),
      orElse: () => roles.first, // dummy value, check below
    );

    if (kitchenRole.name.isEmpty) return tasks;

    final participants = await _participantRepo.getParticipantsByEvent(eventId);
    final kitchenParticipants = participants.where((p) => p.roleId == kitchenRole.id && p.isActive).toList();

    if (kitchenParticipants.isNotEmpty && !_isTaskCompleted(completedTasks, 'kitchen_team_gift', eventId)) {
      final namesList = kitchenParticipants.map((p) => '${p.firstName} ${p.lastName}').join(', ');

      tasks.add(GeneratedTask(
        taskType: 'kitchen_team_gift',
        referenceId: eventId,
        title: 'Geschenk für das Küchenteam (${kitchenParticipants.length} Personen)',
        description: 'Küchenteam-Mitglieder: $namesList',
        priority: 'low',
        metadata: {'count': kitchenParticipants.length},
      ));
    }

    return tasks;
  }

  /// 11. Familienfreizeit check (check for non-members)
  Future<List<GeneratedTask>> _generateFamilienfreizeitCheckTasks(
    int eventId,
    Event event,
    Set<CompletedTaskKey> completedTasks,
  ) async {
    final tasks = <GeneratedTask>[];

    if (event.eventType?.toLowerCase() == 'familienfreizeit') {
      if (!_isTaskCompleted(completedTasks, 'familienfreizeit_non_member_check', eventId)) {
        tasks.add(GeneratedTask(
          taskType: 'familienfreizeit_non_member_check',
          referenceId: eventId,
          title: 'Kinder von Nicht-Gemeindemitgliedern prüfen',
          description: 'Prüfen ob Kinder von nicht-Gemeindemitgliedern mitfahren. Zuschüsse werden nur für Gemeindemitglieder gewährt.',
          priority: 'medium',
        ));
      }
    }

    return tasks;
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  bool _isTaskCompleted(Set<CompletedTaskKey> completedTasks, String taskType, int referenceId) {
    return completedTasks.contains(CompletedTaskKey(taskType, referenceId));
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.';
  }
}
