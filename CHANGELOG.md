## 0.0.1

* Initial Release:
  * Schedule One off task
  * Schedule Periodic task
    * Fixed delay
  * Initial delay
  * Constraints
    * Support for 1 network type
    * requires battery not low
    * requires charging
    * requires device idle
    * requires storage not low
  * back off policy

## 0.0.2

* Remove the need to register a custom Application on Android side. (Everything still works in testing)

## 0.0.3

* Add Dart documentation

# 0.0.4

* Provide a better description so package scores higher on Pub

# 0.0.5

* The description was too big so you lose points for that too...

# 0.0.6

* Expose a WorkManagerHelper to the native.
  * This makes it easier if you also have some native code that wants to schedule the Echo Worker