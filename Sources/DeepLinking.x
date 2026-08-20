#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <substrate.h>
#import "Utils.h"
#import "Logger.h"

static NSString *deeplinkType(NSURL *url) {
    if ([url.scheme isEqualToString:@"manager"]) {
        return [url.host isEqualToString:@"bundle"] ? @"bundle" : nil;
    }
    if ([@[@"plugin", @"theme", @"font"] containsObject:url.scheme]) {
        return url.scheme;
    }
    if ([url.scheme isEqualToString:@"retribution"]) {
        return url.host;
    }
    return nil;
}

static NSString *resolveInstallUrl(NSURL *url) {
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *item in components.queryItems) {
        if ([item.name isEqualToString:@"url"] && item.value.length > 0) {
            return item.value;
        }
    }

    if (!url.host || url.host.length == 0) return nil;

    BOOL hasDot = [url.host rangeOfString:@"."].location != NSNotFound;
    NSString *base = hasDot ? [NSString stringWithFormat:@"https://%@", url.host]
                            : [NSString stringWithFormat:@"https://%@.github.io", url.host];

    NSString *path = url.path ? [url.path stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]] : @"";
    if (path.length == 0) return nil;

    NSString *query = url.query ? [NSString stringWithFormat:@"?%@", url.query] : @"";

    if ([url.scheme isEqualToString:@"plugin"]) {
        return [NSString stringWithFormat:@"%@/%@/", base, path];
    }
    if ([url.scheme isEqualToString:@"theme"]) {
        if ([path hasSuffix:@".json"]) {
            return [NSString stringWithFormat:@"%@/%@%@", base, path, query];
        }
        return [NSString stringWithFormat:@"%@/%@.json%@", base, path, query];
    }
    if ([url.scheme isEqualToString:@"font"]) {
        return [NSString stringWithFormat:@"%@/%@%@", base, path, query];
    }
    if ([url.scheme isEqualToString:@"retribution"]) {
        if ([url.host isEqualToString:@"plugin"]) {
            return [NSString stringWithFormat:@"%@/%@/", base, path];
        }
        if ([url.host isEqualToString:@"theme"]) {
            if ([path hasSuffix:@".json"]) {
                return [NSString stringWithFormat:@"%@/%@%@", base, path, query];
            }
            return [NSString stringWithFormat:@"%@/%@.json%@", base, path, query];
        }
        if ([url.host isEqualToString:@"font"]) {
            return [NSString stringWithFormat:@"%@/%@%@", base, path, query];
        }
        if ([url.host isEqualToString:@"bundle"]) {
            return [NSString stringWithFormat:@"%@/%@%@", base, path, query];
        }
    }

    return nil;
}

static void saveLoaderConfig(NSString *bundleUrl) {
    NSURL *configUrl = [getPyoncordDirectory() URLByAppendingPathComponent:@"loader.json"];
    NSDictionary *json = @{
        @"customLoadUrl": @{
            @"enabled": @YES,
            @"url": bundleUrl ?: @""
        }
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    [data writeToURL:configUrl atomically:YES];
}

static void saveDeeplinkPayload(NSString *type, NSString *url) {
    NSURL *payloadUrl = [getPyoncordDirectory() URLByAppendingPathComponent:@"deeplink.json"];
    NSDictionary *json = @{
        @"type": type,
        @"url": url
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    [data writeToURL:payloadUrl atomically:YES];
}

static void showDeeplinkAlert(NSString *type) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Retribution"
                                                                   message:[NSString stringWithFormat:@"%@ deep link saved. Relaunch Discord to apply.", [type capitalizedString]]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];

    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    if (root) {
        [root presentViewController:alert animated:YES completion:nil];
    }
}

static void handleDeepLink(NSURL *url) {
    NSString *type = deeplinkType(url);
    if (!type) {
        RetributionLog(@"Ignoring unsupported deep link: %@", url.absoluteString);
        return;
    }

    NSString *installUrl = resolveInstallUrl(url);
    if (!installUrl) {
        RetributionLog(@"Could not resolve deep link: %@", url.absoluteString);
        return;
    }

    RetributionLog(@"Deep link type=%@ url=%@", type, installUrl);

    if ([type isEqualToString:@"bundle"]) {
        saveLoaderConfig(installUrl);
    } else {
        saveDeeplinkPayload(type, installUrl);
    }

    showDeeplinkAlert(type);
}

static BOOL (*origOpenUrlOptions)(id, SEL, UIApplication *, NSURL *, NSDictionary<UIApplicationOpenURLOptionsKey, id> *);
static BOOL retributionOpenUrlOptions(id self, SEL _cmd, UIApplication *app, NSURL *url, NSDictionary<UIApplicationOpenURLOptionsKey, id> *options) {
    if (url) handleDeepLink(url);
    return origOpenUrlOptions(self, _cmd, app, url, options);
}

static BOOL (*origContinueUserActivity)(id, SEL, UIApplication *, NSUserActivity *, void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable));
static BOOL retributionContinueUserActivity(id self, SEL _cmd, UIApplication *application, NSUserActivity *userActivity, void (^restorationHandler)(NSArray<id<UIUserActivityRestoring>> * _Nullable)) {
    if (userActivity.webpageURL) handleDeepLink(userActivity.webpageURL);
    return origContinueUserActivity(self, _cmd, application, userActivity, restorationHandler);
}

static void hookDeepLinkDelegate(id<UIApplicationDelegate> delegate) {
    if (!delegate) return;
    Class cls = [delegate class];

    MSHookMessageEx(
        cls,
        @selector(application:openURL:options:),
        (IMP)retributionOpenUrlOptions,
        (IMP *)&origOpenUrlOptions
    );

    MSHookMessageEx(
        cls,
        @selector(application:continueUserActivity:restorationHandler:),
        (IMP)retributionContinueUserActivity,
        (IMP *)&origContinueUserActivity
    );
}

%group DeepLinking

%hook UIApplication

- (void)setDelegate:(id<UIApplicationDelegate>)delegate {
    %orig;
    hookDeepLinkDelegate(delegate);
}

%end

%end

%ctor {
    @autoreleasepool {
        %init(DeepLinking);

        UIApplication *app = [UIApplication sharedApplication];
        if (app && app.delegate) {
            hookDeepLinkDelegate(app.delegate);
        }
    }
}
