#import "TradPlusSigmobAdapter.h"
#import <WindSDK/WindSDK.h>
#import "TradPlusSigmobSDKLoader.h"
#import <TradPlusAds/MsCommon.h>

@implementation TradPlusSigmobAdapter

+ (NSString *)getBuyeruidWithInfo:(NSDictionary *)infoDic
{
    if(infoDic != nil)
    {
        NSString *appId = infoDic[@"appId"];
        NSString *appKey = infoDic[@"AppKey"];
        if(appId != nil && appKey != nil)
        {
            if([TradPlusSigmobSDKLoader sharedInstance].initSource == -1)
            {
                [TradPlusSigmobSDKLoader sharedInstance].initSource = 2;
            }
            [[TradPlusSigmobSDKLoader sharedInstance] initWithAppID:appId appKey:appKey delegate:nil];
            __block NSString *token = @"";
            tp_dispatch_main_sync_safe(^{
                token = [WindAds getSdkToken];
            });
            return token;
        }
    }
    return @"";
}

+ (NSString *)sdkVersion
{
    return [WindAds sdkVersion];
}

@end
