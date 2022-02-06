#import <Flutter/Flutter.h>

@interface WorkmanagerPlugin : NSObject<FlutterPlugin>

/** 
 * Register a custom task identifier to be scheduled/executed later on.
 * @author Tuyen Vu
 *
 * @param taskIdentifier The identifier of the custom task.
 */
+ (void)registerTaskWithIdentifier:(NSString *) taskIdentifier;

@end
