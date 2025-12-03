import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/task_provider.dart';
import '../../providers/current_event_provider.dart';
import '../../providers/participant_provider.dart';
import '../../utils/constants.dart';
import '../../utils/route_helpers.dart';
import '../../extensions/context_extensions.dart';
import '../../widgets/responsive_form_container.dart';

/// Task Form Screen (Create/Edit)
class TaskFormScreen extends ConsumerStatefulWidget {
  final int? taskId; // null = Create, sonst Edit

  const TaskFormScreen({
    super.key,
    this.taskId,
  });

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _dueDate;
  late String _priority;
  late String _status;
  int? _assignedTo;

  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _dueDate = DateTime.now().add(const Duration(days: 7));
    _priority = 'medium';
    _status = 'pending';
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    if (widget.taskId != null) {
      // Edit-Modus: Lade Task-Daten
      final repository = ref.read(taskRepositoryProvider);
      final task = await repository.getTaskById(widget.taskId!);

      if (task != null && mounted) {
        setState(() {
          _titleController.text = task.title;
          _descriptionController.text = task.description ?? '';
          _dueDate = task.dueDate ?? DateTime.now().add(const Duration(days: 7));
          _priority = task.priority;
          _status = task.status;
          _assignedTo = task.assignedTo;
          _isInitialized = true;
        });
      }
    } else {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(taskRepositoryProvider);
      final currentEvent = ref.read(currentEventProvider);

      if (currentEvent == null) {
        throw Exception('Kein Event ausgewählt');
      }

      if (widget.taskId == null) {
        // Create
        await repository.createTask(
          eventId: currentEvent.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          dueDate: _dueDate,
          priority: _priority,
          status: _status,
          assignedTo: _assignedTo,
        );
      } else {
        // Update
        await repository.updateTask(
          id: widget.taskId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          dueDate: _dueDate,
          priority: _priority,
          status: _status,
          assignedTo: _assignedTo,
        );
      }

      if (mounted) {
        context.showSuccess(
          widget.taskId == null ? 'Aufgabe erstellt' : 'Aufgabe aktualisiert',
        );
        RouteHelpers.pop(context);
      }
    } catch (e) {
      if (mounted) {
        context.showError('Fehler: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteTask() async {
    if (widget.taskId == null) return;

    final confirmed = await context.showConfirm(
      title: 'Aufgabe löschen?',
      message: 'Diese Aktion kann nicht rückgängig gemacht werden.',
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(taskRepositoryProvider);
      await repository.deleteTask(widget.taskId!);

      if (mounted) {
        context.showSuccess('Aufgabe gelöscht');
        RouteHelpers.pop(context);
      }
    } catch (e) {
      if (mounted) {
        context.showError('Fehler beim Löschen: $e');
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
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.taskId == null ? 'Neue Aufgabe' : 'Aufgabe bearbeiten'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final participantsAsync = ref.watch(participantsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskId == null ? 'Neue Aufgabe' : 'Aufgabe bearbeiten'),
      ),
      body: ResponsiveFormContainer(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: AppConstants.paddingAll16,
            children: [
              // Titel
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titel *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Titel erforderlich';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),

              const SizedBox(height: AppConstants.spacing),

              // Beschreibung
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                textInputAction: TextInputAction.newline,
              ),

              const SizedBox(height: AppConstants.spacing),

              // Priorität
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priorität',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag),
                ),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Niedrig')),
                  DropdownMenuItem(value: 'medium', child: Text('Mittel')),
                  DropdownMenuItem(value: 'high', child: Text('Hoch')),
                ],
                onChanged: (value) {
                  setState(() {
                    _priority = value!;
                  });
                },
              ),

              const SizedBox(height: AppConstants.spacing),

              // Status
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.check_circle),
                ),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Offen')),
                  DropdownMenuItem(value: 'in_progress', child: Text('In Bearbeitung')),
                  DropdownMenuItem(value: 'completed', child: Text('Erledigt')),
                ],
                onChanged: (value) {
                  setState(() {
                    _status = value!;
                  });
                },
              ),

              const SizedBox(height: AppConstants.spacing),

              // Fälligkeitsdatum
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _dueDate = picked;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fälligkeitsdatum',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd.MM.yyyy', 'de_DE').format(_dueDate)),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppConstants.spacing),

              // Zugewiesen an
              participantsAsync.when(
                data: (participants) => DropdownButtonFormField<int?>(
                  initialValue: _assignedTo,
                  decoration: const InputDecoration(
                    labelText: 'Zugewiesen an',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Nicht zugewiesen')),
                    ...participants.map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.firstName} ${p.lastName}'),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _assignedTo = value;
                    });
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Fehler beim Laden der Teilnehmer'),
              ),

              const SizedBox(height: AppConstants.spacingXL),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Löschen (nur bei Edit-Mode)
                  if (widget.taskId != null)
                    TextButton.icon(
                      onPressed: _isLoading ? null : _deleteTask,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Löschen'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  // Abbrechen + Speichern
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: _isLoading ? null : () => RouteHelpers.pop(context),
                        child: const Text('Abbrechen'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _isLoading ? null : _saveTask,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: Text(widget.taskId == null ? 'Erstellen' : 'Speichern'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
