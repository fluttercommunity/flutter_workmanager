import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:get_it/get_it.dart';

import 'package:test/test.dart';
import 'package:workmanager/src/workmanager.dart';

import 'workmanager_test.mocks.dart';

const testTaskName = 'ios-background-task-name';

Future<bool> testCallBackDispatcher(task, inputData) {
  return Future.value(true);
}

void mySetUpWrapper() {
  GetIt.I<Workmanager>().initialize(testCallBackDispatcher);
  GetIt.I<Workmanager>().cancelAll();
  GetIt.I<Workmanager>().cancelByUniqueName(testTaskName);
}

@GenerateMocks([Workmanager])
void main() {
  group(
      "singleton pattern",
      () => {
            test("It always return the same workmanager instance", () {
              final workmanager = Workmanager();
              final workmanager2 = Workmanager();

              expect(workmanager == workmanager2, true);
            })
          });

  group("mocked workmanager", () {
    setUpAll(() {
      GetIt.I.registerSingleton<Workmanager>(MockWorkmanager());
    });
    test("cancelAll - It calls methods on the mocked class", () {
      mySetUpWrapper();

      verify(GetIt.I<Workmanager>().initialize(testCallBackDispatcher));
      verify(GetIt.I<Workmanager>().cancelAll());
    });

    test("cancelByUniqueName - It calls methods on the mocked class", () {
      mySetUpWrapper();

      verify(GetIt.I<Workmanager>().initialize(testCallBackDispatcher));
      verify(GetIt.I<Workmanager>().cancelByUniqueName(testTaskName));
    });
  });
}
