#import <UIKit/UIKit.h>
#import "TradPlusGDTMobAdapter.h"
#import "GDTSDKConfig.h"
#import <TradPlusAds/MsCommon.h>
#import "TradPlusGDTMobSDKLoader.h"

@implementation TradPlusGDTMobAdapter

+ (NSString *)getBuyeruidWithInfo:(NSDictionary *)infoDic
{
    __block NSString *Buyeruid = nil;
    tp_dispatch_main_sync_safe(^{
        Buyeruid = [GDTSDKConfig getBuyerIdWithContext:nil];
    });
    return Buyeruid;
   
}

+ (NSString *)getSDKInfoWithInfo:(NSDictionary *)infoDic
{
    NSString *appId = infoDic[@"appId"];
    NSString *placementId = infoDic[@"placementId"];
    __block NSString *sdkInfo = nil;
    if(appId != nil && placementId != nil)
    {
        tp_dispatch_main_sync_safe(^{
            if([TradPlusGDTMobSDKLoader sharedInstance].initSource == -1)
            {
                [TradPlusGDTMobSDKLoader sharedInstance].initSource = 2;
            }
            [[TradPlusGDTMobSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
            sdkInfo = [GDTSDKConfig getSDKInfoWithPlacementId:placementId];
        });
        return sdkInfo;
    }
    else
    {
        return sdkInfo;
    }
}

+ (NSString *)sdkVersion
{
    return [GDTSDKConfig sdkVersion];
}
@end
