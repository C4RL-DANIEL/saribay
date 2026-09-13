import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local memory system for AI - stores insights, patterns, and recommendations.
class AiMemoryService {
  AiMemoryService._();
  static final AiMemoryService instance = AiMemoryService._();

  static const _insightsKey = 'ai_insights';
  static const _patternsKey = 'ai_patterns';
  static const _recommendationsKey = 'ai_recommendations';
  static const _chatHistoryKey = 'ai_chat_history';

  /// Store an insight (e.g., "User asked about profit margins 3 times")
  Future<void> storeInsight(String insight, {String? context}) async {
    final prefs = await SharedPreferences.getInstance();
    final insights = await getInsights();
    insights.add({
      'insight': insight,
      'context': context,
      'timestamp': DateTime.now().toIso8601String(),
    });
    // Keep last 50 insights
    if (insights.length > 50) insights.removeRange(0, insights.length - 50);
    await prefs.setString(_insightsKey, jsonEncode(insights));
  }

  /// Get stored insights
  Future<List<Map<String, dynamic>>> getInsights() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_insightsKey);
    if (json == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(json));
  }

  /// Store a pattern (e.g., "User always asks about inventory on Mondays")
  Future<void> storePattern(String pattern, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final patterns = await getPatterns();
    patterns.add({
      'pattern': pattern,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (patterns.length > 100) patterns.removeRange(0, patterns.length - 100);
    await prefs.setString(_patternsKey, jsonEncode(patterns));
  }

  /// Get stored patterns
  Future<List<Map<String, dynamic>>> getPatterns() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_patternsKey);
    if (json == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(json));
  }

  /// Store a recommendation and track if user acted on it
  Future<void> storeRecommendation(String recommendation, {String? action}) async {
    final prefs = await SharedPreferences.getInstance();
    final recs = await getRecommendations();
    recs.add({
      'recommendation': recommendation,
      'action': action,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (recs.length > 50) recs.removeRange(0, recs.length - 50);
    await prefs.setString(_recommendationsKey, jsonEncode(recs));
  }

  /// Get stored recommendations
  Future<List<Map<String, dynamic>>> getRecommendations() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_recommendationsKey);
    if (json == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(json));
  }

  /// Store chat history for context
  Future<void> storeChatMessage(String role, String message) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getChatHistory();
    history.add({
      'role': role,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
    // Keep last 100 messages
    if (history.length > 100) history.removeRange(0, history.length - 100);
    await prefs.setString(_chatHistoryKey, jsonEncode(history));
  }

  /// Get recent chat history for context
  Future<List<Map<String, dynamic>>> getChatHistory({int limit = 20}) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_chatHistoryKey);
    if (json == null) return [];
    final all = List<Map<String, dynamic>>.from(jsonDecode(json));
    return all.length > limit ? all.sublist(all.length - limit) : all;
  }

  /// Get memory context for AI prompts
  Future<String> getMemoryContext() async {
    final insights = await getInsights();
    final patterns = await getPatterns();
    final recommendations = await getRecommendations();
    final chatHistory = await getChatHistory(limit: 10);

    final context = StringBuffer();
    
    if (insights.isNotEmpty) {
      context.writeln('Recent insights:');
      for (final i in insights.takeLast(5)) {
        context.writeln('- ${i['insight']} (${i['timestamp']})');
      }
    }
    
    if (patterns.isNotEmpty) {
      context.writeln('\nLearned patterns:');
      for (final p in patterns.takeLast(3)) {
        context.writeln('- ${p['pattern']}');
      }
    }
    
    if (recommendations.isNotEmpty) {
      context.writeln('\nRecent recommendations:');
      for (final r in recommendations.takeLast(3)) {
        context.writeln('- ${r['recommendation']}');
      }
    }
    
    if (chatHistory.isNotEmpty) {
      context.writeln('\nRecent conversation:');
      for (final msg in chatHistory.takeLast(5)) {
        context.writeln('${msg['role']}: ${msg['message']}');
      }
    }
    
    return context.toString();
  }

  /// Analyze user behavior and store patterns
  Future<void> analyzeAndStorePatterns(List<Map<String, dynamic>> recentMessages) async {
    // Detect question patterns
    final questionCount = <String, int>{};
    for (final msg in recentMessages) {
      if (msg['role'] == 'user') {
        final msgText = (msg['message'] as String).toLowerCase();
        if (msgText.contains('profit') || msgText.contains('margin')) {
          questionCount['profit_analysis'] = (questionCount['profit_analysis'] ?? 0) + 1;
        }
        if (msgText.contains('reorder') || msgText.contains('stock')) {
          questionCount['inventory_analysis'] = (questionCount['inventory_analysis'] ?? 0) + 1;
        }
        if (msgText.contains('utang') || msgText.contains('credit')) {
          questionCount['credit_analysis'] = (questionCount['credit_analysis'] ?? 0) + 1;
        }
        if (msgText.contains('best') || msgText.contains('top')) {
          questionCount['best_seller_analysis'] = (questionCount['best_seller_analysis'] ?? 0) + 1;
        }
      }
    }
    
    // Store patterns
    for (final entry in questionCount.entries) {
      if (entry.value >= 2) {
        await storePattern('User frequently asks about: ${entry.key}', {'count': entry.value});
      }
    }
  }
}

extension _ListExtension<T> on List<T> {
  List<T> takeLast(int count) {
    if (length <= count) return this;
    return sublist(length - count);
  }
}
