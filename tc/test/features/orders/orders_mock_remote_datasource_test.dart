import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/orders/data/datasources/orders_mock_remote_datasource.dart';
import 'package:naham_cook_app/features/orders/domain/entities/order_entity.dart';

void main() {
  /// Valid UUID (matches what Supabase auth uses for chef id shape).
  const chefId = '11111111-1111-4111-8111-111111111111';

  group('OrdersMockRemoteDataSource', () {
    setUp(OrdersMockRemoteDataSource.clearInstancesForTests);
    tearDown(OrdersMockRemoteDataSource.clearInstancesForTests);
    test('happy path: pending → accepted → preparing → ready → completed', () async {
      final ds = OrdersMockRemoteDataSource(chefId: chefId);
      await ds.acceptOrder(CookMockOrderIds.pendingAlpha);
      var o = await ds.getOrderById(CookMockOrderIds.pendingAlpha);
      expect(o.status, OrderStatus.accepted);

      await ds.updateOrderStatus(CookMockOrderIds.pendingAlpha, OrderStatus.preparing);
      o = await ds.getOrderById(CookMockOrderIds.pendingAlpha);
      expect(o.status, OrderStatus.preparing);

      await ds.updateOrderStatus(CookMockOrderIds.pendingAlpha, OrderStatus.ready);
      o = await ds.getOrderById(CookMockOrderIds.pendingAlpha);
      expect(o.status, OrderStatus.ready);

      await ds.updateOrderStatus(CookMockOrderIds.pendingAlpha, OrderStatus.completed);
      o = await ds.getOrderById(CookMockOrderIds.pendingAlpha);
      expect(o.status, OrderStatus.completed);
    });

    test('reject: pending → cancelled with reason note', () async {
      final ds = OrdersMockRemoteDataSource(chefId: chefId);
      await ds.rejectOrder(CookMockOrderIds.pendingBeta, reason: 'Busy');
      final o = await ds.getOrderById(CookMockOrderIds.pendingBeta);
      expect(o.status, OrderStatus.cancelled);
      expect(o.notes, contains('Busy'));
    });

    test('abnormal: cannot skip to preparing from pending', () async {
      final ds = OrdersMockRemoteDataSource(chefId: chefId);
      await expectLater(
        ds.updateOrderStatus(CookMockOrderIds.pendingAlpha, OrderStatus.preparing),
        throwsStateError,
      );
    });

    test('abnormal: cannot accept twice', () async {
      final ds = OrdersMockRemoteDataSource(chefId: chefId);
      await ds.acceptOrder(CookMockOrderIds.pendingAlpha);
      await expectLater(
        ds.acceptOrder(CookMockOrderIds.pendingAlpha),
        throwsStateError,
      );
    });

    test('abnormal: cannot advance completed order', () async {
      final ds = OrdersMockRemoteDataSource(chefId: chefId);
      await expectLater(
        ds.updateOrderStatus(CookMockOrderIds.doneCompleted, OrderStatus.preparing),
        throwsStateError,
      );
    });

    test('isValidCookTransition matrix (sample)', () {
      expect(
        OrdersMockRemoteDataSource.isValidCookTransition(
          OrderStatus.pending,
          OrderStatus.accepted,
        ),
        isTrue,
      );
      expect(
        OrdersMockRemoteDataSource.isValidCookTransition(
          OrderStatus.pending,
          OrderStatus.preparing,
        ),
        isFalse,
      );
      expect(
        OrdersMockRemoteDataSource.isValidCookTransition(
          OrderStatus.ready,
          OrderStatus.completed,
        ),
        isTrue,
      );
    });

    test('createOrder appends pending row', () async {
      final ds = OrdersMockRemoteDataSource(chefId: chefId);
      final before = (await ds.getOrders()).length;
      final id = await ds.createOrder(
        customerId: 'c1',
        customerName: 'New',
        chefId: chefId,
        chefName: 'K',
        items: [
          {'name': 'X', 'quantity': 1, 'price': 10.0},
        ],
        totalAmount: 10,
      );
      final after = await ds.getOrders();
      expect(after.length, before + 1);
      final o = await ds.getOrderById(id);
      expect(o.status, OrderStatus.pending);
      expect(o.items.length, 1);
    });
  });
}
