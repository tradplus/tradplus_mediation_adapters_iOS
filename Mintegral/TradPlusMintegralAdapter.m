#import "TradPlusMintegralAdapter.h"
#import <TradPlusAds/TradPlusAds.h>
#import <MTGSDK/MTGSDK.h>
#import <MTGSDKBidding/MTGBiddingSDK.h>

@implementation TradPlusMintegralAdapter


+ (NSString *)getBuyeruidWithInfo:(NSDictionary *)infoDic
{
    __block NSString * buyerUID;
    tp_dispatch_main_sync_safe(^{
        buyerUID = [MTGBiddingSDK buyerUID];
    });
    return buyerUID;
}

+ (NSString *)sdkVersion
{
    return [MTGSDK sdkVersion];
}
@end
