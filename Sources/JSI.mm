#import "JSI.h"
#import "Logger.h"
#import "Utils.h"

using namespace facebook;

namespace {

class NSDataBuffer : public jsi::Buffer {
public:
    explicit NSDataBuffer(NSData *data) : data_(data) {}

    size_t size() const override {
        return data_.length;
    }

    const uint8_t *data() const override {
        return static_cast<const uint8_t *>(data_.bytes);
    }

private:
    NSData *data_;
};

}

@implementation JSI

+ (void)evaluate:(NSData *)scriptData tag:(NSString *)tag runtime:(jsi::Runtime &)runtime expectedHbcVersion:(uint32_t)expectedHbcVersion {
    if (scriptData.length == 0) {
        return;
    }

    try {
        std::string sourceUrl(tag.UTF8String ?: "");

        uint32_t hbcVersion = hermesBytecodeVersionOfData(scriptData);
        if (hbcVersion != 0) {
            if (expectedHbcVersion != 0 && hbcVersion != expectedHbcVersion) {
                RetributionLog(@"[JSI] Skipping '%@': HBC version mismatch (got %u, expected %u). Evaluating as-is would crash.", tag, hbcVersion, expectedHbcVersion);
                return;
            }
            auto buffer = std::make_shared<NSDataBuffer>(scriptData);
            runtime.evaluateJavaScript(buffer, sourceUrl);
        } else {
            std::string source((const char *)scriptData.bytes, scriptData.length);
            auto buffer = std::make_shared<jsi::StringBuffer>(std::move(source));
            runtime.evaluateJavaScript(buffer, sourceUrl);
        }
    } catch (const jsi::JSError &e) {
        RetributionLog(@"[JSI] JSError for '%@': %s", tag, e.what());
    } catch (const std::exception &e) {
        RetributionLog(@"[JSI] exception for '%@': %s", tag, e.what());
    }
}

+ (void)evaluate:(NSData *)scriptData tag:(NSString *)tag runtime:(jsi::Runtime &)runtime {
    [self evaluate:scriptData tag:tag runtime:runtime expectedHbcVersion:0];
}

@end
