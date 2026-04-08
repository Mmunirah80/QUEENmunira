import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/orders/data/order_db_status.dart';
import 'package:naham_cook_app/features/orders/domain/entities/order_entity.dart';

/// Chef pipeline + DB string mapping (no Supabase).
void main() {
  group('OrderDbStatus — chef-facing raw status', () {
    test('domainFromDb maps common DB aliases to domain', () {
      expect(OrderDbStatus.domainFromDb('paid_waiting_acceptance'), OrderStatus.pending);
      expect(OrderDbStatus.domainFromDb('cooking'), OrderStatus.preparing);
      expect(OrderDbStatus.domainFromDb('accepted'), OrderStatus.accepted);
      expect(OrderDbStatus.domainFromDb('ready'), OrderStatus.ready);
      expect(OrderDbStatus.domainFromDb('completed'), OrderStatus.completed);
      expect(OrderDbStatus.domainFromDb('cancelled_by_customer'), OrderStatus.cancelled);
    });

    test('canChefAcceptDbStatus true for paid_waiting_acceptance', () {
      expect(OrderDbStatus.canChefAcceptDbStatus('paid_waiting_acceptance'), isTrue);
    });

    test('canChefAdvanceDbStatus rejects skipping preparing', () {
      expect(OrderDbStatus.canChefAdvanceDbStatus('accepted', OrderStatus.ready), isFalse);
    });

    test('canChefRejectDbStatus false when terminal', () {
      expect(OrderDbStatus.canChefRejectDbStatus('completed'), isFalse);
      expect(OrderDbStatus.canChefRejectDbStatus('cancelled'), isFalse);
    });

    test('canChefRejectDbStatus true for ready (late cancel path)', () {
      expect(OrderDbStatus.canChefRejectDbStatus('ready'), isTrue);
    });

    test('isInKitchenDbStatus covers active kitchen work', () {
      expect(OrderDbStatus.isInKitchenDbStatus('accepted'), isTrue);
      expect(OrderDbStatus.isInKitchenDbStatus('cooking'), isTrue);
      expect(OrderDbStatus.isInKitchenDbStatus('ready'), isTrue);
      expect(OrderDbStatus.isInKitchenDbStatus('completed'), isFalse);
    });

    test('mutationValueFor chef stages uses stable DB tokens', () {
      expect(OrderDbStatus.mutationValueFor(OrderStatus.preparing), 'preparing');
      expect(OrderDbStatus.mutationValueFor(OrderStatus.ready), 'ready');
      expect(OrderDbStatus.mutationValueFor(OrderStatus.completed), 'completed');
    });
  });

  group('OrderDbStatus.recognizes', () {
    test('unknown raw status is not recognized', () {
      expect(OrderDbStatus.recognizes('totally_unknown_status_xyz'), isFalse);
    });
  });
}
