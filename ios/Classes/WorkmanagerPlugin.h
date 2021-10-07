#import <Flutter/Flutter.h>

@interface WorkmanagerPlugin : NSObject<FlutterPlugin>

+ (void)registerTaskWithIdentifier:(NSString *) taskIdentifier;

@end
