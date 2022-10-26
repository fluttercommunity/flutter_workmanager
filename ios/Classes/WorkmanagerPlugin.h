#import <Flutter/Flutter.h>

@interface WorkmanagerPlugin : NSObject<FlutterPlugin>

/** 
 * Register a custom task identifier to be scheduled/executed later on.
 * @author Tuyen Vu
 *
 * @param taskIdentifier The identifier of the custom task.
 */
+ (void)registerTaskWithIdentifier:(NSString *) taskIdentifier;

/**
 * Register a custom task identifier to be iOS Background Task /executed later on.
 * @author Lars Huth
 *
 * @param taskIdentifier The identifier of the custom task. Must be set in info.plist
 */
+ (void)registerPeriodicTaskWithIdentifier:(NSString *) taskIdentifier;

@end
