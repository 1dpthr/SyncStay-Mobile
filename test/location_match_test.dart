import 'package:flutter_test/flutter_test.dart';
import 'package:pbl_flutter/services/app_state.dart';

void main() {
  group('locationsMatch', () {
    test('ignores letter case', () {
      expect(AppState.locationsMatch('Lahore', 'lahore'), isTrue);
      expect(AppState.locationsMatch('LAHORE', 'Lahore, Punjab'), isTrue);
    });

    test('matches city with sub-area', () {
      expect(AppState.locationsMatch('Lahore', 'Lahore Township'), isTrue);
      expect(AppState.locationsMatch('lahore township', 'Lahore'), isTrue);
    });

    test('matches any area within the same city', () {
      expect(AppState.locationsMatch('Lahore', 'Johar Town, Lahore, Punjab'), isTrue);
      expect(AppState.locationsMatch('Model Town Lahore', 'Lahore'), isTrue);
    });

    test('does not match different cities', () {
      expect(AppState.locationsMatch('Karachi', 'Lahore Township'), isFalse);
      expect(AppState.locationsMatch('Islamabad', 'Lahore'), isFalse);
    });
  });
}
