import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/payee.dart';

void main() {
  group('Payee', () {
    test('should instantiate correctly', () {
      final now = DateTime.now();
      final payee = Payee(
        id: '1',
        name: 'Test Payee',
        autoCategoryId: 'cat1',
        createdAt: now,
      );

      expect(payee.id, '1');
      expect(payee.name, 'Test Payee');
      expect(payee.autoCategoryId, 'cat1');
      expect(payee.createdAt, now);
    });

    test('should use default values', () {
      const payee = Payee(
        id: '1',
        name: 'Test Payee',
      );

      expect(payee.id, '1');
      expect(payee.name, 'Test Payee');
      expect(payee.autoCategoryId, isNull);
      expect(payee.createdAt, isNull);
    });

    test('should support serialization', () {
      final now = DateTime(2023, 10, 1);
      final payee = Payee(
        id: '1',
        name: 'Test Payee',
        autoCategoryId: 'cat1',
        createdAt: now,
      );

      final json = payee.toJson();
      expect(json['id'], '1');
      expect(json['name'], 'Test Payee');
      expect(json['auto_category_id'], 'cat1');
      expect(json['created_at'], now.toIso8601String());

      final fromJson = Payee.fromJson(json);
      expect(fromJson.id, payee.id);
      expect(fromJson.name, payee.name);
      expect(fromJson.autoCategoryId, payee.autoCategoryId);
      expect(fromJson.createdAt, payee.createdAt);
    });
  });
}
