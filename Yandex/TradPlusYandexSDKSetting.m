#import "TradPlusYandexSDKSetting.h"
#import <YandexMobileAds/YandexMobileAds.h>
#import <TradPlusAds/MSConsentManager.h>
#import <TradPlusAds/MSLogging.h>
#import "TPYandexAdapterBaseInfo.h"

@implementation TradPlusYandexSDKSetting


+ (void)setPrivacy
{
    BOOL bo = [MSConsentManager sharedManager].canCollectPersonalInfo;
    [YMAMobileAds setUserConsent: bo];
    
    [TradPlusYandexSDKSetting showAdapterInfo];
    
    MSLogTrace(@"Yandex set gdpr:%d", bo);
    
}

+ (void)showAdapterInfo
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *version = [YMAMobileAds SDKVersion];
        NSMutableString *adapterInfo = [[NSMutableString alloc] init];
        [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"Yandex"];
        [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_YandexAdapter_Version];
        [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_YandexAdapter_PlatformSDK_Version];
        if(version != nil)
        {
            [adapterInfo appendFormat:@"Current version[当前sdk版本]:%@",version];
        }
        MSLogInfo(@"%@", adapterInfo);
    });
}
@end
