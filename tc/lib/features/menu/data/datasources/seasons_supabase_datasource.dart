import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_config.dart';
import '../models/season_model.dart';

/// Supabase access for the `seasons` table used by AI pricing.
class SeasonsSupabaseDataSource {
  SeasonsSupabaseDataSource({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  Future<List<SeasonModel>> getSeasons() async {
    final res = await _client.from('seasons').select();
    final list = res as List<dynamic>? ?? const [];
    return list
        .map((row) => SeasonModel.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Builds the config map expected by [AiService.getMenuSeasonalAlerts].
  Future<Map<String, dynamic>> buildSeasonsConfig() async {
    final seasons = await getSeasons();
    final Map<String, dynamic> config = {};
    for (final s in seasons) {
      config[s.name] = {
        'price_increase_pct': s.priceIncreasePct,
      };
    }
    if (!config.containsKey('normal')) {
      config['normal'] = {'price_increase_pct': 0};
    }
    return config;
  }

  /// Finds an appropriate seasonal price increase percentage for this dish.
  ///
  /// Picks the first non-"normal" season from [dishSeasons] that exists in
  /// [allSeasons]; falls back to "normal" or 0 if none match.
  double resolveSeasonIncreasePct({
    required List<String> dishSeasons,
    required List<SeasonModel> allSeasons,
  }) {
    if (allSeasons.isEmpty) return 0;
    final lowerToModel = {
      for (final s in allSeasons) s.name.toLowerCase(): s,
    };

    String effective = 'normal';
    for (final s in dishSeasons) {
      final key = s.toLowerCase();
      if (key != 'normal' && lowerToModel.containsKey(key)) {
        effective = s;
        break;
      }
    }

    final key = effective.toLowerCase();
    final match = lowerToModel[key] ?? lowerToModel['normal'];
    return match?.priceIncreasePct ?? 0;
  }
}

