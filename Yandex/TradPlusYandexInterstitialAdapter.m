#import "TradPlusYandexInterstitialAdapter.h"
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSLogging.h>
#import <YandexMobileAds/YandexMobileAds.h>
#import "TPYandexAdapterBaseInfo.h"
#import "TradPlusYandexSDKSetting.h"

@interface TradPlusYandexInterstitialAdapter ()<YMAInterstitialAdDelegate>

@property (nonatomic, strong) YMAInterstitialAd *interstitialAd;
@property (nonatomic, strong) YMABidderTokenLoader *loader;

@end

@implementation TradPlusYandexInterstitialAdapter

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
    else if([event isEqualToString:@"S2SBidding"])
    {
        [self getBiddingToken];
    }
    else
    {
        return NO;
    }
    return YES;
}

- (void)getBiddingToken
{
    [TradPlusYandexSDKSetting showAdapterInfo];
    self.loader = [[YMABidderTokenLoader alloc] init];
    __weak typeof(self) weakSelf = self;
    [self.loader loadBidderTokenWithCompletionHandler:^(NSString * _Nullable bidderToken) {
        if(bidderToken == nil)
        {
            bidderToken = @"";
        }
        NSString *version = [YMAMobileAds SDKVersion];
        if(version == nil)
        {
           version = @"";
        }
        NSDictionary *dic = @{@"token":bidderToken,@"version":version};
        [weakSelf ADLoadExtraCallbackWithEvent:@"S2SBiddingFinish" info:dic];
    }];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_YandexAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [YMAMobileAds SDKVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_YandexAdapter_PlatformSDK_Version
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
    [TradPlusYandexSDKSetting setPrivacy];
    NSString *bidToken = nil;
    if (self.waterfallItem.adsourceplacement != nil)
    {
        bidToken = self.waterfallItem.adsourceplacement.adm;
    }
    self.interstitialAd = [[YMAInterstitialAd alloc] initWithAdUnitID:placementId];
    self.interstitialAd.delegate = self;
    if (bidToken)
    {
        YMAMutableAdRequest *request = [[YMAMutableAdRequest alloc] init];
        request.biddingData = bidToken;
        [self.interstitialAd loadWithRequest:request];
    }
    else
        [self.interstitialAd load];
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.interstitialAd presentFromViewController:rootViewController];
}

- (BOOL)isReady
{
    return self.interstitialAd != nil;
}

- (id)getCustomObject
{
    return self.interstitialAd;
}

#pragma mark - YMAInterstitialAdDelegate

- (void)interstitialAdDidFailToLoad:(YMAInterstitialAd *)interstitialAd error:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

- (void)interstitialAdDidLoad:(YMAInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)interstitialAdDidAppear:(YMAInterstitialAd *)interstitialAd;
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)interstitialAdDidDisappear:(YMAInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

- (void)interstitialAdDidClick:(YMAInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)interstitialAdDidFailToPresent:(YMAInterstitialAd *)interstitialAd error:(NSError *)error;
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdShowFailWithError:error];
}

- (void)interstitialAd:(YMAInterstitialAd *)interstitialAd
        didTrackImpressionWithData:(nullable id<YMAImpressionData>)impressionData
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

@end
