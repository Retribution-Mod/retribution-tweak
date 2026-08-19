#import <Foundation/Foundation.h>
#import <jsi/jsi.h>

@interface JSI : NSObject

+ (void)evaluate:(NSData *)scriptData tag:(NSString *)tag runtime:(facebook::jsi::Runtime &)runtime;

@end
