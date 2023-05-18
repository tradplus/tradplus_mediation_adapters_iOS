#import "TradPlusYandexAdapter.h"
#import <TradPlusAds/MSConsentManager.h>
#import <YandexMobileAds/YandexMobileAds.h>
#import "TradPlusYandexSDKSetting.h"
#import <TradPlusAds/MSLogging.h>

@interface TradPlusYandexAdapter()

@property (nonatomic,copy)NSString *yandexToken;
@property (nonatomic)YMABidderTokenLoader *loader;
@end

@implementation TradPlusYandexAdapter

+(TradPlusYandexAdapter *)sharedInstance
{
    static TradPlusYandexAdapter *adapter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        adapter = [[TradPlusYandexAdapter alloc] init];
    });
    return adapter;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.loader = [[YMABidderTokenLoader alloc] init];
    }
    return self;
}

+ (NSString *)getBuyeruidWithInfo:(NSDictionary *)infoDic
{
    return [TradPlusYandexAdapter sharedInstance].yandexToken;
}

+ (NSString *)sdkVersion
{
    return [YMAMobileAds SDKVersion];
}

+ (void)initSDKWithInfo:(NSDictionary *)infoDic callback:(void(^)(void))callback
{
    [TradPlusYandexSDKSetting showAdapterInfo];
    [TradPlusYandexAdapter sharedInstance].yandexToken = nil;
    [[TradPlusYandexAdapter sharedInstance].loader loadBidderTokenWithCompletionHandler:^(NSString * _Nullable bidderToken) {
        [TradPlusYandexAdapter sharedInstance].yandexToken = bidderToken;
        if (callback)
        {
            callback();
        }
    }];
}

@end
