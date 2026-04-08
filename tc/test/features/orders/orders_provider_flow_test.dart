import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:naham_cook_app/features/orders/domain/entities/order_entity.dart';
import 'package:naham_cook_app/features/orders/presentation/providers/orders_provider.dart';

import 'support/order_flow_test_infrastructure.dart';

void main() {
  const chefId = '22222222-2222-4222-8222-222222222222';
  const customerId = 'e2000001-0000-4000-8000-0000000000d1';

  test('pendingOrdersProvider returns chef-scoped pending rows from fake', () async {
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

    await OrdersRepositoryImpl(remoteDataSource: customerDs).createOrder(
      customerId: customerId,
      customerName: 'Riverpod Customer',
      chefId: chefId,
      chefName: 'Kitchen',
      items: [
        {'name': 'Item', 'quantity': 1, 'price': 12.0},
      ],
      totalAmount: 12,
    );

    final container = ProviderContainer(
      overrides: [
        ordersRepositoryProvider.overrideWith(
          (ref) => OrdersRepositoryImpl(remoteDataSource: chefDs),
        ),
      ],
    );
    addTearDown(container.dispose);

    final pending = await container.read(pendingOrdersProvider.future);
    expect(pending, isNotEmpty);
    expect(pending.first.chefId, chefId);
    expect(pending.first.status, OrderStatus.pending);
  });
}
