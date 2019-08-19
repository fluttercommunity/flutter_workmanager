#import "WorkmanagerPlugin.h"
#import <workmanager/workmanager-Swift.h>

@implementation WorkmanagerPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    [SwiftWorkmanagerPlugin registerWithRegistrar:registrar];
}

+ (void)setPluginRegistrantCallback:(FlutterPluginRegistrantCallback)callback {
    [SwiftWorkmanagerPlugin setPluginRegistrantCallback:callback];
}

@end
