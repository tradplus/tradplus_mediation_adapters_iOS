#import "TradPlusBaiduSDKSetting.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <BaiduMobAdSDK/BaiduMobAdSetting.h>
#import "TPBaiduAdapterBaseInfo.h"

@interface TradPlusBaiduSDKSetting()

@property (nonatomic, assign) BOOL openPersonalizedAd;
@end

@implementation TradPlusBaiduSDKSetting

+ (TradPlusBaiduSDKSetting *)sharedInstance
{
    static TradPlusBaiduSDKSetting *setting = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        setting = [[TradPlusBaiduSDKSetting alloc] init];
    });
    return setting;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.openPersonalizedAd = YES;
        [self showAdapterInfo];
    }
    return self;
}

- (void)showAdapterInfo
{
    NSString *version = SDK_VERSION_IN_MSSP;
    NSMutableString *adapterInfo = [[NSMutableString alloc] init];
    [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"百度"];
    [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_BaiduAdapter_Version];
    [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_BaiduAdapter_PlatformSDK_Version];
    if(version != nil)
    {
        [adapterInfo appendFormat:@"Current version[当前sdk版本]:%@",version];
    }
    MSLogInfo(@"%@", adapterInfo);
}


- (void)setPersonalizedAd
{
    if(self.openPersonalizedAd != gTPOpenPersonalizedAd)
    {
        self.openPersonalizedAd = gTPOpenPersonalizedAd;
        MSLogTrace(@"***********");
        MSLogTrace(@"Baidu OpenPersonalizedAd %@", @(self.openPersonalizedAd));
        MSLogTrace(@"***********");
        [[BaiduMobAdSetting sharedInstance] setLimitBaiduPersonalAds:self.openPersonalizedAd];
    }
}

@end
