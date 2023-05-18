#import "TradPlusSmaatoInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <SmaatoSDKInterstitial/SmaatoSDKInterstitial.h>
#import "TradPlusSmaatoSDKLoader.h"
#import "TPSmaatoAdapterBaseInfo.h"

@interface TradPlusSmaatoInterstitialAdapter ()<SMAInterstitialDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) SMAInterstitial *interstitial;
@property (nonatomic, copy) NSString *placementId;
@end

@implementation TradPlusSmaatoInterstitialAdapter

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
    if(appId == nil)
    {
        MSLogTrace(@"Smaato init Config Error %@",config);
        return;
    }
    if([TradPlusSmaatoSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusSmaatoSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusSmaatoSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_SmaatoAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [SmaatoSDK sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_SmaatoAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *appId = item.config[@"appId"];
    self.placementId = item.config[@"placementId"];
    if(appId == nil || self.placementId == nil)
    {
        [self AdConfigError];
        return;
    }
    [[TradPlusSmaatoSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    [SmaatoSDK loadInterstitialForAdSpaceId:self.placementId delegate:self];
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
    return (self.interstitial != nil
            && self.interstitial.availableForPresentation);
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.interstitial showFromViewController:rootViewController];
}

#pragma mark - SMAInterstitialDelegate

- (void)interstitialDidLoad:(SMAInterstitial *_Nonnull)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.interstitial = interstitial;
    [self AdLoadFinsh];
}

- (void)interstitial:(SMAInterstitial *_Nullable)interstitial didFailWithError:(NSError *_Nonnull)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

- (void)interstitialDidClick:(SMAInterstitial *_Nonnull)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)interstitialDidAppear:(SMAInterstitial *_Nonnull)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)interstitialDidDisappear:(SMAInterstitial *_Nonnull)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

- (void)interstitialDidTTLExpire:(SMAInterstitial *_Nonnull)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)interstitialWillAppear:(SMAInterstitial *_Nonnull)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)interstitialWillDisappear:(SMAInterstitial *_Nonnull)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)interstitialWillLeaveApplication:(SMAInterstitial *_Nonnull)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
@end
