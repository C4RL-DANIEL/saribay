import 'dart:convert';
import 'package:http/http.dart' as http;

/// MiMo v2.5 API service — Xiaomi's cheap & efficient model.
/// Uses OpenAI-compatible chat completions endpoint.
class MimoApiService {
  MimoApiService._();
  static final MimoApiService instance = MimoApiService._();

  // MiMo API config — OpenRouter confirmed working!
  static const _apiKeys = ['sk-s1sxqgvenly9j9w74fx3nplop3ip7xnvnmbazn1oatzummnp'];
  static const _model = 'xiaomi/mimo-v2.5';  // OpenRouter format: provider/model
  
  // OpenRouter is the working endpoint
  static const _defaultEndpoints = [
    'https://openrouter.ai/api/v1',  // ✅ CONFIRMED WORKING
    'https://api.xiaomi.com/v1',
    'https://api.mimo.xiaomi.com/v1',
  ];
  
  String? _workingEndpoint;
  List<String> _customEndpoints = [];

  /// Add custom endpoints to try (e.g., from settings)
  void addCustomEndpoints(List<String> endpoints) {
    _customEndpoints = endpoints;
  }

  /// Set the primary endpoint to use (from settings)
  void setPrimaryEndpoint(String endpoint) {
    _workingEndpoint = endpoint;
  }

  /// Send a chat completion request to MiMo.
  Future<String> chat({
    required String systemPrompt,
    required String userMessage,
    String? context,
  }) async {
    final messages = [
      {'role': 'system', 'content': systemPrompt},
      if (context != null && context.isNotEmpty)
        {'role': 'system', 'content': 'Current store data:\n$context'},
      {'role': 'user', 'content': userMessage},
    ];

    // Build endpoint list: working endpoint first, then custom, then defaults
    final endpointsToTry = [
      if (_workingEndpoint != null) _workingEndpoint!,
      ..._customEndpoints.where((e) => e != _workingEndpoint),
      ..._defaultEndpoints.where((e) => 
        e != _workingEndpoint && !_customEndpoints.contains(e)),
    ];

    for (final baseUrl in endpointsToTry) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${_apiKeys[0]}',
            'HTTP-Referer': 'https://saribay.app',
            'X-Title': 'SariBay POS',
          },
          body: jsonEncode({
            'model': _model,
            'messages': messages,
            'temperature': 0.3,
            'max_tokens': 1024,
            'stream': false,
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          _workingEndpoint = baseUrl;
          final data = jsonDecode(response.body);
          final content = data['choices']?[0]?['message']?['content'];
          if (content != null && content is String && content.isNotEmpty) {
            return content.trim();
          }
          return 'I received an empty response. Please try again.';
        } else if (response.statusCode == 401) {
          continue; // Try next endpoint
        } else if (response.statusCode == 429) {
          return 'Too many requests. Please wait a moment and try again.';
        }
      } catch (e) {
        continue; // Try next endpoint
      }
    }
    
    return 'NETWORK_ERROR';
  }

  /// Check if any API endpoint is reachable.
  Future<bool> healthCheck() async {
    if (_workingEndpoint != null) {
      try {
        final response = await http.get(
          Uri.parse('$_workingEndpoint/models'),
          headers: {'Authorization': 'Bearer ${_apiKeys[0]}'},
        ).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          return true;
        }
      } catch (_) {
        _workingEndpoint = null;
      }
    }
    
    final allEndpoints = [..._customEndpoints, ..._defaultEndpoints];
    for (final baseUrl in allEndpoints) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/models'),
          headers: {'Authorization': 'Bearer ${_apiKeys[0]}'},
        ).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          _workingEndpoint = baseUrl;
          return true;
        }
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  /// Test a specific endpoint
  Future<bool> testEndpoint(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$endpoint/models'),
        headers: {'Authorization': 'Bearer ${_apiKeys[0]}'},
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        _workingEndpoint = endpoint;
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Get the currently working endpoint (for display)
  String? get workingEndpoint => _workingEndpoint;
}
