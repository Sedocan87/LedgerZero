/// Represents a payee in the LedgerZero application.
///
/// A payee is the entity to whom money is paid or from whom money is received.
class Payee {
  /// The unique identifier of the payee.
  final String id;

  /// The name of the payee.
  final String name;

  /// The unique identifier of the default category for this payee.
  final String? autoCategoryId;

  /// The date and time when the payee was created.
  final DateTime? createdAt;

  /// Creates a new [Payee] instance.
  const Payee({
    required this.id,
    required this.name,
    this.autoCategoryId,
    this.createdAt,
  });
}
