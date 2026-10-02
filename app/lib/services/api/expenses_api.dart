import 'api_client.dart';

class ExpensesApi {
  final ApiClient _client;

  ExpensesApi(this._client);

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final response = await _client.dio.post('/expenses', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> list({
    String? groupId,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.dio.get('/expenses', queryParameters: {
      'page': page,
      'limit': limit,
      'groupId': ?groupId,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getOne(String id) async {
    final response = await _client.dio.get('/expenses/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) async {
    final response = await _client.dio.patch('/expenses/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> delete(String id) async {
    await _client.dio.delete('/expenses/$id');
  }

  Future<Map<String, dynamic>> getStats(int year, int month) async {
    final response = await _client.dio.get('/expenses/stats', queryParameters: {
      'year': year,
      'month': month,
    });
    return response.data as Map<String, dynamic>;
  }
}
