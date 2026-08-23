#import "Logger.h"
#import "Utils.h"
#import <SentryObjC/SentryObjC.h>
#include <stdarg.h>

void RetributionLog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *message = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);

    NSLog(@"%@ %@", LOG_PREFIX, message);

    NSURL *logDir = getPyoncordDirectory();
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:logDir.path]) {
        [fm createDirectoryAtURL:logDir withIntermediateDirectories:YES attributes:nil error:nil];
    }

    NSURL *logURL = [logDir URLByAppendingPathComponent:@"retribution.log"];
    if (![fm fileExistsAtPath:logURL.path]) {
        [fm createFileAtPath:logURL.path contents:nil attributes:nil];
    }

    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:logURL.path];
    if (file) {
        [file seekToEndOfFile];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [formatter stringFromDate:[NSDate date]], message];
        [file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [file closeFile];
    }

    if ([SentryObjCSDK isEnabled]) {
        SentryObjCBreadcrumb *crumb = [[SentryObjCBreadcrumb alloc] initWithLevel:SentryObjCLevelInfo category:@"retribution"];
        crumb.message = message;
        [SentryObjCSDK addBreadcrumb:crumb];
    }
}
