import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when an AI Edge Function call fails. [message] is user-friendly.
class AiServiceException implements Exception {
  AiServiceException(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String toString() => message;
}

/// Central AI service used by chef-side screens.
///
/// All AI calls go through the Supabase Edge Function `ai-pricing`
/// which in turn talks to OpenAI using the prompts defined in the
/// Family Kitchen AI integration document.
class AiService {
  AiService({SupabaseClient? client})
      : _overrideClient = client;

  final SupabaseClient? _overrideClient;

  SupabaseClient get _client =>
      _overrideClient ?? Supabase.instance.client;

  static const String _functionName = 'ai-pricing';

  /// User-friendly message when AI fails so UI can show it and offer retry.
  static String friendlyAiErrorMessage(Object error) {
    if (error is AiServiceException) return error.message;
    final s = error.toString().toLowerCase();
    if (s.contains('socket') || s.contains('connection') || s.contains('network')) {
      return 'No connection. Check your internet and try again.';
    }
    if (s.contains('timeout') || s.contains('timed out')) {
      return 'The request took too long. Please try again.';
    }
    if (s.contains('401') || s.contains('unauthorized') || s.contains('jwt')) {
      return 'Session expired. Please sign in again.';
    }
    if (s.contains('404') || s.contains('not found')) {
      return 'AI service is not available. Please try again later.';
    }
    if (s.contains('500') || s.contains('502') || s.contains('503') || s.contains('internal')) {
      return 'AI is temporarily unavailable. Please try again in a moment.';
    }
    return 'Something went wrong with the AI. Please try again.';
  }

  static bool _looksLikeInvalidJwt(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('401') || s.contains('invalid jwt') || s.contains('unauthorized');
  }

  Map<String, dynamic> _decodeAiResponse(dynamic data) {
    if (data == null) throw Exception('No response from AI');
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      throw Exception('AI response was not a JSON object');
    }
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    throw Exception('AI response was not a JSON object');
  }

  /// Helper to call the `ai-pricing` Edge Function with a raw prompt
  /// and decode the JSON response. Throws [AiServiceException] on failure.
  ///
  /// Retries once after [refreshSession] when the function returns 401 Invalid JWT
  /// (common on web when the access token is slightly stale).
  Future<Map<String, dynamic>> _invokeAiPricing(String prompt) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        if (attempt > 0) {
          await _client.auth.refreshSession();
        }
        final session = _client.auth.currentSession;
        if (session == null) throw Exception('Not authenticated');

        final response = await _client.functions.invoke(
          _functionName,
          body: {'prompt': prompt},
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        );

