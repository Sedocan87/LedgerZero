/// Runs a group of repository calls atomically.
///
/// Every multi-step write in the domain layer (transfers, splits, deletes
/// with reference cleanup, moving money, schedule catch-up, ...) goes
/// through [run]: either all of its writes are committed or none are.
///
/// The data-layer implementation wraps a database transaction; repositories
/// called inside [run] automatically take part in it (drift routes queries
/// issued inside a transaction block to that transaction). Calls may nest:
/// an inner [run] (or a repository that opens its own transaction) becomes a
/// savepoint of the outer one, so a failing inner block rolls back with the
/// outer unit of work.
abstract class UnitOfWork {
  /// Runs [action] atomically and returns its result. If [action] throws,
  /// all writes it made are rolled back and the error is rethrown.
  Future<T> run<T>(Future<T> Function() action);
}

/// A [UnitOfWork] without a database: runs [action] directly.
///
/// Only for unit tests whose repositories are mocks.
class ImmediateUnitOfWork implements UnitOfWork {
  const ImmediateUnitOfWork();

  @override
  Future<T> run<T>(Future<T> Function() action) => action();
}
