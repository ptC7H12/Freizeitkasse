import 'package:flutter/material.dart';

/// Adaptive List Item Widget
///
/// Desktop: ListTile mit Trailing-Buttons (zeigen sich beim Hover)
/// Mobile: Dismissible mit Swipe-to-Action (Rechts = Bearbeiten, Links = Löschen)
class AdaptiveListItem extends StatefulWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;
  final String deleteConfirmMessage;

  const AdaptiveListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.deleteConfirmMessage = 'Wirklich löschen?',
  });

  @override
  State<AdaptiveListItem> createState() => _AdaptiveListItemState();
}

class _AdaptiveListItemState extends State<AdaptiveListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    if (isDesktop) {
      return _buildDesktopListItem();
    } else {
      return _buildMobileListItem();
    }
  }

  /// Desktop: ListTile mit Trailing-Buttons (zeigen sich beim Hover)
  Widget _buildDesktopListItem() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        elevation: _isHovered ? 4 : 1,
        child: ListTile(
          leading: widget.leading,
          title: widget.title,
          subtitle: widget.subtitle,
          onTap: widget.onTap,
          trailing: AnimatedOpacity(
            opacity: _isHovered ? 1.0 : 0.3,
            duration: const Duration(milliseconds: 200),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bearbeiten-Button
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Bearbeiten',
                  color: Colors.blue.shade600,
                  onPressed: widget.onEdit,
                ),
                const SizedBox(width: 4),
                // Löschen-Button
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Löschen',
                  color: Colors.red.shade400,
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Mobile: Dismissible mit Swipe-to-Action
  Widget _buildMobileListItem() {
    return Dismissible(
      key: ValueKey('${widget.hashCode}_${DateTime.now().millisecondsSinceEpoch}'),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Nach rechts wischen = Bearbeiten
          widget.onEdit();
          return false; // Nicht entfernen
        } else {
          // Nach links wischen = Löschen
          return await _confirmDelete(context);
        }
      },
      background: _buildSwipeBackground(
        alignment: Alignment.centerLeft,
        color: Colors.blue.shade600,
        icon: Icons.edit,
        label: 'Bearbeiten',
      ),
      secondaryBackground: _buildSwipeBackground(
        alignment: Alignment.centerRight,
        color: Colors.red.shade600,
        icon: Icons.delete,
        label: 'Löschen',
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          leading: widget.leading,
          title: widget.title,
          subtitle: widget.subtitle,
          onTap: widget.onTap,
        ),
      ),
    );
  }

  Widget _buildSwipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    final isLeft = alignment == Alignment.centerLeft;

    return Container(
      color: color,
      alignment: alignment,
      padding: EdgeInsets.only(
        left: isLeft ? 20 : 0,
        right: isLeft ? 0 : 20,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLeft) ...[
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ] else ...[
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white, size: 28),
          ],
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Löschen bestätigen'),
        content: Text(widget.deleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade700,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      await widget.onDelete();
    }

    return confirmed;
  }
}
