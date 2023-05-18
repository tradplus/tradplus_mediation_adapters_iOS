#import "TradPlusMyTargetSDKSetting.h"
#import <MyTargetSDK/MyTargetSDK.h>
#import <TradPlusAds/MSConsentManager.h>
#import <TradPlusAds/MSLogging.h>
#import "TPMyTargetAdapterBaseInfo.h"

@implementation TradPlusMyTargetSDKSetting


+ (void)setPrivacy
{
    BOOL gdpr = [MSConsentManager sharedManager].canCollectPersonalInfo;
    [MTRGPrivacy setUserConsent:gdpr];
    int ccpa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCCPAStorageKey];
    if (ccpa != 0)
        [MTRGPrivacy setCcpaUserConsent:ccpa == 2];
    int coppa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCOPPAStorageKey];
    if (coppa != 0)
        [MTRGPrivacy setUserAgeRestricted:coppa == 2];
    
    [TradPlusMyTargetSDKSetting showAdapterInfo];
    
}

+ (void)showAdapterInfo
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *version = [MTRGVersion currentVersion];
        NSMutableString *adapterInfo = [[NSMutableString alloc] init];
        [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"MyTarget"];
        [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_MyTargetAdapter_Version];
        [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_MyTargetAdapter_PlatformSDK_Version];
        if(version != nil)
        {
            [adapterInfo appendFormat:@"Current version[当前sdk版本]:%@",version];
        }
        MSLogInfo(@"%@", adapterInfo);
    });
}
@end
