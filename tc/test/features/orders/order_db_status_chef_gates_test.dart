import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/orders/data/order_db_status.dart';
import 'package:naham_cook_app/features/orders/domain/entities/order_entity.dart';

void main() {
  group('OrderDbStatus chef transition gates', () {
    test('canChefAcceptDbStatus only for pending-like raw values', () {
      expect(OrderDbStatus.canChefAcceptDbStatus('pending'), isTrue);
      expect(OrderDbStatus.canChefAcceptDbStatus('accepted'), isFalse);
    });

    test('canChefAdvanceDbStatus enforces accepted → preparing → ready → completed', () {
      expect(OrderDbStatus.canChefAdvanceDbStatus('accepted', OrderStatus.preparing), isTrue);
      expect(OrderDbStatus.canChefAdvanceDbStatus('preparing', OrderStatus.ready), isTrue);
      expect(OrderDbStatus.canChefAdvanceDbStatus('ready', OrderStatus.completed), isTrue);
      expect(OrderDbStatus.canChefAdvanceDbStatus('pending', OrderStatus.preparing), isFalse);
    });

    test('canChefRejectDbStatus allows early pipeline stages', () {
      expect(OrderDbStatus.canChefRejectDbStatus('pending'), isTrue);
      expect(OrderDbStatus.canChefRejectDbStatus('accepted'), isTrue);
      expect(OrderDbStatus.canChefRejectDbStatus('completed'), isFalse);
    });
  });
}
