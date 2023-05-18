#import "TradPlusVungleAdapter.h"
#import "TPVungleRouter.h"
#import "TradPlusVungleSDKLoader.h"

@implementation TradPlusVungleAdapter

+ (NSString *)getBuyeruidWithInfo:(NSDictionary *)infoDic
{
    if(infoDic != nil)
    {
        NSString *appId = infoDic[@"appId"];
        if(appId != nil)
        {
            if([TradPlusVungleSDKLoader sharedInstance].initSource == -1)
            {
                [TradPlusVungleSDKLoader sharedInstance].initSource = 2;
            }
            [[TradPlusVungleSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
            
            return [[VungleSDK sharedSDK] currentSuperToken];
        }
    }
    return nil;
}

+ (NSString *)sdkVersion
{
    return VungleSDKVersion;
}

@end
