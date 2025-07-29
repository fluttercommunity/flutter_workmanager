import 'package:test/test.dart';

void main() {
  group('inputData null handling logic', () {
    /// This function replicates the exact logic implemented in _WorkmanagerFlutterApiImpl.executeTask
    /// to test the null handling behavior that was fixed.
    Map<String, dynamic>? convertInputData(Map<String?, Object?>? inputData) {
      Map<String, dynamic>? convertedInputData;
      if (inputData != null) {
        convertedInputData = <String, dynamic>{};
        for (final entry in inputData.entries) {
          if (entry.key != null) {
            convertedInputData[entry.key!] = entry.value;
          }
        }
      }
      return convertedInputData;
    }

    test('handles null inputData correctly', () {
      final result = convertInputData(null);
      expect(result, null);
    });

    test('handles inputData with null keys and values correctly', () {
      // Create problematic input data that would cause the old cast() method to fail
      final Map<String?, Object?> problematicInputData = {
        'validKey': 'validValue',
        'nullValueKey': null,
        null: 'shouldBeFilteredOut', // null key should be filtered
        'numberKey': 42,
        'boolKey': true,
        'listKey': ['item1', 'item2'],
      };
      
      final result = convertInputData(problematicInputData);
      
      expect(result, isNotNull);
      expect(result, isA<Map<String, dynamic>>());
      
      // Verify valid keys and values were preserved
      expect(result!['validKey'], 'validValue');
      expect(result['nullValueKey'], null); // null values should be preserved
      expect(result['numberKey'], 42);
      expect(result['boolKey'], true);
      expect(result['listKey'], ['item1', 'item2']);
      
      // Verify null keys were filtered out
      expect(result.containsKey(null), false);
      expect(result.keys.every((key) => key.isNotEmpty), true);
      
      // Verify we have the expected number of entries (null key filtered out)
      expect(result.length, 5); // 6 original entries - 1 null key = 5
    });

    test('handles empty inputData correctly', () {
      final Map<String?, Object?> emptyInputData = {};
      
      final result = convertInputData(emptyInputData);
      
      expect(result, isNotNull);
      expect(result, isEmpty);
      expect(result, isA<Map<String, dynamic>>());
    });

    test('handles inputData with only null keys correctly', () {
      final Map<String?, Object?> onlyNullKeysData = {
        null: 'value1',
      };
      
      final result = convertInputData(onlyNullKeysData);
      
      expect(result, isNotNull);
      expect(result, isEmpty); // All null keys filtered out
      expect(result, isA<Map<String, dynamic>>());
    });

    test('handles inputData with mixed valid and invalid keys', () {
      final Map<String?, Object?> mixedData = {
        'key1': 'value1',
        null: 'nullKeyValue',
        'key2': null,
        '': 'emptyStringKey', // empty string is valid
        'key3': 123,
      };
      
      final result = convertInputData(mixedData);
      
      expect(result, isNotNull);
      expect(result!.length, 4); // 5 entries - 1 null key = 4
      expect(result['key1'], 'value1');
      expect(result['key2'], null);
      expect(result[''], 'emptyStringKey');
      expect(result['key3'], 123);
      expect(result.containsKey(null), false);
    });

    test('demonstrates safe handling vs unsafe cast approach', () {
      final Map<String?, Object?> problematicData = {
        'validKey': 'value',
        null: 'nullKey',
      };
      
      // The old implementation: inputData?.cast<String, dynamic>() 
      // This cast succeeds but creates a Map<String, dynamic> that still 
      // contains null keys, which can cause issues downstream
      final castResult = problematicData.cast<String, dynamic>();
      expect(castResult.containsKey(null), true); // Null key still present!
      
      // Our new implementation handles it safely by filtering null keys
      final result = convertInputData(problematicData);
      expect(result, isNotNull);
      expect(result!['validKey'], 'value');
      expect(result.containsKey(null), false); // Null key properly filtered
      
      // Demonstrate the difference in behavior
      expect(castResult.length, 2); // Cast preserves null key
      expect(result.length, 1); // Our method filters it out
    });
  });
}