#import "TradPlusAdColonyInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <AdColony/AdColony.h>
#import "TradPlusAdColonySDKLoader.h"
#import "TPAdColonyAdapterBaseInfo.h"

@interface TradPlusAdColonyInterstitialAdapter ()<AdColonyInterstitialDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) AdColonyInterstitial *interstitial;
@property (nonatomic, copy) NSString *zoneId;
@end

@implementation TradPlusAdColonyInterstitialAdapter

#pragma mark - Extra
- (BOOL)extraActWithEvent:(NSString *)event info:(NSDictionary *)config
{
    if([event isEqualToString:@"StartInit"])
    {
        [self initSDKWithInfo:config];
    }
    else if([event isEqualToString:@"AdapterVersion"])
    {
        [self adapterVersionCallback];
    }
    else if([event isEqualToString:@"PlatformSDKVersion"])
    {
        [self platformSDKVersionCallback];
    }
    else
    {
        return NO;
    }
    return YES;
}

- (void)initSDKWithInfo:(NSDictionary *)config
{
    NSString *appId = config[@"appId"];
    NSString *strAllZoneIds = config[@"adcolonyZ"];
    if(appId == nil || strAllZoneIds == nil)
    {
        MSLogTrace(@"AdColony init Config Error %@",config);
        return;
    }
    NSArray *allZoneIds = [strAllZoneIds componentsSeparatedByString:@","];
    if([TradPlusAdColonySDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusAdColonySDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusAdColonySDKLoader sharedInstance] initWithAppID:appId zoneIDs:allZoneIds delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_AdColonyAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [AdColony getSDKVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_AdColonyAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *appId = item.config[@"appId"];
    self.zoneId = item.config[@"placementId"];
    NSString *strAllZoneIds = item.config[@"adcolonyZ"];
    if(appId == nil || strAllZoneIds == nil || self.zoneId == nil)
    {
        [self AdConfigError];
        return;
    }
    NSArray *allZoneIds = [strAllZoneIds componentsSeparatedByString:@","];
    [[TradPlusAdColonySDKLoader sharedInstance] initWithAppID:appId zoneIDs:allZoneIds delegate:self];
}

#pragma mark - TPSDKLoaderDelegate
- (void)tpInitFinish
{
    [self loadAd];
}

- (void)tpInitFailWithError:(NSError *)error
{
    [self AdLoadFailWithError:error];
}

- (void)loadAd
{
    [AdColony requestInterstitialInZone:self.zoneId options:nil andDelegate:self];
}

- (id)getCustomObject
{
    return self.interstitial;
}

- (BOOL)isReady
{
    return (self.interstitial != nil && !self.interstitial.expired);
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.interstitial showWithPresentingViewController:rootViewController];
}

#pragma mark - AdColonyInterstitialDelegate
- (void)adColonyInterstitialDidLoad:(AdColonyInterstitial * _Nonnull)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.interstitial = interstitial;
    [self AdLoadFinsh];
}

- (void)adColonyInterstitialDidFailToLoad:(AdColonyAdRequestError * _Nonnull)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFailWithError:error];
}

- (void)adColonyInterstitialDidReceiveClick:(AdColonyInterstitial * _Nonnull)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)adColonyInterstitialDidClose:(AdColonyInterstitial * _Nonnull)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

- (void)adColonyInterstitialWillOpen:(AdColonyInterstitial * _Nonnull)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)adColonyInterstitialExpired:(AdColonyInterstitial * _Nonnull)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)adColonyInterstitialWillLeaveApplication:(AdColonyInterstitial * _Nonnull)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
@end
