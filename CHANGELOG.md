# 0.2.4
* Restore iOS compatibility for Flutter 1.20

# 0.2.3
* Define iOS module so that host apps without use_frameworks! setting can consume the iOS module 
* wrap engine.destroy() call in isInitialized [#182](https://github.com/vrtdev/flutter_workmanager/pull/182)

# 0.2.2
* Android:
    * Fix crash when FlutterEngine would be destroyed twice  

# 0.2.1
* Android:
    * Fix example building  
    * Cleanup FlutterEngine when job is stopped or cancelled [#140]((https://github.com/vrtdev/flutter_workmanager/issues/140)),

# 0.2.0
* Android:
    * Adding support for the `Android v2 embedding`.  
      See more details in the Android setup guide.
    
# 0.1.5
 * Android:
    * The result was not correctly mapped to a RETRY when returning false from a background task 

# 0.1.4
 * Android:
    * Using Backoff Policy in conjunction with device idle constraint is an illegal action.  
      Backoff policy is now nullable in the Android code. See issue [#107](https://github.com/vrtdev/flutter_workmanager/issues/107).

# 0.1.3

* iOS & Android:
  * Result of `BackgroundTaskHandler` now correctly returns to background method channel
* iOS:
  * Invoking `iOSPerformFetch` method now no longer crashes
  * The iOS example app now  implements `setPluginRegistrantCallback` as described in our docs, making it possible to access other plugins during a backround fetch
  * Dart debug logging is now visible again in Xcode's console
  
# 0.1.2

* Android:
  * Added support for inputData

# 0.1.1

* iOS:
  * Added support for Flutter 1.9.1

# 0.1.0
* First API stable release
* Android: 
    * Improved debug notification with result message first
    * Updated Installation README
* iOS:
    * 🐞 Improved debug notification delivery when the app is in the background.
    * Updated Installation README 

# 0.0.15
* iOS: 🐞 Make sure all the implementers plugins are available in the background isolate by registering them first.  
  This requires the user to provide us with the generated registry in the `AppDelegate`
* iOS: 📝 specified minimum deployment target of iOS 10 (with Swift 4.2)

# 0.0.14
* iOS performBackgroundFetch now actually works.

# 0.0.13
* [‼️ BREAKING change]
  You will need to clear the preferences or re-install the App if you had registered jobs already on Android.
* Android:
    * Thanks to [@vanlooverenkoen](https://github.com/vanlooverenkoen) 
        * 🐞 cancelling all task would have failed before this version
        * 📝 Update documentation to be a bit more clear about the minimum frequency a periodic can be scheduled
    * Better debug notification support:
        * Emoji's to quickly see if a task ran successful
        * Elapsed time
        * Collapsing notifications
    * General Internal API renames to improve readability
* iOS
    * ⬆️ Separate UserDefaults for the plugin
    * 🐞 Memory leak resources cleanup
    * 🐞 Result mapping Dart -> Swift was wrong
    * Better debug notification support:
        * Emoji's to quickly see if a task ran successful
        * Elapsed time
        * Collapsing notifications   

# 0.0.12

* 🐞 expose `setPluginRegistrantCallback` to the old rusty Java people 

# 0.0.11

* Better README and docs
  * Everything now refers to the top level callback as the *callbackDispatcher* 
  * Some typo's 
  * Link to [Medium blog](https://medium.com/vrt-digital-studio/flutter-workmanager-81e0cfbd6f6e) post
* Adds unit tests to the project since the many issues with enum parsing
  * Fixes an issue with the parsing of the `NetworkType`
* Project restructure to a `src` folder 

# 0.0.10

* I should test a little better before publishing to pub.dev.
  * Fixes all enum parsing issues with `ExistingWorkPolicy` and `BackoffPolicy`

# 0.0.9

* A bugfix were parsing the `BackOffPolicy` was still wrong. 

# 0.0.8

* A bugfix were parsing of the `ExistingWorkPolicy` and `BackoffPolicy` went rogue.  Addresses [#9](https://github.com/vrtdev/flutter_workmanager/issues/9)

# 0.0.7

* This version is the first version to support iOS with the help of the Background Fetch API.  
  * Only recurring tasks can be scheduled by iOS.
  * If you want to respond to iOS background triggers you should add the extra case `Workmanager.iOSBackgroundTask` to your switch case.
* [‼️ BREAKING change]
  * `Workmanager.defaultCallbackDispatcher` becomes `Workmanager.executeTask` 
* This version was used as referenced in the [Medium blogpost](https://medium.com/vrt-digital-studio/flutter-workmanager-81e0cfbd6f6e)
  
# 0.0.6+2

* Fixes a bug in which you could not use other plugins inside a `EchoCallbackFunction`.
  * Fixes [#6](https://github.com/vrtdev/flutter_workmanager/issues/6)
  * Fixes [#4](https://github.com/vrtdev/flutter_workmanager/issues/4)
  * [‼️ BREAKING change] A user should extend a custom `Application` and register it in its `AndroidManifest.xml`

    ```kotlin
    class App : FlutterApplication(), PluginRegistry.PluginRegistrantCallback {
        override fun onCreate() {
            super.onCreate()
            WorkmanagerPlugin.setPluginRegistrantCallback(this)
        }
    
        override fun registerWith(reg: PluginRegistry?) {
            GeneratedPluginRegistrant.registerWith(reg)
        }
    }
    ```
    
    ```xml
    <manifest xmlns:android="http://schemas.android.com/apk/res/android"
        xmlns:tools="http://schemas.android.com/tools"
        package="be.tramckrijte.workmanager_example">
    
        <!-- io.flutter.app.FlutterApplication is an android.app.Application that
             calls FlutterMain.startInitialization(this); in its onCreate method.
             In most cases you can leave this as-is, but you if you want to provide
             additional functionality it is fine to subclass or reimplement
             FlutterApplication and put your custom class here. -->
        <application
            android:name=".App" <!-- Replace io.flutter.app.FlutterApplication with .App -->
            android:icon="@mipmap/ic_launcher"
            android:label="workmanager_example"
            tools:replace="android:name">
            <activity
                android:name=".MainActivity"
                android:configChanges="orientation|keyboardHidden|keyboard|screenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
                android:hardwareAccelerated="true"
                android:launchMode="singleTop"
                android:theme="@style/LaunchTheme"
                android:windowSoftInputMode="adjustResize">
                <!-- This keeps the window background of the activity showing
                     until Flutter renders its first frame. It can be removed if
                     there is no splash screen (such as the default splash screen
                     defined in @style/LaunchTheme). -->
                <meta-data
                    android:name="io.flutter.app.android.SplashScreenUntilFirstFrame"
                    android:value="true" />
                <intent-filter>
                    <action android:name="android.intent.action.MAIN" />
                    <category android:name="android.intent.category.LAUNCHER" />
                </intent-filter>
            </activity>
        </application>
    </manifest>
    ```
    
# 0.0.6+1

* This version is the first version to support iOS with the help of the Background Fetch API.  
  * Only recurring tasks can be scheduled by iOS.
  * If you want to respond to iOS background triggers you should add the extra case `Workmanager.iOSBackgroundTask` to your switch case.
* [‼️ BREAKING change]
  * `Workmanager.defaultCallbackDispatcher` becomes `Workmanager.executeTask`
  
# 0.0.6

* Expose a WorkManagerHelper to the native.
  * This makes it easier if you also have some native code that wants to schedule the Echo Worker
  
# 0.0.5

* The description was too big so you lose points for that too...

# 0.0.4

* Provide a better description so package scores higher on Pub

# 0.0.3

* Add Dart documentation

# 0.0.2

* Remove the need to register a custom Application on Android side. (Everything still works in testing)

# 0.0.1

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

