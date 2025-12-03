import 'package:flutter/material.dart';

/// Participant SpeedDial Widget
///
/// Ein FloatingActionButton der sich zu einem Menü mit Participant-Aktionen öffnet
class ParticipantSpeedDial extends StatefulWidget {
  final VoidCallback onAdd;
  final VoidCallback onImport;
  final VoidCallback onExport;

  const ParticipantSpeedDial({
    super.key,
    required this.onAdd,
    required this.onImport,
    required this.onExport,
  });

  @override
  State<ParticipantSpeedDial> createState() => _ParticipantSpeedDialState();
}

class _ParticipantSpeedDialState extends State<ParticipantSpeedDial>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _close() {
    if (_isOpen) {
      setState(() {
        _isOpen = false;
        _animationController.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Export Button
        ScaleTransition(
          scale: _animation,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Export',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.small(
                  heroTag: 'export_participants_fab',
                  onPressed: () {
                    _close();
                    widget.onExport();
                  },
                  backgroundColor: Colors.green.shade700,
                  child: const Icon(Icons.download, size: 20),
                ),
              ],
            ),
          ),
        ),

        // Import Button
        ScaleTransition(
          scale: _animation,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Import',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.small(
                  heroTag: 'import_participants_fab',
                  onPressed: () {
                    _close();
                    widget.onImport();
                  },
                  backgroundColor: Colors.orange.shade700,
                  child: const Icon(Icons.upload_file, size: 20),
                ),
              ],
            ),
          ),
        ),

        // Main Button (Add)
        FloatingActionButton.extended(
          heroTag: 'main_participants_fab',
          onPressed: _isOpen ? _toggle : widget.onAdd,
          icon: AnimatedRotation(
            turns: _animation.value * 0.125,
            duration: const Duration(milliseconds: 250),
            child: Icon(_isOpen ? Icons.close : Icons.person_add),
          ),
          label: Text(_isOpen ? 'Schließen' : 'Teilnehmer'),
        ),
      ],
    );
  }
}
