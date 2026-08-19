#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

NSURL *getPyoncordDirectory(void);
UIColor *hexToUIColor(NSString *hex);
void showErrorAlert(NSString *title, NSString *message);

#ifdef __cplusplus
}
#endif