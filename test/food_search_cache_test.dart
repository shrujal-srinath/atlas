import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/features/food/data/food_repository.dart';

void main() {
  group('searchCacheKey', () {
    test('is case-insensitive and trims whitespace', () {
      expect(searchCacheKey('  Chicken ', 40), searchCacheKey('chicken', 40));
      expect(searchCacheKey('PANEER', 25), 'paneer|25');
    });

    test(
      'separates by limit so a wider request never reuses a narrower one',
      () {
        expect(
          searchCacheKey('rice', 15) == searchCacheKey('rice', 40),
          isFalse,
        );
      },
    );

    test('distinct queries produce distinct keys', () {
      expect(searchCacheKey('oats', 40) == searchCacheKey('oat', 40), isFalse);
    });
  });
}
