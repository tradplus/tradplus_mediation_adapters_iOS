#import "TradPlusGAMInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSConsentManager.h>
#import <GoogleMobileAds/GoogleMobileAds.h>
#import "TPAdMobAdapterBaseInfo.h"
#import "TPGoogleAdMobAdapterConfig.h"

@interface TradPlusGAMInterstitialAdapter ()<GADFullScreenContentDelegate>

@property (nonatomic,strong)GAMInterstitialAd *interstitialAd;
@end

@implementation TradPlusGAMInterstitialAdapter

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
    NSDictionary *dic = @{@"version":TP_AdMobAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [NSString stringWithFormat:@"%s",GoogleMobileAdsVersionString];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_AdMobAdapter_PlatformSDK_Version
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
    [TPGoogleAdMobAdapterConfig setPrivacy:@{}];
    
    GAMRequest *request = [GAMRequest request];
    if (![MSConsentManager sharedManager].canCollectPersonalInfo
        || !gTPOpenPersonalizedAd)
    {
        MSLogTrace(@"***********");
        MSLogTrace(@"GAM non-personalized ads");
        MSLogTrace(@"***********");
        GADExtras *extras = [[GADExtras alloc] init];
        extras.additionalParameters = @{@"npa": @"1"};
        [request registerAdNetworkExtras:extras];
    }
    request.requestAgent = @"TradPlusAd";
    __weak typeof(self) weakSelf = self;
    [GAMInterstitialAd loadWithAdManagerAdUnitID:placementId request:request completionHandler:^(GAMInterstitialAd * _Nullable interstitialAd, NSError * _Nullable error) {
        if(error == nil)
        {
            weakSelf.interstitialAd = interstitialAd;
            [weakSelf AdLoadFinsh];
        }
        else
        {
            [weakSelf AdLoadFailWithError:error];
        }
    }];
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    NSError *error;
    if([self.interstitialAd canPresentFromRootViewController:rootViewController error:&error])
    {
        self.interstitialAd.fullScreenContentDelegate = self;
        [self.interstitialAd presentFromRootViewController:rootViewController];
    }
    else
    {
        [self AdShowFailWithError:error];
    }
}

- (id)getCustomObject
{
    return self.interstitialAd;
}

- (BOOL)isReady
{
    return (self.interstitialAd != nil);
}

#pragma mark - GADFullScreenContentDelegate
- (void)adDidRecordImpression:(nonnull id<GADFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)adDidRecordClick:(nonnull id<GADFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)ad:(nonnull id<GADFullScreenPresentingAd>)ad
    didFailToPresentFullScreenContentWithError:(nonnull NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShowFailWithError:error];
}

- (void)adWillDismissFullScreenContent:(nonnull id<GADFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    
}

- (void)adDidDismissFullScreenContent:(nonnull id<GADFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}
@end
