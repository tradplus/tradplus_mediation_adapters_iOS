#import "TradPlusGoogleIMASDKSetting.h"
#import <TradPlusAds/MSLogging.h>
#import "TPGoogleIMAAdapterBaseInfo.h"
#import <GoogleInteractiveMediaAds/GoogleInteractiveMediaAds.h>

@implementation TradPlusGoogleIMASDKSetting

+ (TradPlusGoogleIMASDKSetting *)sharedInstance
{
    static TradPlusGoogleIMASDKSetting *setting = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        setting = [[TradPlusGoogleIMASDKSetting alloc] init];
    });
    return setting;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        [self showAdapterInfo];
    }
    return self;
}

- (void)showAdapterInfo
{
    NSString *version = [IMAAdsLoader sdkVersion];
    NSMutableString *adapterInfo = [[NSMutableString alloc] init];
    [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"GoogleIMA"];
    [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_GoogleIMAAdapter_Version];
    [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_GoogleIMAAdapter_PlatformSDK_Version];
    if(version != nil)
    {
        [adapterInfo appendFormat:@"Current version[当前sdk版本]:%@",version];
    }
    MSLogInfo(@"%@", adapterInfo);
}

@end
