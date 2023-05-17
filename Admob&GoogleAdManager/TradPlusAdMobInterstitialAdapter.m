#import "TradPlusAdMobInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSConsentManager.h>
#import <GoogleMobileAds/GoogleMobileAds.h>
#import "TPGoogleAdMobAdapterConfig.h"
#import "TPAdMobAdapterBaseInfo.h"

@interface TradPlusAdMobInterstitialAdapter ()<GADFullScreenContentDelegate>

@property (nonatomic,strong)GADInterstitialAd *interstitialAd;
@end

@implementation TradPlusAdMobInterstitialAdapter

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
    
    GADRequest *request = [GADRequest request];
    if (![MSConsentManager sharedManager].canCollectPersonalInfo
        || !gTPOpenPersonalizedAd)
    {
        MSLogTrace(@"***********");
        MSLogTrace(@"admob non-personalized ads");
        MSLogTrace(@"***********");
        GADExtras *extras = [[GADExtras alloc] init];
        extras.additionalParameters = @{@"npa": @"1"};
        [request registerAdNetworkExtras:extras];
    }
    request.requestAgent = @"TradPlusAd";
    __weak typeof(self) weakSelf = self;
    [GADInterstitialAd loadWithAdUnitID:placementId request:request completionHandler:^(GADInterstitialAd * _Nullable interstitialAd, NSError * _Nullable error) {
        if(error == nil)
        {
            [weakSelf loadFinishWithInterstitialAd:interstitialAd];
        }
        else
        {
            [weakSelf AdLoadFailWithError:error];
        }
    }];
}

- (void)loadFinishWithInterstitialAd:(GADInterstitialAd *)interstitialAd
{
    self.interstitialAd = interstitialAd;
    __weak typeof(self) weakSelf = self;
    self.interstitialAd.paidEventHandler = ^void(GADAdValue *_Nonnull value){
        NSString *imp_ecpm = [NSString stringWithFormat:@"%@",value.value];
        NSString *imp_currency = value.currencyCode;
        NSString *imp_precision = [NSString stringWithFormat:@"%@",@(value.precision)];
        weakSelf.waterfallItem.extraInfoDictionary[@"imp_ecpm"] = imp_ecpm;
        weakSelf.waterfallItem.extraInfoDictionary[@"imp_currency"] = imp_currency;
        weakSelf.waterfallItem.extraInfoDictionary[@"imp_precision"] = imp_precision;
        [weakSelf ADShowExtraCallbackWithEvent:@"tradplus_imp_show1310" info:nil];
    };
    [self AdLoadFinsh];
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
