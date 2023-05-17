#import "TPFacebookAdapterConfig.h"
#import <TradPlusAds/MSLogging.h>
#import <FBAudienceNetwork/FBAudienceNetwork.h>
#import <TradPlusAds/MsCommon.h>
#import "TPFacebookAdapterBaseInfo.h"

@implementation TPFacebookAdapterConfig

static bool coppa_setted = false;
+ (void)setCOPPAIsAgeRestrictedUser:(BOOL)isCOPPAChild
{
    if (!coppa_setted)
    {
        coppa_setted = true;
        MSLogTrace(@"%s set coppa %@", __PRETTY_FUNCTION__, isCOPPAChild?@"Y":@"N");
        [FBAdSettings setMixedAudience:isCOPPAChild];
    }
}

+ (void)setPrivacy:(NSDictionary *)info
{
    if (@available(iOS 14, *))
    {
        int att = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPATTEnableStorageKey];
        [FBAdSettings setAdvertiserTrackingEnabled:(att != 1)];
    }
    int coppa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCOPPAStorageKey];
    if (coppa != 0)
    {
        [FBAdSettings setMixedAudience:coppa == 2];
    }
    
    [TPFacebookAdapterConfig showAdapterInfo];
}

+ (void)showAdapterInfo
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *version = FB_AD_SDK_VERSION;
        NSMutableString *adapterInfo = [[NSMutableString alloc] init];
        [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"Meta"];
        [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_FacebookAdapter_Version];
        [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_FacebookAdapter_PlatformSDK_Version];
        if(version != nil)
        {
            [adapterInfo appendFormat:@"Current version[当前sdk版本]:%@",version];
        }
        MSLogInfo(@"%@", adapterInfo);
    });
}
@end
