#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Utils.h"
#import "Logger.h"
#import "Theme.h"
#import "Fonts.h"
#import "LoaderConfig.h"

static NSURL *source;
static BOOL isJailbroken;
static NSString *retributionPatchesBundlePath;
static NSURL *pyoncordDirectory;
static LoaderConfig *loaderConfig;

%hook RCTCxxBridge

- (void)executeApplicationScript:(NSData *)script url:(NSURL *)url async:(BOOL)async {
    if (![url.absoluteString containsString:@"main.jsbundle"]) {
        return %orig;
    }

    NSBundle *retributionPatchesBundle = [NSBundle bundleWithPath:retributionPatchesBundlePath];
    if (!retributionPatchesBundle) {
        RetributionLog(@"Failed to load RetributionPatches bundle from path: %@", retributionPatchesBundlePath);
        showErrorAlert(@"Loader Error", @"Failed to initialize mod loader. Please reinstall the tweak.");
        return %orig;
    }

    NSURL *patchPath = [retributionPatchesBundle URLForResource:@"payload-base" withExtension:@"js"];
    if (!patchPath) {
        RetributionLog(@"Failed to find payload-base.js in bundle");
        showErrorAlert(@"Loader Error", @"Failed to initialize mod loader. Please reinstall the tweak.");
        return %orig;
    }

    NSData *patchData = [NSData dataWithContentsOfURL:patchPath];
    RetributionLog(@"Injecting loader");
    %orig(patchData, source, YES);

    __block NSData *bundle = nil;

    NSURL *localBundlePath = [retributionPatchesBundle URLForResource:@"bundle" withExtension:@"js"];
    if (localBundlePath) {
        bundle = [NSData dataWithContentsOfURL:localBundlePath];
        if (bundle) {
            RetributionLog(@"Loaded embedded bundle from resources: %@", localBundlePath.absoluteString);
        }
    }

    if (!bundle) {
        bundle = [NSData dataWithContentsOfURL:[pyoncordDirectory URLByAppendingPathComponent:@"bundle.js"]];
    }

    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    NSURL *bundleUrl;
    if (loaderConfig.customLoadUrlEnabled && loaderConfig.customLoadUrl) {
        bundleUrl = loaderConfig.customLoadUrl;
        RetributionLog(@"Using custom load URL: %@", bundleUrl.absoluteString);
    } else {
        bundleUrl = [NSURL URLWithString:@"https://github.com/Retribution-Mod/retribution-bundle/releases/latest/download/retribution.min.js"];
        RetributionLog(@"Using default bundle URL: %@", bundleUrl.absoluteString);
    }

    NSMutableURLRequest *bundleRequest = [NSMutableURLRequest requestWithURL:bundleUrl
                                                               cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                           timeoutInterval:30.0];

    NSString *bundleEtag = [NSString stringWithContentsOfURL:[pyoncordDirectory URLByAppendingPathComponent:@"etag.txt"]
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
    if (bundleEtag && bundle) {
        [bundleRequest setValue:bundleEtag forHTTPHeaderField:@"If-None-Match"];
    }

    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    [[session dataTaskWithRequest:bundleRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            RetributionLog(@"Failed to download bundle: %@", error);
        } else if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode == 200) {
                bundle = data;
                [bundle writeToURL:[pyoncordDirectory URLByAppendingPathComponent:@"bundle.js"] atomically:YES];

                NSString *etag = [httpResponse.allHeaderFields objectForKey:@"Etag"];
                if (etag) {
                    [etag writeToURL:[pyoncordDirectory URLByAppendingPathComponent:@"etag.txt"]
                         atomically:YES
                           encoding:NSUTF8StringEncoding
                              error:nil];
                }
            } else {
                RetributionLog(@"Bundle download returned status code %ld", (long)httpResponse.statusCode);
            }
        } else {
            RetributionLog(@"Bundle download returned non-HTTP response: %@", response);
        }
        dispatch_group_leave(group);
    }] resume];

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    if (!bundle) {
        RetributionLog(@"No bundle available; Retribution will not load");
    }

    NSString *themeString = [NSString stringWithContentsOfURL:[pyoncordDirectory URLByAppendingPathComponent:@"current-theme.json"]
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];
    if (themeString) {
        NSString *jsCode = [NSString stringWithFormat:@"globalThis.__PYON_LOADER__.storedTheme=%@", themeString];
        %orig([jsCode dataUsingEncoding:NSUTF8StringEncoding], source, async);
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

    if (bundle) {
        RetributionLog(@"Executing JS bundle");
        %orig(bundle, source, async);
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
                    RetributionLog(@"Executing preload JS file %@", fileURL.absoluteString);
                    NSData *data = [NSData dataWithContentsOfURL:fileURL];
                    if (data) {
                        %orig(data, source, async);
                    }
                }
            }
        } else {
            RetributionLog(@"Error reading contents of preloads directory");
        }
    }

    %orig(script, url, async);
}

%end

%ctor {
    @autoreleasepool {
        source = [NSURL URLWithString:@"retribution"];

        NSString *install_prefix = @"/var/jb";
        isJailbroken = [[NSFileManager defaultManager] fileExistsAtPath:install_prefix];

        NSString *bundlePath = [NSString stringWithFormat:@"%@/Library/Application Support/RetributionResources.bundle", install_prefix];
        RetributionLog(@"Is jailbroken: %d", isJailbroken);
        RetributionLog(@"Bundle path for jailbroken: %@", bundlePath);

        NSString *jailedPath = [[NSBundle mainBundle].bundleURL.path stringByAppendingPathComponent:@"RetributionResources.bundle"];
        RetributionLog(@"Bundle path for jailed: %@", jailedPath);

        retributionPatchesBundlePath = isJailbroken ? bundlePath : jailedPath;
        RetributionLog(@"Selected bundle path: %@", retributionPatchesBundlePath);

        BOOL bundleExists = [[NSFileManager defaultManager] fileExistsAtPath:retributionPatchesBundlePath];
        RetributionLog(@"Bundle exists at path: %d", bundleExists);

        NSError *error = nil;
        NSArray *bundleContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:retributionPatchesBundlePath error:&error];
        if (error) {
            RetributionLog(@"Error listing bundle contents: %@", error);
        } else {
            RetributionLog(@"Bundle contents: %@", bundleContents);
        }

pyoncordDirectory = getPyoncordDirectory();
        loaderConfig = [[LoaderConfig alloc] init];
        [loaderConfig loadConfig];
        
        %init;
    }
}
