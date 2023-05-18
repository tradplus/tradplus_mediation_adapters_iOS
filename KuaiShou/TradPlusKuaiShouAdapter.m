#import "TradPlusKuaiShouAdapter.h"
#import <KSAdSDK/KSAdSDK.h>
#import "TradPlusKuaiShouSDKLoader.h"

@implementation TradPlusKuaiShouAdapter

+ (NSString *)getBuyeruidWithInfo:(NSDictionary *)infoDic
{
    NSString *appId = infoDic[@"appId"];
    NSString *posId = infoDic[@"placementId"];
    if (appId != nil && posId != nil)
    {
        [[TradPlusKuaiShouSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
        KSAdBiddingAdV2Model *model = [[KSAdBiddingAdV2Model alloc] init];
        return [KSAdSDKManager getBidRequestTokenV2:model];
    }
    return nil;
}

+ (NSString *)sdkVersion
{
    return [KSAdSDKManager SDKVersion];
}

@end
