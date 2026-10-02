import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../services/api/groups_api.dart';

final groupsApiProvider = Provider(
  (ref) => GroupsApi(ref.read(apiClientProvider)),
);

class GroupListState {
  final List<Map<String, dynamic>> groups;
  final bool isLoading;
  final String? error;

  const GroupListState({
    this.groups = const [],
    this.isLoading = false,
    this.error,
  });
}

class GroupListNotifier extends Notifier<GroupListState> {
  @override
  GroupListState build() {
    Future.microtask(() => loadGroups());
    return const GroupListState(isLoading: true);
  }

  Future<void> loadGroups() async {
    state = GroupListState(groups: state.groups, isLoading: true);
    try {
      final result = await ref.read(groupsApiProvider).list();
      final List<Map<String, dynamic>> list = [];
      for (final item in result) {
        if (item is Map) {
          list.add(Map<String, dynamic>.from(item));
        }
      }
      state = GroupListState(groups: list, isLoading: false);
    } catch (e) {
      state = GroupListState(
        groups: state.groups,
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> createGroup(String name, String? emoji) async {
    final payload = <String, dynamic>{'name': name};
    if (emoji != null) payload['emoji'] = emoji;
    await ref.read(groupsApiProvider).create(payload);
    await loadGroups();
  }
}

final groupListProvider = NotifierProvider<GroupListNotifier, GroupListState>(
  GroupListNotifier.new,
);

class GroupDetailState {
  final Map<String, dynamic>? group;
  final List<Map<String, dynamic>> balances;
  final bool isLoading;

  const GroupDetailState({
    this.group,
    this.balances = const [],
    this.isLoading = false,
  });
}

final groupDetailProvider = FutureProvider.family<GroupDetailState, String>(
  (ref, groupId) async {
    final api = ref.read(groupsApiProvider);
    final results = await Future.wait([
      api.getOne(groupId),
      api.getBalances(groupId),
    ]);
    return GroupDetailState(
      group: results[0] as Map<String, dynamic>,
      balances: (results[1] as List).cast<Map<String, dynamic>>(),
    );
  },
);
