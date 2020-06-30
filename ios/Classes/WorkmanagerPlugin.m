#import "WorkmanagerPlugin.h"

#if __has_include(<workmanager/workmanager-Swift.h>)
#import <workmanager/workmanager-Swift.h>
#else
#import "workmanager-Swift.h"
#endif

@implementation WorkmanagerPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    [SwiftWorkmanagerPlugin registerWithRegistrar:registrar];
}

+ (void)setPluginRegistrantCallback:(FlutterPluginRegistrantCallback)callback {
    [SwiftWorkmanagerPlugin setPluginRegistrantCallback:callback];
}

@end
