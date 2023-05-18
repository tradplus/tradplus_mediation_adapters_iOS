#import "TradPlusBigoSplashAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <BigoADS/BigoSplashAdLoader.h>
#import "TradPlusBigoSDKLoader.h"
#import "TPBigoAdapterBaseInfo.h"
#import <BigoADS/BigoAdSdk.h>

@interface TradPlusBigoSplashAdapter ()<BigoSplashAdLoaderDelegate, BigoSplashAdInteractionDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) BigoSplashAd *splashAd;
@property (nonatomic, strong) BigoSplashAdLoader *adLoader;
@property (nonatomic, strong) UIView *splashView;
@property (nonatomic, copy) NSString *slotId;
@property (nonatomic, assign) BOOL isS2SBidding;
@end

@implementation TradPlusBigoSplashAdapter

- (void)dealloc
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

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
    else if([event isEqualToString:@"S2SBidding"])
    {
        [self initSDKS2SBidding];
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
    if(appId == nil || appId.length <= 5)
    {
        MSLogTrace(@"Bigo init Config Error %@",config);
        return;
    }
    if([TradPlusBigoSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusBigoSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusBigoSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_BigoAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [[BigoAdSdk sharedInstance] getSDKVersionName];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_BigoAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

#pragma mark - S2SBidding
- (void)initSDKS2SBidding
{
    self.isS2SBidding = YES;
    [self initSDKWithWaterfallItem:self.waterfallItem initSource:2];
}

- (void)getBiddingToken
{
    NSString *token = [[BigoAdSdk sharedInstance] getBidderToken];
    if(token == nil)
    {
        token = @"";
    }
    NSString *version = [[BigoAdSdk sharedInstance] getSDKVersionName];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{@"token":token,@"version":version};
    [self ADLoadExtraCallbackWithEvent:@"S2SBiddingFinish" info:dic];
}

- (void)failS2SBiddingWithErrorStr:(NSString *)errorStr
{
    NSDictionary *dic = @{@"error":errorStr};
    [self ADLoadExtraCallbackWithEvent:@"S2SBiddingFail" info:dic];
}
 
- (void)initSDKWithWaterfallItem:(TradPlusAdWaterfallItem *)item initSource:(NSInteger)initSource
{
    NSString *appId = item.config[@"appId"];
    self.slotId = item.config[@"placementId"];
    if(appId == nil || self.slotId == nil || appId.length <= 5)
    {
        MSLogTrace(@"Bigo init Config Error %@",item.config);
        [self AdConfigError];
        return;
    }
    if([TradPlusBigoSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusBigoSDKLoader sharedInstance].initSource = initSource;
    }
    [[TradPlusBigoSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    [self initSDKWithWaterfallItem:item initSource:3];
}

- (void)loadAd
{
    BigoSplashAdRequest *request = [[BigoSplashAdRequest alloc] initWithSlotId:self.slotId];
    self.adLoader = [[BigoSplashAdLoader alloc] initWithSplashAdLoaderDelegate:self];
    NSString *bidToken = nil;
    if(self.waterfallItem.adsourceplacement != nil)
    {
        bidToken = self.waterfallItem.adsourceplacement.adm;
    }
    if(bidToken != nil)
    {
        [request setServerBidPayload:bidToken];
    }
    [self.adLoader loadAd:request];
}

- (void)showAdInWindow:(UIWindow *)window bottomView:(UIView *)bottomView
{
    
    self.splashView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [self.splashAd showInAdContainer:self.splashView];
    [window addSubview:self.splashView];
}

- (void)destroySplashAdView
{
    [self.splashView removeFromSuperview];
    [self.splashAd destroy];
    self.splashAd = nil;
}

#pragma mark - TPSDKLoaderDelegate

- (void)tpInitFinish
{
    if(self.isS2SBidding)
    {
        [self getBiddingToken];
    }
    else
    {
        [self loadAd];
    }
}

- (void)tpInitFailWithError:(NSError *)error
{
    if(self.isS2SBidding)
    {
        NSString *errorStr = @"S2S Init Fail";
        if(error != nil)
        {
            errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.localizedDescription];
        }
        [self failS2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        [self AdLoadFailWithError:error];
    }
}
 
- (BOOL)isReady
{
    return !self.splashAd.isExpired;
}

- (id)getCustomObject
{
    return self.splashAd;
}

#pragma mark - BigoSplashAdLoaderDelegate
- (void)onSplashAdLoaded:(BigoSplashAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    
    self.splashAd = ad;
    [self.splashAd setSplashAdInteractionDelegate:self];
    [self AdLoadFinsh];
}

- (void)onSplashAdLoadError:(BigoAdError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    NSInteger errorCode = 403;
    NSString *errorMsg = @"Load Fail";
    if(error != nil)
    {
        errorCode = error.errorCode;
        errorMsg = error.errorMsg;
    }
    NSError *loadError = [NSError errorWithDomain:@"Bigo.splash" code:errorCode userInfo:@{NSLocalizedDescriptionKey:errorMsg}];
    [self AdLoadFailWithError:loadError];
}
#pragma mark - BigoSplashAdInteractionDelegate
- (void)onAdSkipped:(BigoAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_splash_skip" info:nil];
    [self AdClose];
    [self destroySplashAdView];
}

- (void)onAdFinished:(BigoAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
    [self destroySplashAdView];
}

- (void)onAd:(BigoAd *)ad error:(BigoAdError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    NSInteger errorCode = 403;
    NSString *errorMsg = @"Show Fail";
    if(error != nil)
    {
        errorCode = error.errorCode;
        errorMsg = error.errorMsg;
    }
    NSError *showError = [NSError errorWithDomain:@"Bigo.splash" code:errorCode userInfo:@{NSLocalizedDescriptionKey:errorMsg}];
    [self AdShowFailWithError:showError];
    [self destroySplashAdView];
}

- (void)onAdImpression:(BigoAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)onAdClicked:(BigoAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

@end
