#import <Foundation/Foundation.h>
#import <jsi/jsi.h>

@interface JSI : NSObject

/**
 * Evaluates scriptData in the given runtime.
 * If expectedHbcVersion is non-zero and the script is Hermes bytecode with a different version,
 * evaluation is skipped and an error is logged rather than crashing.
 * Pass 0 for expectedHbcVersion to skip version validation.
 */
+ (void)evaluate:(NSData *)scriptData tag:(NSString *)tag runtime:(facebook::jsi::Runtime &)runtime expectedHbcVersion:(uint32_t)expectedHbcVersion;

/// Convenience overload that skips HBC version validation.
+ (void)evaluate:(NSData *)scriptData tag:(NSString *)tag runtime:(facebook::jsi::Runtime &)runtime;

@end
