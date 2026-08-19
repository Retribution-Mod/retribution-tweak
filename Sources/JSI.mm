#import "JSI.h"
#import "Logger.h"

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

BOOL isHermesBytecode(NSData *data) {
    if (data.length < 4) return NO;
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    return bytes[0] == 0x48 && bytes[1] == 0x42 && bytes[2] == 0x43 && bytes[3] == 0x01;
}

}

@implementation JSI

+ (void)evaluate:(NSData *)scriptData tag:(NSString *)tag runtime:(jsi::Runtime &)runtime {
    if (scriptData.length == 0) {
        return;
    }

    try {
        std::string sourceUrl(tag.UTF8String ?: "");

        if (isHermesBytecode(scriptData)) {
            auto buffer = std::make_shared<NSDataBuffer>(scriptData);
            auto prepared = runtime.prepareJavaScript(buffer, sourceUrl);
            runtime.evaluatePreparedJavaScript(prepared);
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

@end
