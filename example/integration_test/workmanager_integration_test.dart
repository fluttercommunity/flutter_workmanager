import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workmanager/workmanager.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    return true;
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('initialize & schedule task', (WidgetTester tester) async {
    final wm = Workmanager();
    await wm.initialize(callbackDispatcher);
    await wm.registerOneOffTask('taskId', 'taskName');
  });
}
