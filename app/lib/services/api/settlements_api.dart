import 'api_client.dart';

class SettlementsApi {
  final ApiClient _client;

  SettlementsApi(this._client);

  Future<List<dynamic>> optimize(String groupId) async {
    final response = await _client.dio.get('/settlements/optimize', queryParameters: {
      'groupId': groupId,
    });
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> list(String groupId) async {
    final response = await _client.dio.get('/settlements', queryParameters: {
      'groupId': groupId,
    });
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final response = await _client.dio.post('/settlements', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> settle(String id) async {
    final response = await _client.dio.patch('/settlements/$id/settle');
    return response.data as Map<String, dynamic>;
  }

  Future<void> delete(String id) async {
    await _client.dio.delete('/settlements/$id');
  }

  Future<Map<String, dynamic>> dispute(String id, bool isDisputed, [String? reason]) async {
    final response = await _client.dio.patch('/settlements/$id/dispute', data: {
      'isDisputed': isDisputed,
      'disputeReason': ?reason,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getUpiLink({
    required String vpa,
    required int amount,
    required String note,
  }) async {
    final response = await _client.dio.get('/settlements/upi-link', queryParameters: {
      'vpa': vpa,
      'amount': amount,
      'note': note,
    });
    return response.data as Map<String, dynamic>;
  }
}
