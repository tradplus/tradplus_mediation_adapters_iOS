#import "TradPlusChartboostInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <ChartboostSDK/Chartboost.h>
#import "TradPlusChartboostSDKLoader.h"
#import "TPChartboostAdapterBaseInfo.h"

@interface TradPlusChartboostInterstitialAdapter ()<CHBInterstitialDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong)CHBInterstitial *interstitial;
@property (nonatomic,copy)NSString *placementId;
@end

@implementation TradPlusChartboostInterstitialAdapter

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
    NSString *appSignature = config[@"appSign"];
    if(appId == nil || appSignature == nil)
    {
        MSLogTrace(@"Chartboost init Config Error %@",config);
        return;
    }
    if([TradPlusChartboostSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusChartboostSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusChartboostSDKLoader sharedInstance] initWithAppId:appId appSignature:appSignature delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_ChartboostAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [Chartboost getSDKVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_ChartboostAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    self.placementId = item.config[@"placementId"];
    NSString *appId = item.config[@"appId"];
    NSString *appSignature = item.config[@"appSign"];
    if(self.placementId == nil || appId == nil || appSignature == nil)
    {
        [self AdConfigError];
        return;
    }
    
    [[TradPlusChartboostSDKLoader sharedInstance] initWithAppId:appId appSignature:appSignature delegate:self];
}

- (void)loadAd
{
    self.interstitial = [[CHBInterstitial alloc] initWithLocation:self.placementId delegate:self];
    [self.interstitial cache];
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

- (id)getCustomObject
{
    return self.interstitial;
}

- (BOOL)isReady
{
    return (self.interstitial != nil && self.interstitial.isCached);
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.interstitial showFromViewController:rootViewController];
}

#pragma mark - CHBInterstitialDelegate
- (void)didCacheAd:(CHBCacheEvent *)event error:(nullable CHBCacheError *)error;
{
    MSLogTrace(@"%s->%@", __PRETTY_FUNCTION__, error);
    if(error == nil)
    {
        [self AdLoadFinsh];
    }
    else
    {
        [self AdLoadFailWithError:error];
    }
}

- (void)didShowAd:(CHBShowEvent *)event error:(nullable CHBShowError *)error
{
    MSLogTrace(@"%s->%@", __PRETTY_FUNCTION__, error);
    if (error == nil)
    {
        [self AdShow];
    }
    else
    {
        [self AdShowFailWithError:error];
    }
}

- (void)didClickAd:(CHBClickEvent *)event error:(nullable CHBClickError *)error
{
    MSLogTrace(@"%s->%@", __PRETTY_FUNCTION__, error);
    [self AdClick];
}

- (void)didDismissAd:(CHBDismissEvent *)event
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}
@end
