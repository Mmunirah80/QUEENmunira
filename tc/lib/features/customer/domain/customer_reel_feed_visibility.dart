import '../../../core/location/pickup_distance.dart';
import '../../reels/domain/reel_public_feed_visibility.dart';
import '../../cook/data/models/chef_doc_model.dart';

/// Full client-side gate for a reel row in the customer feed (row flags + chef + geography).
bool customerCanSeeReelInFeed({
  required ChefDocModel chef,
  required Map<String, dynamic> reelRow,
  required double customerLat,
  required double customerLng,
  String? pickupLocalityCity,
}) {
  return isReelRowPublicFeedVisible(reelRow) &&
      chefReelVisibleToCustomer(chef, customerLat, customerLng, pickupLocalityCity);
}
