#import "WorkmanagerPlugin.h"

#if __has_include(<workmanager_apple/workmanager_apple-Swift.h>)
#import <workmanager_apple/workmanager_apple-Swift.h>
#else
#import "workmanager_apple-Swift.h"
#endif

@implementation WorkmanagerPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    [SwiftWorkmanagerPlugin registerWithRegistrar:registrar];
}

+ (void)setPluginRegistrantCallback:(FlutterPluginRegistrantCallback)callback {
    [SwiftWorkmanagerPlugin setPluginRegistrantCallback:callback];
}

// TODO this might not be needed anymore
+ (void)registerTaskWithIdentifier:(NSString *) taskIdentifier {
    if (@available(iOS 13, *)) {
        [SwiftWorkmanagerPlugin registerBGProcessingTaskWithIdentifier:taskIdentifier];
    }
}

+ (void)registerPeriodicTaskWithIdentifier:(NSString *)taskIdentifier frequency:(NSNumber *) frequency {
    if (@available(iOS 13, *)) {
        [SwiftWorkmanagerPlugin registerPeriodicTaskWithIdentifier:taskIdentifier frequency:frequency];
    }
}

+ (void)registerBGProcessingTaskWithIdentifier:(NSString *) taskIdentifier{
    if (@available(iOS 13, *)) {
        [SwiftWorkmanagerPlugin registerBGProcessingTaskWithIdentifier:taskIdentifier];
    }
}

@end
