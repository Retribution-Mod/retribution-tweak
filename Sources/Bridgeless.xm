#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "JSI.h"
#import "Logger.h"
#import "Utils.h"
#import "LoaderConfig.h"
#import "Theme.h"
#import "Fonts.h"
#import "RCTHost.h"

%group RCTHostGroup

%hook RCTHost

- (void)instance:(id)instance didInitializeRuntime:(facebook::jsi::Runtime &)runtime {
    %orig;

    RetributionLog(@"RCTHost didInitializeRuntime (bridgeless/new arch)");

    LoaderConfig *loaderConfig = [LoaderConfig getLoaderConfig];
    [loaderConfig loadConfig];

    NSString *installPrefix = @"/var/jb";
    BOOL isJailbroken = [[NSFileManager defaultManager] fileExistsAtPath:installPrefix];
    NSString *jailbrokenBundlePath = [NSString stringWithFormat:@"%@/Library/Application Support/RetributionResources.bundle", installPrefix];
    NSString *jailedBundlePath = [[NSBundle mainBundle].bundleURL.path stringByAppendingPathComponent:@"RetributionResources.bundle"];
    NSString *retributionPatchesBundlePath = isJailbroken ? jailbrokenBundlePath : jailedBundlePath;

    NSBundle *retributionPatchesBundle = [NSBundle bundleWithPath:retributionPatchesBundlePath];
    if (!retributionPatchesBundle) {
        RetributionLog(@"Failed to load Retribution bundle from path: %@", retributionPatchesBundlePath);
        return;
    }

    NSURL *payloadPath = [retributionPatchesBundle URLForResource:@"payload-base" withExtension:@"js"];
    if (payloadPath) {
        NSData *payload = [NSData dataWithContentsOfURL:payloadPath];
        if (payload) {
            RetributionLog(@"Injecting bridgeless loader payload");
            [JSI evaluate:payload tag:@"retribution:payload" runtime:runtime];
        }
    }

    NSURL *pyoncordDirectory = getPyoncordDirectory();

    NSString *themeString = [NSString stringWithContentsOfURL:[pyoncordDirectory URLByAppendingPathComponent:@"current-theme.json"]
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];
    if (themeString) {
        NSString *jsCode = [NSString stringWithFormat:@"globalThis.__PYON_LOADER__.storedTheme=%@", themeString];
        [JSI evaluate:[jsCode dataUsingEncoding:NSUTF8StringEncoding] tag:@"retribution:theme" runtime:runtime];
    }

    NSData *fontData = [NSData dataWithContentsOfURL:[pyoncordDirectory URLByAppendingPathComponent:@"fonts.json"]];
    if (fontData) {
        NSError *jsonError;
        NSDictionary *fontDict = [NSJSONSerialization JSONObjectWithData:fontData options:0 error:&jsonError];
        if (!jsonError && fontDict[@"main"]) {
            RetributionLog(@"Found font configuration, applying...");
            patchFonts(fontDict[@"main"], fontDict[@"name"]);
        }
    }

    __block NSData *bundle = nil;

    NSURL *cachedBundlePath = [pyoncordDirectory URLByAppendingPathComponent:@"bundle-new.js"];
    bundle = [NSData dataWithContentsOfURL:cachedBundlePath];

    NSURL *localBundlePath = [retributionPatchesBundle URLForResource:@"bundle-new" withExtension:@"js"];
    if (!bundle && localBundlePath) {
        bundle = [NSData dataWithContentsOfURL:localBundlePath];
        if (bundle) {
            RetributionLog(@"Loaded embedded bundle from resources: %@", localBundlePath.absoluteString);
        }
    }

    NSURL *bundleUrl = loaderConfig.customLoadUrlEnabled && loaderConfig.customLoadUrl
        ? loaderConfig.customLoadUrl
        : [NSURL URLWithString:@"https://github.com/Retribution-Mod/retribution-bundle/releases/latest/download/retribution-new.min.js"];
    NSMutableURLRequest *bundleRequest = [NSMutableURLRequest requestWithURL:bundleUrl
                                                                 cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                             timeoutInterval:30.0];
    NSString *bundleEtag = [NSString stringWithContentsOfURL:[pyoncordDirectory URLByAppendingPathComponent:@"etag-new.txt"]
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];
    if (bundleEtag && bundle) {
        [bundleRequest setValue:bundleEtag forHTTPHeaderField:@"If-None-Match"];
    }

    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[session dataTaskWithRequest:bundleRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            RetributionLog(@"Failed to download bundle: %@", error);
        } else if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode == 200) {
                bundle = data;
                [bundle writeToURL:cachedBundlePath atomically:YES];

                NSString *etag = [httpResponse.allHeaderFields objectForKey:@"Etag"];
                if (etag) {
                    [etag writeToURL:[pyoncordDirectory URLByAppendingPathComponent:@"etag-new.txt"]
                          atomically:YES
                            encoding:NSUTF8StringEncoding
                               error:nil];
                }
            } else if (httpResponse.statusCode != 304) {
                RetributionLog(@"Bundle download returned status code %ld", (long)httpResponse.statusCode);
            }
        }
        dispatch_semaphore_signal(sem);
    }] resume];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

    if (bundle) {
        RetributionLog(@"Executing JS bundle in bridgeless runtime");
        [JSI evaluate:bundle tag:@"retribution:bundle" runtime:runtime];
    } else {
        RetributionLog(@"No bundle available in bridgeless runtime");
    }

    NSURL *preloadsDirectory = [pyoncordDirectory URLByAppendingPathComponent:@"preloads"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:preloadsDirectory.path]) {
        NSError *error = nil;
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:preloadsDirectory
                                                           includingPropertiesForKeys:nil
                                                                              options:0
                                                                                error:&error];
        if (!error) {
            for (NSURL *fileURL in contents) {
                if ([[fileURL pathExtension] isEqualToString:@"js"]) {
                    NSData *data = [NSData dataWithContentsOfURL:fileURL];
                    if (data) {
                        [JSI evaluate:data tag:fileURL.path runtime:runtime];
                    }
                }
            }
        } else {
            RetributionLog(@"Error reading contents of preloads directory");
        }
    }
}

%end

%end

%ctor {
    @autoreleasepool {
        Class cls = objc_getClass("RCTHost");
        BOOL newArchEnabled = cls != Nil;
        id rawValue = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"RCTNewArchEnabled"];
        if (rawValue) {
            newArchEnabled = [rawValue boolValue];
        }

        if (newArchEnabled && cls) {
            RetributionLog(@"RCTHost detected, installing bridgeless loader hook");
            %init(RCTHostGroup, RCTHost = cls);
        } else {
            RetributionLog(@"RCTHost not active, bridgeless loader not installed");
        }
    }
}
