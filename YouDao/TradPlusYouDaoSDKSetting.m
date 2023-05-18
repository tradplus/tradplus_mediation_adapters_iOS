#import "TradPlusYouDaoSDKSetting.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import "YDSDKHeader.h"
#import "TPYouDaoAdapterBaseInfo.h"

@interface TradPlusYouDaoSDKSetting()

@end

@implementation TradPlusYouDaoSDKSetting

+ (TradPlusYouDaoSDKSetting *)sharedInstance
{
    static TradPlusYouDaoSDKSetting *setting = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        setting = [[TradPlusYouDaoSDKSetting alloc] init];
    });
    return setting;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        [self showAdapterInfo];
    }
    return self;
}

- (void)showAdapterInfo
{
    NSString *version = nil;
    NSMutableString *adapterInfo = [[NSMutableString alloc] init];
    [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"有道"];
    [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_YouDaoAdapter_Version];
    [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_YouDaoAdapter_PlatformSDK_Version];
    if(version != nil)
    {
        [adapterInfo appendFormat:@"Current version[当前sdk版本]:%@",version];
    }
    MSLogInfo(@"%@", adapterInfo);
}

- (BOOL)personalizedAd
{
    MSLogTrace(@"***********");
    MSLogTrace(@"YouDao OpenPersonalizedAd %@", @(gTPOpenPersonalizedAd));
    MSLogTrace(@"***********");
    return gTPOpenPersonalizedAd;
}

@end
