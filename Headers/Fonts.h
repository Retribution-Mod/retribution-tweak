#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

extern NSMutableDictionary<NSString *, NSString *> *fontMap;
void patchFonts(NSDictionary<NSString *, NSString *> *mainFonts, NSString *fontDefName);

#ifdef __cplusplus
}
#endif