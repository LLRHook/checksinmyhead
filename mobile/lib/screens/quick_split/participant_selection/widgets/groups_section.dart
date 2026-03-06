// Billington: Privacy-first receipt spliting
//     Copyright (C) 2025  Kruski Ko.
//     Email us: checkmateapp@duck.com

//     This program is free software: you can redistribute it and/or modify
//     it under the terms of the GNU General Public License as published by
//     the Free Software Foundation, either version 3 of the License, or
//     (at your option) any later version.

//     This program is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//     GNU General Public License for more details.

//     You should have received a copy of the GNU General Public License
//     along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:checks_frontend/config/dialogUtils/dialog_utils.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';
import 'package:checks_frontend/screens/quick_split/participant_selection/models/group_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Displays saved and suggested people groups as tappable cards
/// in the "Groups" tab of the participant selection sheet.
class GroupsSection extends StatelessWidget {
  final List<PeopleGroupWithMembers> savedGroups;
  final List<PeopleGroupWithMembers> suggestedGroups;
  final ValueChanged<PeopleGroupWithMembers> onGroupTapped;
  final Future<void> Function(int groupId, String name) onGroupSaved;
  final Future<void> Function(int groupId) onGroupDeleted;
  final Future<void> Function(int groupId, String newName) onGroupRenamed;
  final Future<void> Function(String name, List<Person> members) onCreateGroup;
  final List<Person> recentPeople;

