import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/cook/data/models/chef_doc_model.dart';

void main() {
  group('ChefDocModel.hasKitchenMapPin', () {
    test('D.12 both lat and lng set → true', () {
      const c = ChefDocModel(
        chefId: 'a',
        kitchenLatitude: 24.7,
        kitchenLongitude: 46.6,
      );
      expect(c.hasKitchenMapPin, isTrue);
    });

    test('D.12 missing latitude → false', () {
      const c = ChefDocModel(
        chefId: 'a',
        kitchenLongitude: 46.6,
      );
      expect(c.hasKitchenMapPin, isFalse);
    });

    test('D.12 missing longitude → false', () {
      const c = ChefDocModel(
        chefId: 'a',
        kitchenLatitude: 24.7,
      );
      expect(c.hasKitchenMapPin, isFalse);
    });
  });
}
