#import "TradPlusFacebookInterstitialAdapter.h"
#import "TPFacebookAdapterConfig.h"
#import <FBAudienceNetwork/FBAudienceNetwork.h>
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TPFacebookAdapterBaseInfo.h"

@interface TradPlusFacebookInterstitialAdapter ()<FBInterstitialAdDelegate>

@property (nonatomic, strong) FBInterstitialAd *interstitialAd;
@end

@implementation TradPlusFacebookInterstitialAdapter

#pragma mark - Extra
- (BOOL)extraActWithEvent:(NSString *)event info:(NSDictionary *)config
{
    if([event isEqualToString:@"AdapterVersion"])
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

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_FacebookAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = FB_AD_SDK_VERSION;
    if(version == nil)
    {
       version = @"";
    }
    NSDictionary *dic = @{
       @"version":version,
       @"adaptedVersion":TP_FacebookAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *placementId = item.config[@"placementId"];
    if(placementId == nil)
    {
        [self AdConfigError];
        return;
    }
    [TPFacebookAdapterConfig setPrivacy:@{}];
    self.interstitialAd = [[FBInterstitialAd alloc] initWithPlacementID:placementId];
    self.interstitialAd.delegate = self;
    NSString *bidToken = nil;
    if(item.adsourceplacement != nil)
    {
        bidToken = item.adsourceplacement.adm;
    }
    if(bidToken == nil)
    {
        [self.interstitialAd loadAd];
    }
    else
    {
        [self.interstitialAd loadAdWithBidPayload:bidToken];
    }
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.interstitialAd showAdFromRootViewController:rootViewController];
}

- (id)getCustomObject
{
    return self.interstitialAd;
}

- (BOOL)isReady
{
    return (self.interstitialAd != nil && self.interstitialAd.isAdValid);
}

#pragma mark - FBInterstitialAdDelegate

- (void)interstitialAdDidLoad:(FBInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)interstitialAd:(FBInterstitialAd *)interstitialAd didFailWithError:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFailWithError:error];
}

- (void)interstitialAdDidClick:(FBInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)interstitialAdDidClose:(FBInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

- (void)interstitialAdWillLogImpression:(FBInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)interstitialAdWillClose:(FBInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
@end
