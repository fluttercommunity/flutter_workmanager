import 'package:mockito/mockito.dart';
import 'package:get_it/get_it.dart';

import 'package:test/test.dart';
import 'package:workmanager/src/workmanager.dart';

class MockWorkmanager extends Mock implements Workmanager {}

Future<bool> testCallBackDispatcher(task, inputData) {
  return Future.value(true);
}

void mySetUpWrapper() {
  GetIt.I<Workmanager>().initialize(testCallBackDispatcher);
  GetIt.I<Workmanager>().cancelAll();
}

void main() {
  setUpAll(() {
    GetIt.I.registerSingleton<Workmanager>(MockWorkmanager());
  });

  test('testCallBackDispatcher calls the Workmanager executeTask method', () {
    mySetUpWrapper();

    verify(GetIt.I<Workmanager>().initialize(testCallBackDispatcher));
    verify(GetIt.I<Workmanager>().cancelAll());
  });
}