#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

NSURL *getPyoncordDirectory(void);
UIColor *hexToUIColor(NSString *hex);
void showErrorAlert(NSString *title, NSString *message);

/**
 * Reads the Hermes bytecode header version from a file, or 0 if the file isn't Hermes bytecode
 * (e.g. plain JS source) or is too short to contain a header.
 */
uint32_t hermesBytecodeVersionOfFile(NSString *path);

#ifdef __cplusplus
}
#endif