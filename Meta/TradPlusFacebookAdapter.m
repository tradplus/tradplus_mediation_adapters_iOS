#import "TradPlusFacebookAdapter.h"
#import "TPFacebookAdapterConfig.h"
#import <FBAudienceNetwork/FBAudienceNetwork.h>
#import <TradPlusAds/TradPlus.h>

@implementation TradPlusFacebookAdapter

+ (NSString *)getBuyeruidWithInfo:(NSDictionary *)infoDic
{
    [TPFacebookAdapterConfig showAdapterInfo];
    [FBAdSettings setAdvertiserTrackingEnabled:[TradPlus isAllowTracking]];
    return [FBAdSettings bidderToken];
}

+ (NSString *)sdkVersion
{
    return FB_AD_SDK_VERSION;
}
@end
