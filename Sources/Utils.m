#import "Utils.h"
#import <string.h>

NSURL *getPyoncordDirectory(void) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentDirectoryURL = [[fileManager URLsForDirectory:NSDocumentDirectory 
                                                     inDomains:NSUserDomainMask] lastObject];
    
    NSURL *pyoncordFolderURL = [documentDirectoryURL URLByAppendingPathComponent:@"pyoncord"];
    
    if (![fileManager fileExistsAtPath:pyoncordFolderURL.path]) {
        [fileManager createDirectoryAtURL:pyoncordFolderURL
              withIntermediateDirectories:YES
                               attributes:nil
                                    error:nil];
    }
    
    return pyoncordFolderURL;
}

UIColor *hexToUIColor(NSString *hex) {
    if (![hex hasPrefix:@"#"]) {
        return nil;
    }
    
    NSString *hexColor = [hex substringFromIndex:1];
    if (hexColor.length == 6) {
        hexColor = [hexColor stringByAppendingString:@"ff"];
    }
    
    if (hexColor.length == 8) {
        unsigned int hexNumber;
        NSScanner *scanner = [NSScanner scannerWithString:hexColor];
        if ([scanner scanHexInt:&hexNumber]) {
            CGFloat r = ((hexNumber & 0xFF000000) >> 24) / 255.0;
            CGFloat g = ((hexNumber & 0x00FF0000) >> 16) / 255.0;
            CGFloat b = ((hexNumber & 0x0000FF00) >> 8) / 255.0;
            CGFloat a = (hexNumber & 0x000000FF) / 255.0;
            
            return [UIColor colorWithRed:r green:g blue:b alpha:a];
        }
    }
    
    return nil;
}

uint32_t hermesBytecodeVersionOfData(NSData *data) {
    static const uint8_t HERMES_MAGIC[8] = {0xc6, 0x1f, 0xbc, 0x03, 0xc1, 0x03, 0x19, 0x1f};

    if (data.length < 12) return 0;

    const uint8_t *bytes = (const uint8_t *)data.bytes;
    if (memcmp(bytes, HERMES_MAGIC, sizeof(HERMES_MAGIC)) != 0) return 0;

    uint32_t version;
    memcpy(&version, bytes + 8, sizeof(version));
    return CFSwapInt32LittleToHost(version);
}

uint32_t hermesBytecodeVersionOfFile(NSString *path) {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) return 0;

    NSData *header = [handle readDataOfLength:12];
    [handle closeFile];
    return hermesBytecodeVersionOfData(header);
}

void showErrorAlert(NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                     message:message
                                                              preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" 
                                                         style:UIAlertActionStyleDefault
                                                       handler:nil];
        
        [alert addAction:okAction];
        
        UIWindow *window = nil;
        NSArray *windows = [[UIApplication sharedApplication] windows];
        for (UIWindow *w in windows) {
            if (w.isKeyWindow) {
                window = w;
                break;
            }
        }
        
        [window.rootViewController presentViewController:alert animated:YES completion:nil];
    });
} 