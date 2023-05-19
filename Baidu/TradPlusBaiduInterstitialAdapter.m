#import "TradPlusBaiduInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <BaiduMobAdSDK/BaiduMobAdExpressInterstitial.h>
#import <BaiduMobAdSDK/BaiduMobAdExpressFullScreenVideo.h>
#import "TradPlusBaiduSDKSetting.h"
#import "TPBaiduAdapterBaseInfo.h"

@interface TradPlusBaiduInterstitialAdapter ()<BaiduMobAdExpressIntDelegate,BaiduMobAdExpressFullScreenVideoDelegate>

@property (nonatomic, strong) BaiduMobAdExpressFullScreenVideo *expressFullscreenVideoAd;
@property (nonatomic, strong) BaiduMobAdExpressInterstitial *expressInterstitialAd;
@property (nonatomic, assign) BOOL isC2SBidding;
@property (nonatomic, copy) NSString *appId;
@end

@implementation TradPlusBaiduInterstitialAdapter

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
    else if([event isEqualToString:@"C2SBidding"])
    {
        [self initSDKC2SBidding];
    }
    else if([event isEqualToString:@"LoadAdC2SBidding"])
    {
        [self loadAdC2SBidding];
    }
    else
    {
        return NO;
    }
    return YES;
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_BaiduAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = SDK_VERSION_IN_MSSP;
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_BaiduAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    self.appId = item.config[@"appId"];
    NSString *placementId = item.config[@"placementId"];
    if(placementId == nil || self.appId == nil)
    {
        [self AdConfigError];
        return;
    }
    [[TradPlusBaiduSDKSetting sharedInstance] setPersonalizedAd];
    switch (item.full_screen_video)
    {
        case 2:
        case 3:
        {
            self.expressInterstitialAd = [[BaiduMobAdExpressInterstitial alloc] init];
            self.expressInterstitialAd.delegate = self;
            self.expressInterstitialAd.adUnitTag = placementId;
            self.expressInterstitialAd.publisherId = self.appId;
            [self.expressInterstitialAd load];
            break;
        }
        default:
        {
            self.expressFullscreenVideoAd = [[BaiduMobAdExpressFullScreenVideo alloc] init];
            self.expressFullscreenVideoAd.delegate = self;
            self.expressFullscreenVideoAd.AdUnitTag = placementId;
            self.expressFullscreenVideoAd.publisherId = self.appId;
            self.expressFullscreenVideoAd.adType = BaiduMobAdTypeFullScreenVideo;
            [self.expressFullscreenVideoAd load];
            break;
        }
    }
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    switch (self.waterfallItem.full_screen_video)
    {
        case 2:
        case 3:
        {
            [self.expressInterstitialAd showFromViewController:rootViewController];
            break;
        }
        default:
        {
            [self.expressFullscreenVideoAd showFromViewController:rootViewController];
            break;
        }
    }
}

- (BOOL)isReady
{
    if(self.waterfallItem.full_screen_video == 2|| self.waterfallItem.full_screen_video == 3)
    {
        return self.expressInterstitialAd.isReady;
    }
    else
    {
        return self.expressFullscreenVideoAd.isReady;
    }
}

- (id)getCustomObject
{
    switch (self.waterfallItem.full_screen_video)
    {
        case 2:
        case 3:
        {
            return self.expressInterstitialAd;
        }
        default:
        {
            return self.expressFullscreenVideoAd;
        }
    }
    return nil;
}

#pragma mark - C2SBidding

- (void)initSDKC2SBidding
{
    self.isC2SBidding = YES;
    [self loadAdWithWaterfallItem:self.waterfallItem];
}

- (void)loadAdC2SBidding
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if([self isReady])
    {
        [self AdLoadFinsh];
    }
    else
    {
        NSError *loadError = [NSError errorWithDomain:@"baidu.interstitial" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S Interstitial not ready"}];
        [self AdLoadFailWithError:loadError];
    }
}

- (void)finishC2SBiddingWithEcpm:(NSString *)ecpmStr
{
    NSString *version = SDK_VERSION_IN_MSSP;
    if(version == nil)
    {
        version = @"";
    }
    if(ecpmStr == nil)
    {
        ecpmStr = @"0";
    }
    NSDictionary *dic = @{@"ecpm":ecpmStr,@"version":version};
    [self ADLoadExtraCallbackWithEvent:@"C2SBiddingFinish" info:dic];
}

- (void)failC2SBiddingWithErrorStr:(NSString *)errorStr
{
    NSDictionary *dic = @{@"error":errorStr};
    [self ADLoadExtraCallbackWithEvent:@"C2SBiddingFail" info:dic];
}

#pragma mark - BaiduMobAdInterstitialDelegate
- (NSString *)publisherId
{
    return self.appId;
}

