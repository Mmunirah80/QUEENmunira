# Switching from mock data to backend

The app uses **mock datasources** for all features. When your backend is ready, switch without changing UI or providers.

## Current layout

- **Data:** `lib/features/<feature>/data/datasources/`
  - `<feature>_mock_datasource.dart` – mock data (can be removed or kept for tests).
  - `<feature>_remote_datasource.dart` – abstract interface (API will implement this).
- **Repository:** `lib/features/<feature>/data/repositories/<feature>_repository_impl.dart`
  - Default constructor uses the mock: `remoteDataSource ?? XxxMockDataSource()`.
- **Providers:** `lib/features/<feature>/presentation/providers/`
  - Use the repository only; no reference to mock vs remote.

## How to switch to the real backend

1. **Implement the remote datasource**  
   Create a class that implements the same interface as the mock (e.g. `OrdersRemoteDataSource`) and perform real API calls (e.g. with Dio).

2. **Inject it in the repository**  
   In the repository implementation, pass your API datasource instead of the mock, e.g.:

   ```dart
   // Before (mock)
   OrdersRepositoryImpl();

   // After (backend)
   OrdersRepositoryImpl(remoteDataSource: OrdersRemoteDataSourceImpl(dio: myDio));
   ```

3. **Where to inject**  
   Repositories are provided in Riverpod (e.g. `ordersRepositoryProvider`).  
   Either:
   - Override the provider to return `OrdersRepositoryImpl(remoteDataSource: YourApiImpl())`, or  
   - Use a flag/env (e.g. `useMock`) and in the provider return the repository with mock or remote datasource.

4. **Mock datasources**  
   You can delete the `*_mock_datasource.dart` files or keep them for unit/widget tests.

## Features and datasources

| Feature   | Repository impl              | Mock datasource           | Remote interface           |
|----------|------------------------------|---------------------------|----------------------------|
| Auth     | AuthRepositoryImpl           | AuthMockDataSource        | AuthRemoteDataSource       |
| Orders   | OrdersRepositoryImpl         | OrdersMockDataSource      | OrdersRemoteDataSource     |
| Menu     | MenuRepositoryImpl           | MenuMockDataSource        | MenuRemoteDataSource       |
| Chat     | ChatRepositoryImpl           | ChatMockDataSource        | ChatRemoteDataSource       |
| Reels    | ReelsRepositoryImpl          | ReelsMockDataSource       | ReelsRemoteDataSource      |
| Home     | HomeRepositoryImpl           | HomeMockDataSource        | HomeRemoteDataSource       |
| Profile  | ProfileRepositoryImpl        | ProfileMockDataSource     | ProfileRemoteDataSource    |
| Analytics| AnalyticsRepositoryImpl      | AnalyticsMockDataSource   | AnalyticsRemoteDataSource  |
| Documents| DocumentsRepositoryImpl      | DocumentsMockDataSource   | DocumentsRemoteDataSource  |

No changes are needed in providers or screens when switching; only the datasource passed into the repository changes.
