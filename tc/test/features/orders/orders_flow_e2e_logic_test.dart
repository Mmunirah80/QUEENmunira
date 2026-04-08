import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/orders/data/order_db_status.dart';
import 'package:naham_cook_app/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:naham_cook_app/features/orders/domain/entities/order_entity.dart';

import 'support/order_flow_test_infrastructure.dart';

void main() {
  const chefId = '11111111-1111-4111-8111-111111111111';
  const customerId = 'e1000001-0000-4000-8000-0000000000c1';

  group('Order flow (customer / chef / admin) — shared fake store', () {
    late OrderFlowSharedStore store;
    late OrderFlowFakeRemoteDataSource customerDs;
    late OrderFlowFakeRemoteDataSource chefDs;
    late OrderFlowFakeRemoteDataSource adminDs;

    late OrdersRepositoryImpl customerRepo;
    late OrdersRepositoryImpl chefRepo;
    late OrdersRepositoryImpl adminRepo;

    setUp(() {
      store = OrderFlowSharedStore();
      customerDs = OrderFlowFakeRemoteDataSource(
        view: OrderFlowActorView.customer,
        actorId: customerId,
        store: store,
      );
      chefDs = OrderFlowFakeRemoteDataSource(
        view: OrderFlowActorView.chef,
        actorId: chefId,
        store: store,
      );
      adminDs = OrderFlowFakeRemoteDataSource(
        view: OrderFlowActorView.admin,
        actorId: '',
        store: store,
      );
      customerRepo = OrdersRepositoryImpl(remoteDataSource: customerDs);
      chefRepo = OrdersRepositoryImpl(remoteDataSource: chefDs);
      adminRepo = OrdersRepositoryImpl(remoteDataSource: adminDs);
    });

    test('customer places order → appears in customer active list (pending)', () async {
      final id = await customerRepo.createOrder(
        customerId: customerId,
        customerName: 'Test Customer',
        chefId: chefId,
        chefName: 'Test Kitchen',
        items: [
          {'name': 'Dish', 'quantity': 1, 'price': 25.0},
        ],
        totalAmount: 25,
      );
      final mine = await customerRepo.getOrdersByStatus(OrderStatus.pending);
      expect(mine.any((o) => o.id == id), isTrue);
    });

    test('chef sees same order; full pipeline accept → preparing → ready → complete', () async {
      final id = await customerRepo.createOrder(
        customerId: customerId,
        customerName: 'Test Customer',
        chefId: chefId,
        chefName: 'Test Kitchen',
        items: [
          {'name': 'Dish', 'quantity': 1, 'price': 10.0},
        ],
        totalAmount: 10,
      );

      final chefPending = await chefRepo.getOrdersByStatus(OrderStatus.pending);
      expect(chefPending.any((o) => o.id == id), isTrue);

      await chefRepo.acceptOrder(id);
      await chefRepo.updateOrderStatus(id, OrderStatus.preparing);
      await chefRepo.updateOrderStatus(id, OrderStatus.ready);
      await chefRepo.updateOrderStatus(id, OrderStatus.completed);

      final done = await chefRepo.getOrderById(id);
      expect(done.status, OrderStatus.completed);

      final cust = await customerRepo.getOrderById(id);
      expect(cust.status, OrderStatus.completed);
      final adm = await adminRepo.getOrderById(id);
      expect(adm.status, OrderStatus.completed);
    });

    test('invalid chef transitions fail and cannot skip steps', () async {
      final id = await customerRepo.createOrder(
        customerId: customerId,
        customerName: 'Test Customer',
        chefId: chefId,
        chefName: 'Test Kitchen',
        items: [
          {'name': 'Dish', 'quantity': 1, 'price': 1.0},
        ],
        totalAmount: 1,
      );

      await expectLater(
        chefRepo.updateOrderStatus(id, OrderStatus.preparing),
        throwsStateError,
      );

      await chefRepo.acceptOrder(id);
      await expectLater(
        chefRepo.updateOrderStatus(id, OrderStatus.ready),
        throwsStateError,
      );
    });

    test('chef reject maps to cook cancel reason semantics', () async {
      final id = await customerRepo.createOrder(
        customerId: customerId,
        customerName: 'Test Customer',
        chefId: chefId,
        chefName: 'Test Kitchen',
        items: [
          {'name': 'Dish', 'quantity': 1, 'price': 5.0},
        ],
        totalAmount: 5,
      );
      await chefRepo.rejectOrder(id, reason: 'Too busy');
      final o = await adminRepo.getOrderById(id);
      expect(o.status, OrderStatus.cancelled);
      expect(o.cancelReason, OrderDbStatus.internalCookRejected);
    });

    test('customer can cancel pending; system cancel sets internal frozen reason', () async {
      final id = await customerRepo.createOrder(
        customerId: customerId,
        customerName: 'Test Customer',
        chefId: chefId,
        chefName: 'Test Kitchen',
        items: [
          {'name': 'Dish', 'quantity': 1, 'price': 3.0},
        ],
        totalAmount: 3,
      );
      await customerDs.customerCancelPending(id);
      var o = await adminRepo.getOrderById(id);
      expect(o.status, OrderStatus.cancelled);
      expect(o.dbStatus, 'cancelled_by_customer');

      final id2 = await customerRepo.createOrder(
        customerId: customerId,
        customerName: 'Test Customer',
        chefId: chefId,
        chefName: 'Test Kitchen',
        items: [
          {'name': 'Dish2', 'quantity': 1, 'price': 4.0},
        ],
        totalAmount: 4,
      );
      store.applySystemCancel(id2);
      o = await adminRepo.getOrderById(id2);
      expect(o.status, OrderStatus.cancelled);
      expect(o.cancelReason, OrderDbStatus.internalSystemCancelledFrozen);
    });

    test('double place with same idempotency key does not duplicate orders', () async {
      const key = 'idem-key-001';
      final id1 = await customerRepo.createOrder(
        customerId: customerId,
        customerName: 'Test Customer',
        chefId: chefId,
        chefName: 'Test Kitchen',
        items: [
          {'name': 'Dish', 'quantity': 1, 'price': 10.0},
        ],
        totalAmount: 10,
        idempotencyKey: key,
      );
      final id2 = await customerRepo.createOrder(
        customerId: customerId,
        customerName: 'Test Customer',
        chefId: chefId,
        chefName: 'Test Kitchen',
        items: [
          {'name': 'Dish', 'quantity': 1, 'price': 10.0},
        ],
        totalAmount: 10,
        idempotencyKey: key,
      );
      expect(id1, id2);
      final all = await adminRepo.getOrders();
      expect(all.where((o) => o.id == id1).length, 1);
    });

    test('capacity: cannot order more than remaining dish stock', () async {
      const dishId = 'dish-cap-1';
      store.dishRemaining[dishId] = 2;

      await expectLater(
        customerRepo.createOrder(
          customerId: customerId,
          customerName: 'Test Customer',
          chefId: chefId,
          chefName: 'Test Kitchen',
          items: [
            {'id': dishId, 'name': 'Limited', 'quantity': 3, 'price': 1.0},
          ],
          totalAmount: 3,
        ),
        throwsException,
      );

      final okId = await customerRepo.createOrder(
        customerId: customerId,
        customerName: 'Test Customer',
        chefId: chefId,
        chefName: 'Test Kitchen',
        items: [
          {'id': dishId, 'name': 'Limited', 'quantity': 2, 'price': 1.0},
        ],
        totalAmount: 2,
      );
      expect(store.dishRemaining[dishId], 0);
      final o = await customerRepo.getOrderById(okId);
      expect(o.status, OrderStatus.pending);
    });

    test('sync: customer, chef, admin read identical status after accept', () async {
      final id = await customerRepo.createOrder(
        customerId: customerId,
        customerName: 'Test Customer',
        chefId: chefId,
        chefName: 'Test Kitchen',
        items: [
          {'name': 'Dish', 'quantity': 1, 'price': 7.0},
        ],
        totalAmount: 7,
      );
      await chefRepo.acceptOrder(id);
      final a = await customerRepo.getOrderById(id);
      final b = await chefRepo.getOrderById(id);
      final c = await adminRepo.getOrderById(id);
      expect(a.status, OrderStatus.accepted);
      expect(b.status, OrderStatus.accepted);
      expect(c.status, OrderStatus.accepted);
    });

    test('edge: missing items / invalid total rejected at create', () async {
      await expectLater(
        customerRepo.createOrder(
          customerId: customerId,
          customerName: 'Test Customer',
          chefId: chefId,
          chefName: 'Test Kitchen',
          items: [],
          totalAmount: 1,
        ),
        throwsArgumentError,
      );
      await expectLater(
        customerRepo.createOrder(
          customerId: customerId,
          customerName: 'Test Customer',
          chefId: chefId,
          chefName: 'Test Kitchen',
          items: [
            {'name': 'X', 'quantity': 1, 'price': 1.0},
          ],
          totalAmount: double.nan,
        ),
        throwsArgumentError,
      );
    });

    test('network fail once: getOrders retries succeed on second repository read', () async {
      final wrapped = OrdersNetworkFailOnceWrapper(
        OrderFlowFakeRemoteDataSource(
          view: OrderFlowActorView.chef,
          actorId: chefId,
          store: store,
        ),
      );
      final repo = OrdersRepositoryImpl(remoteDataSource: wrapped);
      await expectLater(repo.getOrders(), throwsException);
      final second = await repo.getOrders();
      expect(second, isA<List<OrderEntity>>());
    });

    test('chef watchOrders stream receives pending after customer creates order', () async {
      final id = await customerRepo.createOrder(
        customerId: customerId,
        customerName: 'Test Customer',
        chefId: chefId,
        chefName: 'Test Kitchen',
        items: [
          {'name': 'Dish', 'quantity': 1, 'price': 2.0},
        ],
        totalAmount: 2,
      );
      final snap = await chefDs.watchOrders(statuses: [OrderStatus.pending]).first;
      expect(snap.any((o) => o.id == id), isTrue);
    });

    test('cross-tenant: customer cannot read another customer order by id', () async {
      final otherCustomer = OrderFlowFakeRemoteDataSource(
        view: OrderFlowActorView.customer,
        actorId: 'e1000002-0000-4000-8000-0000000000c2',
        store: store,
      );
      final id = await customerRepo.createOrder(
        customerId: customerId,
        customerName: 'Test Customer',
        chefId: chefId,
        chefName: 'Test Kitchen',
        items: [
          {'name': 'Dish', 'quantity': 1, 'price': 1.0},
        ],
        totalAmount: 1,
      );
      await expectLater(otherCustomer.getOrderById(id), throwsException);
    });
  });
}