        return _decodeAiResponse(response.data);
      } catch (e) {
        lastError = e;
        if (attempt == 0 && _looksLikeInvalidJwt(e)) {
          continue;
        }
        if (kDebugMode) {
          debugPrint('AI ERROR: $e');
        }
        throw Exception('AI service error: $e');
      }
    }
    if (kDebugMode) {
      debugPrint('AI ERROR: $lastError');
    }
    throw Exception('AI service error: $lastError');
  }

  /// Prompt 1 — Classify Dish Season
  ///
  /// Uses:
  ///   - dish name
  ///   - ingredients (name / quantity / unit)
  ///   - category
  ///
  /// Returns JSON like:
  /// {
  ///   "seasons": ["ramadan"],
  ///   "confidence": "high",
  ///   "reason": "..."
  /// }
  Future<Map<String, dynamic>> classifyDishSeason({
    required String dishName,
    required List<Map<String, dynamic>> ingredients,
    required String category,
  }) async {
    final ingredientsList = ingredients
        .map((i) => "${i['name']} (${i['quantity']} ${i['unit']})")
        .join(', ');

    final prompt = '''
You are an AI assistant for a Saudi family kitchen platform.

Analyze the following dish and determine which seasons it belongs to.

Dish name: $dishName
Ingredients: $ingredientsList
Category: $category

Available seasons: ramadan, eid_fitr, eid_adha, winter, summer, celebrations, normal

Rules:
- A dish can belong to multiple seasons
- Use "normal" if it doesn't fit any specific season
- Base your decision on Saudi food culture

Reply in JSON only, no extra text:
{
  "seasons": ["ramadan"],
  "confidence": "high",
  "reason": "Samboosa is one of the most popular Ramadan dishes in Saudi Arabia"
}
''';

    return _invokeAiPricing(prompt);
  }

  /// Prompt 2 — Calculate Cost & Suggest Price
  ///
  /// Uses:
  ///   - dish name
  ///   - full ingredient JSON (name, quantity, unit, price)
  ///   - servings
  ///   - current season + dish seasons + season increase percentage
  ///
  /// Returns JSON like:
  /// {
  ///   "ingredient_cost": 48,
  ///   "spices_cost": 1.44,
  ///   "operational_cost": 4.94,
  ///   "total_cost": 54.38,
  ///   "cost_per_serving": 9.06,
  ///   "base_price": 12,
  ///   "seasonal_price": 14,
  ///   "seasonal_increase_amount": 2,
  ///   "is_season_active": true,
  ///   "warning": null,
  ///   "insight": "..."
  /// }
  Future<Map<String, dynamic>> analyzeRecipePricing({
    required String dishName,
    required List<Map<String, dynamic>> ingredients,
    required int servings,
    required String currentSeason,
    required List<String> dishSeasons,
    required double seasonIncreasePct,
  }) async {
    final prompt = '''
You are a pricing assistant for a Saudi family kitchen platform.

Calculate the cost and suggest a price for this dish.

Dish name: $dishName
Ingredients:
${jsonEncode(ingredients)}

Number of servings from this batch: $servings
Spices estimate: 3% of ingredient cost
Operational costs (electricity + packaging + running): 10%
Profit margin: 30%

Current season: $currentSeason
This dish's seasons: ${dishSeasons.join(', ')}
Season price increase: $seasonIncreasePct%

Reply in JSON only, no extra text:
{
  "ingredient_cost": 48,
  "spices_cost": 1.44,
  "operational_cost": 4.94,
  "total_cost": 54.38,
  "cost_per_serving": 9.06,
  "base_price": 12,
  "seasonal_price": 14,
  "seasonal_increase_amount": 2,
  "is_season_active": true,
  "warning": null,
  "insight": "Ramadan is coming! Your samboosa cost is 9 SAR per serving. We suggest 14 SAR during Ramadan for a healthy margin."
}

Important: if seasonal_price < cost_per_serving, set warning to
"Warning: this price is below cost. You will lose {X} SAR per serving."
''';

    return _invokeAiPricing(prompt);
  }

  /// Prompt 3 — Menu Seasonal Alerts
  ///
  /// Uses:
  ///   - today's date
  ///   - current + next season info
  ///   - menu items JSON
  ///   - seasons config (price increase percentages)
  ///
  /// Returns JSON like:
  /// {
  ///   "alerts": [...],
  ///   "summary": "...",
  ///   "missing_seasons_suggestion": "..."
  /// }
  Future<Map<String, dynamic>> getMenuSeasonalAlerts({
    required List<Map<String, dynamic>> menuItems,
    required String currentSeason,
    required String nextSeason,
    required int daysToNext,
    required Map<String, dynamic> seasonsConfig,
    DateTime? today,
  }) async {
    final now = today ?? DateTime.now();

    final prompt = '''
You are an AI assistant for a Saudi family kitchen platform.

Today's date: ${now.toIso8601String()}
Current season: $currentSeason
Next season: $nextSeason (in $daysToNext days)

Chef's menu items:
${jsonEncode(menuItems)}

Season price increases:
${jsonEncode(seasonsConfig)}

For each item whose season is currently active OR starting within 7 days,
suggest a price increase.

Reply in JSON only, no extra text:
{
  "alerts": [
    {
      "dish_name": "Samboosa",
      "current_price": 12,
      "suggested_price": 14,
      "increase_amount": 2,
      "increase_pct": 15,
      "message": "Ramadan is here! Consider raising your Samboosa price to 14 SAR.",
      "urgency": "high"
    }
  ],
  "summary": "You have 2 seasonal items that need a price review.",
  "missing_seasons_suggestion": "You don't have any Ramadan sweets on your menu. Qatayef and Kunafa are very popular during Ramadan."
}
''';

    return _invokeAiPricing(prompt);
  }
}

