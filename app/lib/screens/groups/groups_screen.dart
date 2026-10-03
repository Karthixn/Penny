import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/penny_loading.dart';
import '../../providers/groups_provider.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Groups',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
        ),
        actions: [
          IconButton(
            tooltip: 'Archived Groups',
            icon: const Icon(Icons.archive_outlined),
            onPressed: () => _showArchivedGroups(context, ref),
          ),
          IconButton(
            tooltip: 'Join with Code',
            icon: const Icon(Icons.group_add_outlined),
            onPressed: () => _showJoinDialog(context, ref),
          ),
          IconButton(
            tooltip: 'Create Group',
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: state.isLoading && state.groups.isEmpty
          ? const Center(child: PennyLoadingIndicator(size: 48, message: 'Loading groups...'))
          : state.groups.isEmpty
              ? _buildEmptyState(context, ref)
              : RefreshIndicator(
                  onRefresh: () => ref.read(groupListProvider.notifier).loadGroups(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: state.groups.length,
                    itemBuilder: (context, index) {
                      final group = state.groups[index];
                      final members = (group['members'] as List?) ?? [];
                      final expenseCount = (group['_count'] as Map?)?['expenses'] ?? 0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => context.push('/groups/${group['id']}'),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      group['emoji'] ?? '👥',
                                      style: const TextStyle(fontSize: 26),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          group['name'] as String,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${members.length} members · $expenseCount expenses',
                                          style: const TextStyle(
                                            color: AppColors.textTertiary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.textTertiary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFF2994A), // Warm accent matching user reference
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.groups_2_outlined,
                size: 50,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No groups yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a group to split bills with friends, roommates, or travel buddies.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showCreateDialog(context, ref),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Create a Group', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(220, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showJoinDialog(context, ref),
              icon: const Icon(Icons.vpn_key_outlined, size: 18, color: AppColors.primary),
              label: const Text(
                'Join with Invite Code',
                style: TextStyle(color: AppColors.primary, fontSize: 15),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(220, 48),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String selectedEmoji = '👥';

    final emojis = [
      {'emoji': '👥', 'label': 'Friends'},
      {'emoji': '🏠', 'label': 'Home'},
      {'emoji': '✈️', 'label': 'Trip'},
      {'emoji': '🍕', 'label': 'Food'},
      {'emoji': '🍻', 'label': 'Party'},
      {'emoji': '🎓', 'label': 'College'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Create New Group',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textTertiary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Group Category',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: emojis.map((item) {
                    final isSelected = selectedEmoji == item['emoji'];
                    return ChoiceChip(
                      selected: isSelected,
                      label: Text('${item['emoji']} ${item['label']}'),
                      selectedColor: AppColors.primary.withValues(alpha: 0.25),
                      backgroundColor: AppColors.background,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                      onSelected: (_) {
                        setModalState(() => selectedEmoji = item['emoji']!);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'e.g. 3 Idiots, Flat 402, Goa Trip',
                    prefixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      child: Text(selectedEmoji, style: const TextStyle(fontSize: 20)),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  onSubmitted: (_) {
                    final name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      ref.read(groupListProvider.notifier).createGroup(name, selectedEmoji);
                      Navigator.pop(ctx);
                    }
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      ref.read(groupListProvider.notifier).createGroup(name, selectedEmoji);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Group "$name" created!'),
                          backgroundColor: AppColors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Create Group', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showJoinDialog(BuildContext context, WidgetRef ref) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Join Group', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the 8-character invite code shared by the group admin:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                color: AppColors.primary,
                letterSpacing: 3,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 7F3B92E1',
                hintStyle: TextStyle(letterSpacing: 2, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                prefixIcon: const Icon(Icons.vpn_key_outlined, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isNotEmpty) {
                try {
                  await ref.read(groupsApiProvider).joinByInvite(code);
                  ref.read(groupListProvider.notifier).loadGroups();
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Successfully joined group!'),
                        backgroundColor: AppColors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid or expired invite code'),
                        backgroundColor: AppColors.red,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Join Group'),
          ),
        ],
      ),
    );
  }

  void _showArchivedGroups(BuildContext context, WidgetRef ref) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: PennyLoadingIndicator(size: 44, message: 'Loading archived groups...')),
      );

      final list = await ref.read(groupsApiProvider).list(archived: true);
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      final archivedGroups = list.cast<Map<String, dynamic>>();

      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E1E24),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Archived Groups',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${archivedGroups.length}',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (archivedGroups.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No archived groups', style: TextStyle(color: Colors.white38)),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: archivedGroups.length,
                    separatorBuilder: (_, _) => const Divider(color: Colors.white12, height: 1),
                    itemBuilder: (_, idx) {
                      final g = archivedGroups[idx];
                      final gid = (g['id'] ?? '') as String;
                      final name = (g['name'] ?? 'Group') as String;
                      final emoji = (g['emoji'] ?? '👥') as String;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF282830),
                          child: Text(emoji, style: const TextStyle(fontSize: 18)),
                        ),
                        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        trailing: TextButton.icon(
                          icon: const Icon(Icons.unarchive_outlined, size: 16, color: Color(0xFFF2994A)),
                          label: const Text('Restore', style: TextStyle(color: Color(0xFFF2994A), fontSize: 13, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await ref.read(groupsApiProvider).unarchive(gid);
                            ref.read(groupListProvider.notifier).loadGroups();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Restored "$name" to active groups!')),
                              );
                            }
                          },
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          context.push('/groups/$gid');
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load archived groups: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }
}
