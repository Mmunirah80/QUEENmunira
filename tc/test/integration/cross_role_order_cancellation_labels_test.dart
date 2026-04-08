import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/orders/data/order_db_status.dart';
import 'package:naham_cook_app/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:naham_cook_app/features/orders/domain/entities/order_entity.dart';

import '../features/orders/support/order_flow_test_infrastructure.dart';

/// A.6–7 + G/H: shared store order — labels customer-facing vs same underlying cancel_reason.
void main() {
  const chefId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
  const customerId = 'e3000001-0000-4000-8000-0000000000e1';

  group('Cross-role order cancellation labels', () {
    test('chef reject → customer-facing label and admin row share cook_rejected reason', () async {
      final store = OrderFlowSharedStore();
      final customerDs = OrderFlowFakeRemoteDataSource(
        view: OrderFlowActorView.customer,
        actorId: customerId,
        store: store,
      );
      final chefDs = OrderFlowFakeRemoteDataSource(
        view: OrderFlowActorView.chef,
        actorId: chefId,
        store: store,
      );
      final adminDs = OrderFlowFakeRemoteDataSource(
        view: OrderFlowActorView.admin,
        actorId: '',
        store: store,
      );
      final customerRepo = OrdersRepositoryImpl(remoteDataSource: customerDs);
      final chefRepo = OrdersRepositoryImpl(remoteDataSource: chefDs);
      final adminRepo = OrdersRepositoryImpl(remoteDataSource: adminDs);

      final id = await customerRepo.createOrder(
        customerId: customerId,
        customerName: 'Cust',
        chefId: chefId,
        chefName: 'K',
        items: [
          {'name': 'D', 'quantity': 1, 'price': 1.0},
        ],
        totalAmount: 1,
      );
      await chefRepo.rejectOrder(id, reason: 'Busy');

      final cust = await customerRepo.getOrderById(id);
      final ch = await chefRepo.getOrderById(id);
      final ad = await adminRepo.getOrderById(id);

      expect(cust.status, OrderStatus.cancelled);
      expect(ch.status, OrderStatus.cancelled);
      expect(ad.cancelReason, OrderDbStatus.internalCookRejected);

      final label = OrderDbStatus.customerFacingLabel(
        ad.dbStatus,
        cancelReason: ad.cancelReason,
      );
      expect(label, 'Rejected by cook');
    });

    test('customer cancel pending → chef no longer sees as pending', () async {
      final store = OrderFlowSharedStore();
      final customerRepo = OrdersRepositoryImpl(
        remoteDataSource: OrderFlowFakeRemoteDataSource(
          view: OrderFlowActorView.customer,
          actorId: customerId,
          store: store,
        ),
      );
      final chefRepo = OrdersRepositoryImpl(
        remoteDataSource: OrderFlowFakeRemoteDataSource(
          view: OrderFlowActorView.chef,
          actorId: chefId,
          store: store,
        ),
      );
      final customerDs = OrderFlowFakeRemoteDataSource(
        view: OrderFlowActorView.customer,
        actorId: customerId,
        store: store,
      );

      final id = await customerRepo.createOrder(
        customerId: customerId,
        customerName: 'Cust',
        chefId: chefId,
        chefName: 'K',
        items: [
          {'name': 'D', 'quantity': 1, 'price': 2.0},
        ],
        totalAmount: 2,
      );
      expect((await chefRepo.getOrdersByStatus(OrderStatus.pending)).any((o) => o.id == id), isTrue);

      await customerDs.customerCancelPending(id);

      expect(await chefRepo.getOrdersByStatus(OrderStatus.pending), isEmpty);
      final o = await customerRepo.getOrderById(id);
      expect(o.status, OrderStatus.cancelled);
      expect(
        OrderDbStatus.customerFacingLabel(o.dbStatus, cancelReason: o.cancelReason),
        isNot(contains('Waiting')),
      );
    });
  });
}
