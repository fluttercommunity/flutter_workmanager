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
 * Register a custom task identifier as  iOS BGAppRefresh Task executed randomly in future.
 * @author Lars Huth
 *
 * @param taskIdentifier The identifier of the custom task. Must be set in info.plist
 * @param frequency The repeat frequency in seconds
 */
+ (void)registerPeriodicTaskWithIdentifier:(NSString *) taskIdentifier frequency:(NSNumber *) frequency;

/**
 * Register a custom task identifier as iOS BackgroundProcessingTask executed randomly in future.
 * @author Lars Huth
 *
 * @param taskIdentifier The identifier of the custom task. Must be set in info.plist
 */
+ (void)registerBGProcessingTaskWithIdentifier:(NSString *) taskIdentifier;


@end
