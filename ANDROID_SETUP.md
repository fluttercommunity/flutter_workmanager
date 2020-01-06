## Android Installation

In order for this plugin to work properly on Android, you will need to make a custom `Application`.  

this is the template for kotlin file/project.

### Kotlin (.kt)

```kotlin
package replace.me.with.your.package.name

import android.app.Application
import be.tramckrijte.workmanager.WorkmanagerPlugin
import io.flutter.embedding.android.FlutterEngineConfigurator
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class App : Application(), FlutterEngineConfigurator {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {

    }

    override fun onCreate() {
        super.onCreate()
        WorkmanagerPlugin.setPluginRegistrantCallback(this)
    }
}
```

or if you prefer Java, the template is below.
### Java (.java)

```java
package replace.me.with.your.package.name;

import be.tramckrijte.workmanager.WorkmanagerPlugin;
import android.app.Application;
import io.flutter.embedding.android.FlutterEngineConfigurator;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class App extends Application implements FlutterEngineConfigurator {
    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine);
    }

    @Override
    public void cleanUpFlutterEngine(FlutterEngine flutterEngine) {

    }

    @Override
    public void onCreate() {
        super.onCreate();
        WorkmanagerPlugin.setPluginRegistrantCallback(this);
    }
}
```

You will then need to register this `Application` in the `AndroidManifest.xml`.  
Also be sure to add the `flutterEmbedding` meta data flag inside the `application` tag.  

```xml
<meta-data
    android:name="flutterEmbedding"
    android:value="2" />
```  

Your complete `AndroidManifest.xml` should look similar to this:  

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools"
    package="replace.me.with.your.package.name">

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

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```

## Debug Mode

Debugging a background task can be difficult, Android decides when is the best time to run.  
There is no guaranteed way to enforce a run of a job even in debug mode.  

However to facilitate debugging, the plugin provides an `isInDebugMode` flag when initializing the plugin: `Workmanager.initialize(callbackDispatcher, isInDebugMode: true)`  

Once this flag is enabled you will receive a notification whenever a background task was triggered.  
This way you can keep track whether that task ran successfully or not.  

![example of android debug notification](.art/android_debug_notification.gif)
  
