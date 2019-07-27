import 'package:workmanager/workmanager.dart';

import 'constants.dart';

void customCallbackDispatcher() {
  Workmanager.defaultCallbackDispatcher((echoValue) {
    print("Native echoed: $echoValue");

    switch (echoValue) {
      case simpleTaskKey:
        print("$simpleTaskKey was executed");
        break;
      case simpleDelayedTask:
        print("$simpleDelayedTask was executed");
        break;
      case simplePeriodicTask:
        print("$simplePeriodicTask was executed");
        break;
      case simplePeriodic1HourTask:
        print("$simplePeriodic1HourTask was executed");
        break;
    }

    return Future.value(true);
  });
}
