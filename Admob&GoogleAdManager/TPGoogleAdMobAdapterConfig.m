#import "TPGoogleAdMobAdapterConfig.h"
#import <GoogleMobileAds/GoogleMobileAds.h>
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import "TPAdMobAdapterBaseInfo.h"

@implementation TPGoogleAdMobAdapterConfig

+ (void)setPrivacy:(NSDictionary *)info
{
    int ccpa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCCPAStorageKey];
    if (ccpa != 0)
        [NSUserDefaults.standardUserDefaults setBool:ccpa == 2 forKey:@"gad_rdp"];
    
    int coppa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCOPPAStorageKey];
    if (coppa != 0)
        [GADMobileAds.sharedInstance.requestConfiguration tagForChildDirectedTreatment:coppa == 2];
    
    [TPGoogleAdMobAdapterConfig showAdapterInfo];
    
}

+ (void)showAdapterInfo
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *version = [NSString stringWithFormat:@"%s",GoogleMobileAdsVersionString];
        NSMutableString *adapterInfo = [[NSMutableString alloc] init];
        [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"AdMob"];
        [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_AdMobAdapter_Version];
        [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_AdMobAdapter_PlatformSDK_Version];
        if(version != nil)
        {
            [adapterInfo appendFormat:@"Current version[当前sdk版本]:%@",version];
        }
        MSLogInfo(@"%@", adapterInfo);
    });
}


@end
