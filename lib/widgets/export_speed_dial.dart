import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Export SpeedDial Widget
///
/// Ein FloatingActionButton der sich zu einem Menü mit Export-Optionen öffnet
class ExportSpeedDial extends StatefulWidget {
  final Future<void> Function() onPdfExport;
  final Future<void> Function() onExcelExport;
  final Color backgroundColor;

  const ExportSpeedDial({
    super.key,
    required this.onPdfExport,
    required this.onExcelExport,
    this.backgroundColor = const Color(0xFF4CAF50),
  });

  @override
  State<ExportSpeedDial> createState() => _ExportSpeedDialState();
}

class _ExportSpeedDialState extends State<ExportSpeedDial>
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
        // PDF Export Button
        ScaleTransition(
          scale: _animation,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Label
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
                    'Als PDF',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Button
                FloatingActionButton.small(
                  heroTag: 'pdf_export_fab',
                  onPressed: () async {
                    _close();
                    await widget.onPdfExport();
                  },
                  backgroundColor: Colors.red.shade700,
                  child: const Icon(Icons.picture_as_pdf, size: 20),
                ),
              ],
            ),
          ),
        ),

        // Excel Export Button
        ScaleTransition(
          scale: _animation,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Label
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
                    'Als Excel',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Button
                FloatingActionButton.small(
                  heroTag: 'excel_export_fab',
                  onPressed: () async {
                    _close();
                    await widget.onExcelExport();
                  },
                  backgroundColor: Colors.green.shade700,
                  child: const Icon(Icons.table_chart, size: 20),
                ),
              ],
            ),
          ),
        ),

        // Main Button
        FloatingActionButton.extended(
          heroTag: 'main_export_fab',
          onPressed: _toggle,
          icon: AnimatedRotation(
            turns: _animation.value * 0.125, // 45 Grad Rotation
            duration: const Duration(milliseconds: 250),
            child: Icon(_isOpen ? Icons.close : Icons.download),
          ),
          label: const Text('Export'),
          backgroundColor: widget.backgroundColor,
        ),
      ],
    );
  }
}
