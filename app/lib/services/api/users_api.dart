import 'api_client.dart';

class UsersApi {
  final ApiClient _client;

  UsersApi(this._client);

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _client.dio.get('/users/me');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await _client.dio.patch('/users/me', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteAccount() async {
    await _client.dio.delete('/users/me');
  }
}
