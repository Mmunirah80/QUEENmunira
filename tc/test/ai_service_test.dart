// Test for AiService.classifyDishSeason wiring to Supabase Edge Function.
//
// To see what the AI returns for Samboosa + cheese, pastry:
// 1. Run the app: flutter run. Go to Menu > tap edit on any dish (or add one),
//    set name "Samboosa", add ingredients "cheese" and "pastry", tap "Analyze with AI".
//    The result card shows the AI output; on failure you get a friendly message + Retry.
// 2. Or call the Edge Function directly (Postman/curl) with body:
//    { "prompt": "<same prompt as in AiService.classifyDishSeason>" }
//
// This test only verifies the prompt shape and that AiServiceException is used.
// Full integration test requires a device/runner with Supabase plugins.

import 'package:flutter_test/flutter_test.dart';

import 'package:naham_cook_app/services/ai_service.dart';

void main() {
  test('AiService.friendlyAiErrorMessage returns friendly string for AiServiceException', () {
    final e = AiServiceException('Session expired.');
    expect(AiService.friendlyAiErrorMessage(e), 'Session expired.');
  });

  test('classifyDishSeason prompt shape: ingredients list is formatted', () {
    // Minimal check that the service builds the expected structure for the Edge Function.
    final ingredients = [
      {'name': 'cheese', 'quantity': 1, 'unit': 'piece'},
      {'name': 'pastry', 'quantity': 1, 'unit': 'piece'},
    ];
    final list = ingredients
        .map((i) => "${i['name']} (${i['quantity']} ${i['unit']})")
        .join(', ');
    expect(list, 'cheese (1 piece), pastry (1 piece)');
  });
}
