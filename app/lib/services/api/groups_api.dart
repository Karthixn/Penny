import 'api_client.dart';

class GroupsApi {
  final ApiClient _client;

  GroupsApi(this._client);

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final response = await _client.dio.post('/groups', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> list() async {
    final response = await _client.dio.get('/groups');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getOne(String id) async {
    final response = await _client.dio.get('/groups/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) async {
    final response = await _client.dio.patch('/groups/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> archive(String id) async {
    await _client.dio.delete('/groups/$id');
  }

  Future<List<dynamic>> getBalances(String id) async {
    final response = await _client.dio.get('/groups/$id/balances');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createInvite(String id) async {
    final response = await _client.dio.post('/groups/$id/invite');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> joinByInvite(String code) async {
    final response = await _client.dio.post('/groups/join/$code');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addMember(String groupId, String userId) async {
    final response = await _client.dio.post('/groups/$groupId/members', data: {'userId': userId});
    return response.data as Map<String, dynamic>;
  }

  Future<void> removeMember(String groupId, String memberId) async {
    await _client.dio.delete('/groups/$groupId/members/$memberId');
  }
}