#pragma mark - BaiduMobAdExpressIntDelegate
- (void)interstitialAdLoaded:(BaiduMobAdExpressInterstitial *)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)interstitialAdLoadFailCode:(NSString *)errCode message:(NSString *)message interstitialAd:(BaiduMobAdExpressInterstitial *)interstitial
{
    MSLogTrace(@"%s, errCode:%@ message:%@", __PRETTY_FUNCTION__, errCode,message);
    if(errCode == nil)
    {
        errCode = @"4001";
    }
    if(self.isC2SBidding)
    {
        if(message == nil)
        {
            message = @"C2S Bidding Fail";
        }
        NSString *errorStr = [NSString stringWithFormat:@"errCode: %@, errMsg: %@", errCode, message];
        [self failC2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        if(message == nil)
        {
            message = @"load faile";
        }
        NSError *error = [NSError errorWithDomain:@"Baidu" code:[errCode integerValue] userInfo:@{NSLocalizedDescriptionKey: message}];
        [self AdLoadFailWithError:error];
    }
}

- (void)interstitialAdExposure:(BaiduMobAdExpressInterstitial *)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)interstitialAdExposureFail:(BaiduMobAdExpressInterstitial *)interstitial withError:(int)reason
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSString *strError = [NSString stringWithFormat:@"show fail, reason:%d", reason];
    NSError *error = [NSError errorWithDomain:@"Baidu" code:reason userInfo:@{NSLocalizedDescriptionKey: strError}];
    [self AdShowFailWithError:error];
}

- (void)interstitialAdDidClose:(BaiduMobAdExpressInterstitial *)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

- (void)interstitialAdDidClick:(BaiduMobAdExpressInterstitial *)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)interstitialAdDidLPClose:(BaiduMobAdExpressInterstitial *)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)interstitialAdDownloadSucceeded:(BaiduMobAdExpressInterstitial *)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.isC2SBidding)
    {
        [self finishC2SBiddingWithEcpm:[interstitial getECPMLevel]];
    }
    else
    {
        [self AdLoadFinsh];
    }
}

- (void)interstitialAdDownLoadFailed:(BaiduMobAdExpressInterstitial *)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.isC2SBidding)
    {
        NSString *errorStr = @"C2S Bidding Fail";
        [self failC2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        NSError *error = [NSError errorWithDomain:@"Baidu" code:4001 userInfo:@{NSLocalizedDescriptionKey: @"load faile"}];
        [self AdLoadFailWithError:error];
    }
}


#pragma mark - BaiduMobAdExpressFullScreenVideoDelegate
- (void)fullScreenVideoAdLoadSuccess:(BaiduMobAdExpressFullScreenVideo *)video
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)fullScreenVideoAdLoadFailCode:(NSString *)errCode message:(NSString *)message fullScreenAd:(BaiduMobAdExpressFullScreenVideo *)video
{
    MSLogTrace(@"%s errCode:%@ message:%@", __PRETTY_FUNCTION__,errCode,message);
    if(errCode == nil)
    {
        errCode = @"4001";
    }
    if(self.isC2SBidding)
    {
        if(message == nil)
        {
            message = @"C2S Bidding Fail";
        }
        NSString *errorStr = [NSString stringWithFormat:@"errCode: %@, errMsg: %@", errCode, message];
        [self failC2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        if(message == nil)
        {
            message = @"load faile";
        }
        NSError *error = [NSError errorWithDomain:@"Baidu" code:[errCode integerValue] userInfo:@{NSLocalizedDescriptionKey: message}];
        [self AdLoadFailWithError:error];
    }
}

- (void)fullScreenVideoAdLoaded:(BaiduMobAdExpressFullScreenVideo *)video
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.isC2SBidding)
    {
        [self finishC2SBiddingWithEcpm:[video getECPMLevel]];
    }
    else
    {
        [self AdLoadFinsh];
    }
}

- (void)fullScreenVideoAdLoadFailed:(BaiduMobAdExpressFullScreenVideo *)video withError:(BaiduMobFailReason)reason
{
    MSLogTrace(@"%s, reason:%d", __PRETTY_FUNCTION__, reason);
    if(self.isC2SBidding)
    {
        NSString *errorStr = [NSString stringWithFormat:@"C2S Bidding Fail code:%@",@(reason)];
        [self failC2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        NSError *error = [NSError errorWithDomain:@"Baidu" code:reason userInfo:@{NSLocalizedDescriptionKey: @"load failed"}];
        [self AdLoadFailWithError:error];
    }
}

- (void)fullScreenVideoAdDidStarted:(BaiduMobAdExpressFullScreenVideo *)video
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)fullScreenVideoAdShowFailed:(BaiduMobAdExpressFullScreenVideo *)video withError:(BaiduMobFailReason)reason
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSString *strError = [NSString stringWithFormat:@"show fail, reason:%d", reason];
    NSError *error = [NSError errorWithDomain:@"Baidu" code:reason userInfo:@{NSLocalizedDescriptionKey: strError}];
    [self AdShowFailWithError:error];
}

- (void)fullScreenVideoAdDidPlayFinish:(BaiduMobAdExpressFullScreenVideo *)video
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}

- (void)fullScreenVideoAdDidClose:(BaiduMobAdExpressFullScreenVideo *)video withPlayingProgress:(CGFloat)progress
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

- (void)fullScreenVideoAdDidSkip:(BaiduMobAdExpressFullScreenVideo *)video withPlayingProgress:(CGFloat)progress
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)fullScreenVideoAdDidClick:(BaiduMobAdExpressFullScreenVideo *)video withPlayingProgress:(CGFloat)progress
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}
@end
