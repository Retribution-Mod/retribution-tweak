#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

NSURL *getPyoncordDirectory(void);
UIColor *hexToUIColor(NSString *hex);
void showErrorAlert(NSString *title, NSString *message);

/**
 * Reads the Hermes bytecode header version from in-memory data, or 0 if the data isn't Hermes
 * bytecode (e.g. plain JS source) or is too short to contain a header. This is the single source
 * of truth for "is this Hermes bytecode" - JSI.mm's evaluator uses it too, so bytecode detection
 * can never silently diverge between the two again.
 */
uint32_t hermesBytecodeVersionOfData(NSData *data);

/**
 * Same as hermesBytecodeVersionOfData, but reads from a file on disk.
 */
uint32_t hermesBytecodeVersionOfFile(NSString *path);

/**
 * Redact tokens and sensitive strings from a value before sending to Sentry.
 */
NSString *redactForSentry(NSString *value);

#ifdef __cplusplus
}
#endif