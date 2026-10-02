import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../services/api/settlements_api.dart';

final settlementsApiProvider = Provider(
  (ref) => SettlementsApi(ref.read(apiClientProvider)),
);

final settlementOptimizeProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, String groupId) async {
  final api = ref.read(settlementsApiProvider);
  final result = await api.optimize(groupId);
  return result.cast<Map<String, dynamic>>();
});
