import 'dart:convert';
import 'package:http/http.dart' as http;

/// MiMo v2.5 API service — Xiaomi's cheap & efficient model.
/// Uses OpenAI-compatible chat completions endpoint.
class MimoApiService {
  MimoApiService._();
  static final MimoApiService instance = MimoApiService._();

  // MiMo API config
  static const _baseUrl = 'https://api.xiaomi.com/v1';
  static const _apiKey = 'sk-s1sxqgvenly9j9w74fx3nplop3ip7xnvnmbazn1oatzummnp';
  static const _model = 'mimo-v2.5';

  /// Send a chat completion request to MiMo.
  /// [systemPrompt] defines the AI's role and constraints.
  /// [userMessage] is the user's question.
  /// [context] is optional store data to inject into the prompt.
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

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'temperature': 0.3,
          'max_tokens': 1024,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        if (content != null && content is String && content.isNotEmpty) {
          return content.trim();
        }
        return 'I received an empty response. Please try again.';
      } else if (response.statusCode == 401) {
        return 'API key is invalid. Please check the configuration.';
      } else if (response.statusCode == 429) {
        return 'Too many requests. Please wait a moment and try again.';
      } else {
        return 'API error (${response.statusCode}). Using local analysis instead.';
      }
    } catch (e) {
      // Network error — return null so caller falls back to local analysis
      return 'NETWORK_ERROR';
    }
  }

  /// Check if the API is reachable.
  Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/models'),
        headers: {'Authorization': 'Bearer $_apiKey'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
