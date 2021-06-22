import 'dart:io';

import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:workmanager/workmanager.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    return true;
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Workmanager workmanager;

  setUp(() async {
    workmanager = Workmanager();
    await workmanager.initialize(callbackDispatcher);
  });

  test('registerOneOffTask', () async {
    await workmanager.registerOneOffTask(
      'unique1',
      'one-off',
      initialDelay: Duration(seconds: 5),
    );
    await workmanager.cancelAll();
  });
  test('registerPeriodicTask', () async {
    await workmanager.registerPeriodicTask(
      'periodic1',
      'one-off',
      initialDelay: Duration(seconds: 5),
    );
    await workmanager.cancelAll();
  }, skip: !Platform.isAndroid);

  test('cancelByUniqueName', () async {
    await workmanager.registerPeriodicTask(
      'periodic2',
      'one-off',
      initialDelay: Duration(seconds: 5),
    );
    await workmanager.cancelByUniqueName('periodic2');
  }, skip: !Platform.isAndroid);
}
