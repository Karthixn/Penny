import 'api_client.dart';

class RemindersApi {
  final ApiClient _client;

  RemindersApi(this._client);

  Future<List<dynamic>> list() async {
    final response = await _client.dio.get('/reminders');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final response = await _client.dio.post('/reminders', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getOne(String id) async {
    final response = await _client.dio.get('/reminders/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) async {
    final response = await _client.dio.patch('/reminders/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> complete(String id) async {
    final response = await _client.dio.patch('/reminders/$id/complete');
    return response.data as Map<String, dynamic>;
  }

  Future<void> delete(String id) async {
    await _client.dio.delete('/reminders/$id');
  }
}
