import 'package:test/test.dart';
import 'package:workmanager/src/workmanager_impl.dart';

void main() {
  group('convertPigeonInputData', () {
    test('handles null inputData', () {
      final result = convertPigeonInputData(null);
      expect(result, null);
    });

    test('filters null keys while preserving null values', () {
      final Map<String?, Object?> inputData = {
        'validKey': 'validValue',
        'nullValueKey': null,
        null: 'shouldBeFilteredOut',
        'numberKey': 42,
        'boolKey': true,
        'listKey': ['item1', 'item2'],
      };

      final result = convertPigeonInputData(inputData);

      expect(result, isNotNull);
      expect(result, isA<Map<String, dynamic>>());
      expect(result!.length, 5);

      expect(result['validKey'], 'validValue');
      expect(result['nullValueKey'], null);
      expect(result['numberKey'], 42);
      expect(result['boolKey'], true);
      expect(result['listKey'], ['item1', 'item2']);
      expect(result.containsKey(null), false);
    });

    test('handles empty inputData', () {
      final result = convertPigeonInputData({});

      expect(result, isNotNull);
      expect(result, isEmpty);
      expect(result, isA<Map<String, dynamic>>());
    });

    test('handles inputData with only null keys', () {
      final result = convertPigeonInputData({null: 'value1'});

      expect(result, isNotNull);
      expect(result, isEmpty);
      expect(result, isA<Map<String, dynamic>>());
    });

    test('handles mixed valid and invalid keys', () {
      final Map<String?, Object?> mixedData = {
        'key1': 'value1',
        null: 'nullKeyValue',
        'key2': null,
        '': 'emptyStringKey',
        'key3': 123,
      };

      final result = convertPigeonInputData(mixedData);

      expect(result!.length, 4);
      expect(result['key1'], 'value1');
      expect(result['key2'], null);
      expect(result[''], 'emptyStringKey');
      expect(result['key3'], 123);
      expect(result.containsKey(null), false);
    });

    test('preserves complex nested data structures', () {
      final Map<String?, Object?> complexData = {
        'mapKey': {'nested': 'value'},
        'listKey': [
          1,
          2,
          {'nested': 'list'}
        ],
        'nullKey': null,
        null: 'filtered',
      };

      final result = convertPigeonInputData(complexData);

      expect(result!.length, 3);
      expect(result['mapKey'], {'nested': 'value'});
      expect(result['listKey'], [
        1,
        2,
        {'nested': 'list'}
      ]);
      expect(result['nullKey'], null);
      expect(result.containsKey(null), false);
    });

    test('normalizes nested maps to Map<String, dynamic>', () {
      final Map<String?, Object?> inputData = {
        'nested': <dynamic, dynamic>{'string': 'value', 'int': 42},
      };

      final result = convertPigeonInputData(inputData);

      final nested = result!['nested'];
      expect(nested, isA<Map<String, dynamic>>());
      expect(nested, {'string': 'value', 'int': 42});
    });

    test('keeps the element type of homogeneous nested lists', () {
      final Map<String?, Object?> inputData = {
        'strings': ['a', 'b'],
        'ints': [1, 2],
        'doubles': [1.5, 2.5],
        'bools': [true, false],
      };

      final result = convertPigeonInputData(inputData);

      expect(result!['strings'], isA<List<String>>());
      expect(result['ints'], isA<List<int>>());
      expect(result['doubles'], isA<List<double>>());
      expect(result['bools'], isA<List<bool>>());
    });

    test('leaves heterogeneous or empty lists as List<dynamic>', () {
      final Map<String?, Object?> inputData = {
        'mixed': ['a', 1, true],
        'empty': <Object?>[],
      };

      final result = convertPigeonInputData(inputData);

      expect(result!['mixed'], isA<List<dynamic>>());
      expect(result['empty'], isA<List<dynamic>>());
      expect(result['empty'], isEmpty);
    });

    test('normalizes nested containers recursively', () {
      final Map<String?, Object?> inputData = {
        'outer': <dynamic, dynamic>{
          'innerList': ['x', 'y'],
          'innerMap': <dynamic, dynamic>{'deep': [1, 2, 3]},
        },
      };

      final result = convertPigeonInputData(inputData);

      final outer = result!['outer'] as Map<String, dynamic>;
      expect(outer['innerList'], isA<List<String>>());
      final innerMap = outer['innerMap'] as Map<String, dynamic>;
      expect(innerMap['deep'], isA<List<int>>());
    });
  });
}
