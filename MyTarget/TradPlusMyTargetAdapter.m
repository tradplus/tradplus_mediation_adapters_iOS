#import "TradPlusMyTargetAdapter.h"
#import <MyTargetSDK/MyTargetSDK.h>
#import "TradPlusMyTargetSDKSetting.h"

@implementation TradPlusMyTargetAdapter

+ (NSString *)getBuyeruidWithInfo:(NSDictionary *)infoDic
{
    [TradPlusMyTargetSDKSetting showAdapterInfo];
    return @"";
}

+ (NSString *)sdkVersion
{
    return [MTRGVersion currentVersion];
}

@end