  const GroupsSection({
    super.key,
    required this.savedGroups,
    required this.suggestedGroups,
    required this.onGroupTapped,
    required this.onGroupSaved,
    required this.onGroupDeleted,
    required this.onGroupRenamed,
    required this.onCreateGroup,
    required this.recentPeople,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurface.withValues(alpha: 0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Your Groups" header with optional New button
        _buildSavedHeader(labelColor, textTheme, colorScheme, context),
        const SizedBox(height: 10),

        // Saved group cards or empty state
        if (savedGroups.isEmpty)
          _buildEmptyState(context)
        else
          ...savedGroups.map(
            (g) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _GroupCard(
                groupWithMembers: g,
                isSuggested: false,
                onTap: () => onGroupTapped(g),
                onDelete: () => onGroupDeleted(g.group.id),
                onRename: (newName) => onGroupRenamed(g.group.id, newName),
              ),
            ),
          ),

        // Suggested section
        if (suggestedGroups.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSuggestedHeader(labelColor, textTheme, colorScheme),
          const SizedBox(height: 10),
          ...suggestedGroups.map(
            (g) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _GroupCard(
                groupWithMembers: g,
                isSuggested: true,
                onTap: () => onGroupTapped(g),
                onSave: (name) => onGroupSaved(g.group.id, name),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Header row: icon + "Your Groups" + "New" button
  Widget _buildSavedHeader(
    Color labelColor,
    TextTheme textTheme,
    ColorScheme colorScheme,
    BuildContext context,
  ) {
    return Row(
      children: [
        ExcludeSemantics(
          child: Icon(Icons.group, size: 18, color: labelColor),
        ),
        const SizedBox(width: 8),
        Text(
          'Your Groups',
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        if (savedGroups.length < 10)
          _CreateGroupButton(
            onTap: () => _showCreateGroupSheet(context),
          ),
      ],
    );
  }

  /// Header row for suggested groups (more muted)
  Widget _buildSuggestedHeader(
    Color labelColor,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        ExcludeSemantics(
          child: Icon(Icons.auto_awesome, size: 18, color: labelColor),
        ),
        const SizedBox(width: 8),
        Text(
          'Suggested',
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  /// Empty state when no saved groups exist
  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withValues(alpha: 0.15)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.group_add,
            size: 32,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            'No groups yet',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create a group to quickly add people',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.35),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateGroupSheet(
        recentPeople: recentPeople,
        onCreateGroup: onCreateGroup,
      ),
    );
  }
}

/// A card representing a single group (saved or suggested)
class _GroupCard extends StatelessWidget {
  final PeopleGroupWithMembers groupWithMembers;
  final bool isSuggested;
  final VoidCallback onTap;
  final Future<void> Function(String name)? onSave;
  final Future<void> Function()? onDelete;
  final Future<void> Function(String newName)? onRename;

  const _GroupCard({
    required this.groupWithMembers,
    required this.isSuggested,
    required this.onTap,
    this.onSave,
    this.onDelete,
    this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final group = groupWithMembers.group;
    final members = groupWithMembers.members;
    final groupColor = Color(group.colorValue);

    final bgOpacity = isDark ? 0.15 : 0.08;
    final borderOpacity = isDark ? 0.3 : 0.2;

    final nameColor = isDark
        ? ColorUtils.getLightenedColor(groupColor, 0.7)
        : ColorUtils.getDarkenedColor(groupColor, 0.3);

    final memberNamesText = members.map((m) => m.name).join(', ');

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      onLongPress: isSuggested
          ? null
          : () => _showOptionsSheet(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: groupColor.withValues(alpha: bgOpacity),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSuggested
                ? groupColor.withValues(alpha: borderOpacity * 0.7)
                : groupColor.withValues(alpha: borderOpacity),
            width: 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group name
                  Text(
                    isSuggested
                        ? memberNamesText
                        : group.name,
                    style: TextStyle(
                      fontWeight: isSuggested ? FontWeight.w500 : FontWeight.w600,
                      fontSize: 14,
                      color: nameColor,
                      shadows: isDark
                          ? [
                              const Shadow(
                                color: Colors.black,
                                offset: Offset(0, 1),
                                blurRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isSuggested) ...[
                    const SizedBox(height: 2),
                    // Member names subtitle
                    Text(
                      memberNamesText,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Member color dots
                  _buildMemberDots(members),
                ],
              ),
            ),
            if (isSuggested && onSave != null)
              _SaveButton(
                onTap: () => _promptSaveName(context),
              ),
          ],
        ),
      ),
    );
  }

  /// Row of small colored circles representing members
  Widget _buildMemberDots(List<Person> members) {
    final displayMembers = members.take(5).toList();
    final remaining = members.length - displayMembers.length;

    return Row(
      children: [
        ...displayMembers.map(
          (m) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: m.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        if (remaining > 0)
          Text(
            '+$remaining',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
      ],
    );
  }

  /// Shows rename/delete options for a saved group
  void _showOptionsSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Icons.edit, color: colorScheme.primary),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.pop(ctx);
                  _promptRename(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
                title: Text(
                  'Delete',
                  style: TextStyle(color: Colors.red.shade400),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Prompt to rename a saved group
  void _promptRename(BuildContext context) {
    final controller = TextEditingController(text: groupWithMembers.group.name);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Rename Group',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Group name',
                filled: true,
                fillColor: isDark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
              ),
              onSubmitted: (value) {
                final name = value.trim();
                if (name.isNotEmpty && onRename != null) {
                  Navigator.pop(ctx);
                  onRename!(name);
                }
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final name = controller.text.trim();
                  if (name.isNotEmpty && onRename != null) {
                    Navigator.pop(ctx);
                    onRename!(name);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Rename'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Confirm deletion of a saved group
  void _confirmDelete(BuildContext context) {
    AppDialogs.showConfirmationDialog(
      context: context,
      title: 'Delete group?',
      message:
          'This will permanently delete "${groupWithMembers.group.name}". This cannot be undone.',
      cancelText: 'Cancel',
      confirmText: 'Delete',
      isDestructive: true,
    ).then((confirmed) {
      if (confirmed == true && onDelete != null) {
        onDelete!();
      }
    });
  }

  /// Prompt to name and save a suggested group
  void _promptSaveName(BuildContext context) {
    final controller = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Save Group',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter group name',
                filled: true,
                fillColor: isDark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
              ),
              onSubmitted: (value) {
                final name = value.trim();
                if (name.isNotEmpty && onSave != null) {
                  Navigator.pop(ctx);
                  onSave!(name);
                }
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final name = controller.text.trim();
                  if (name.isNotEmpty && onSave != null) {
                    Navigator.pop(ctx);
                    onSave!(name);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small outlined button with "+" icon and "New" text
class _CreateGroupButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateGroupButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(
        Icons.add,
        size: 18,
        color: colorScheme.primary,
      ),
      label: Text(
        'New',
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        side: BorderSide(
          color: colorScheme.primary.withValues(
            alpha: isDark ? 0.5 : 0.3,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

/// Bottom sheet for creating a new group from scratch
class _CreateGroupSheet extends StatefulWidget {
  final List<Person> recentPeople;
  final Future<void> Function(String name, List<Person> members) onCreateGroup;

  const _CreateGroupSheet({
    required this.recentPeople,
    required this.onCreateGroup,
  });

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _nameController = TextEditingController();
  final _selectedPeople = <Person>{};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      _nameController.text.trim().isNotEmpty && _selectedPeople.length >= 2;

  void _togglePerson(Person person) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedPeople.contains(person)) {
        _selectedPeople.remove(person);
      } else {
        _selectedPeople.add(person);
      }
    });
  }

  Future<void> _createGroup() async {
    if (!_canCreate) return;
    HapticFeedback.mediumImpact();

    final name = _nameController.text.trim();
    final members = _selectedPeople.toList();

    Navigator.pop(context);

    await widget.onCreateGroup(name, members);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Group "$name" created'),
          behavior: SnackBarBehavior.floating,
          width: 280,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Text(
              'Create Group',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            // Group name field
            TextField(
              controller: _nameController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Group name',
                filled: true,
                fillColor: isDark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                hintStyle: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              style: TextStyle(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            // People selection label
            if (widget.recentPeople.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select people (${_selectedPeople.length} selected)',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Selectable chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.recentPeople.map((person) {
                  final isSelected = _selectedPeople.contains(person);
                  return _buildPersonChip(
                    person,
                    isSelected,
                    isDark,
                    colorScheme,
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
            // Create button
            SizedBox(
              width: double.infinity,
              child: AnimatedOpacity(
                opacity: _canCreate ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: ElevatedButton(
                  onPressed: _canCreate ? _createGroup : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    disabledBackgroundColor:
                        colorScheme.primary.withValues(alpha: 0.3),
                    disabledForegroundColor:
                        colorScheme.onPrimary.withValues(alpha: 0.5),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Create Group'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a selectable person chip matching RecentPeopleSection styling
  Widget _buildPersonChip(
    Person person,
    bool isSelected,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    final unselectedBgColor =
        isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50;
    final unselectedBorderColor =
        isDark
            ? colorScheme.outline.withValues(alpha: 0.2)
            : Colors.grey.shade300;
    final unselectedTextColor =
        isDark
            ? colorScheme.onSurface.withValues(alpha: 0.7)
            : Colors.grey.shade700;
    final selectedTextColor = isDark
        ? ColorUtils.getLightenedColor(person.color, 0.8)
        : ColorUtils.getDarkenedColor(person.color, 0.3);
    final selectedBgOpacity = isDark ? 0.25 : 0.12;

    return InkWell(
      onTap: () => _togglePerson(person),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? person.color.withValues(alpha: selectedBgOpacity)
              : unselectedBgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? person.color : unselectedBorderColor,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected && isDark
              ? [
                  BoxShadow(
                    color: person.color.withValues(alpha: 0.3),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: isSelected ? 8 : 0,
              height: isSelected ? 8 : 0,
              margin: EdgeInsets.only(right: isSelected ? 6 : 0),
              decoration: BoxDecoration(
                color: isDark
                    ? ColorUtils.getLightenedColor(person.color, 0.3)
                    : person.color,
                shape: BoxShape.circle,
              ),
            ),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                color: isSelected ? selectedTextColor : unselectedTextColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
                shadows: isSelected && isDark
                    ? [
                        const Shadow(
                          color: Colors.black,
                          offset: Offset(0, 1),
                          blurRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Text(person.name),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small outlined "Save" button for suggested group cards
class _SaveButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SaveButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        side: BorderSide(
          color: colorScheme.primary.withValues(
            alpha: isDark ? 0.5 : 0.3,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        'Save',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}
