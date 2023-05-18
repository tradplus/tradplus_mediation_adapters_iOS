#import "TradPlusKuaiShouInterstitialAdapter.h"
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/MSLogging.h>
#import "TradPlusKuaiShouSDKLoader.h"
#import <KSAdSDK/KSAdSDK.h>
#import "TPKuaiShouAdapterBaseInfo.h"

@interface TradPlusKuaiShouInterstitialAdapter ()<KSFullscreenVideoAdDelegate,KSInterstitialAdDelegate,TPSDKLoaderDelegate>

@property (nonatomic,assign)BOOL isFullScreenVideo;
@property (nonatomic,strong)KSFullscreenVideoAd *fullscreenVideoAd;
@property (nonatomic,strong)KSInterstitialAd *interstitialAd;
@property (nonatomic,copy)NSString *placementId;
@end

@implementation TradPlusKuaiShouInterstitialAdapter

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
        MSLogTrace(@"KuaiShou init Config Error %@",config);
        return;
    }
    if([TradPlusKuaiShouSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusKuaiShouSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusKuaiShouSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_KuaiShouAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [KSAdSDKManager SDKVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_KuaiShouAdapter_PlatformSDK_Version
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
    if(item.full_screen_video == 1)
    {
        self.isFullScreenVideo = YES;
    }
    [[TradPlusKuaiShouSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    [[TradPlusKuaiShouSDKLoader sharedInstance] setPersonalizedAd];
    BOOL mute = YES;
    if(self.waterfallItem.video_mute == 2)
    {
        mute = NO;
    }
    NSDictionary *dicBidToken = nil;
    if (self.waterfallItem.adsourceplacement != nil)
    {
        NSString *bidToken = self.waterfallItem.adsourceplacement.adm;
        NSData *admData = [bidToken dataUsingEncoding:NSUTF8StringEncoding];
        dicBidToken = [NSJSONSerialization JSONObjectWithData:admData options:0 error:nil];
    }
    if(self.isFullScreenVideo)
    {
        self.fullscreenVideoAd = [[KSFullscreenVideoAd alloc] initWithPosId:self.placementId];
        self.fullscreenVideoAd.shouldMuted = mute;
        self.fullscreenVideoAd.delegate = self;
        if (dicBidToken)
            [self.fullscreenVideoAd loadAdDataWithResponseV2:dicBidToken];
        else
            [self.fullscreenVideoAd loadAdData];
    }
    else
    {
        self.interstitialAd = [[KSInterstitialAd alloc] initWithPosId:self.placementId];
        self.interstitialAd.delegate = self;
        self.interstitialAd.videoSoundEnabled = !mute;
        if (dicBidToken)
            [self.interstitialAd loadAdDataWithResponseV2:dicBidToken];
        else
            [self.interstitialAd loadAdData];
    }
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

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    if(self.isFullScreenVideo)
    {
        KSAdShowDirection showDirection = KSAdShowDirection_Vertical;
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        if(orientation == UIDeviceOrientationLandscapeRight || orientation == UIDeviceOrientationLandscapeLeft)
        {
            showDirection = KSAdShowDirection_Horizontal;
        }
        self.fullscreenVideoAd.showDirection = showDirection;
        [self.fullscreenVideoAd showAdFromRootViewController:rootViewController];
    }
    else
    {
        [self.interstitialAd showFromViewController:rootViewController];
    }
}

- (BOOL)isReady
{
    if(self.isFullScreenVideo)
    {
        if(self.fullscreenVideoAd != nil)
        {
            return self.fullscreenVideoAd.isValid;
        }
    }
    else
    {
        if(self.interstitialAd != nil)
        {
            return self.interstitialAd.isValid;
        }
    }
    return NO;
}

- (id)getCustomObject
{
    if(self.isFullScreenVideo)
    {
        return self.fullscreenVideoAd;
    }
    else
    {
        return self.interstitialAd;
    }
}

#pragma mark - KSFullscreenVideoAdDelegate

- (void)fullscreenVideoAdDidLoad:(KSFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)fullscreenVideoAd:(KSFullscreenVideoAd *)fullscreenVideoAd didFailWithError:(NSError *_Nullable)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

- (void)fullscreenVideoAdVideoDidLoad:(KSFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)fullscreenVideoAdWillVisible:(KSFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
- (void)fullscreenVideoAdDidVisible:(KSFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}
- (void)fullscreenVideoAdWillClose:(KSFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
- (void)fullscreenVideoAdDidClose:(KSFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}
- (void)fullscreenVideoAdDidClick:(KSFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}
- (void)fullscreenVideoAdDidPlayFinish:(KSFullscreenVideoAd *)fullscreenVideoAd didFailWithError:(NSError *_Nullable)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    if(error != nil)
    {
        [self AdShowFailWithError:error];
    }
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}
- (void)fullscreenVideoAdStartPlay:(KSFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
- (void)fullscreenVideoAdDidClickSkip:(KSFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
- (void)fullscreenVideoAdDidClickSkip:(KSFullscreenVideoAd *)fullscreenVideoAd currentTime:(NSTimeInterval)currentTime
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

#pragma mark- KSInterstitialAdDelegate

- (void)ksad_interstitialAdDidLoad:(KSInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)ksad_interstitialAdRenderSuccess:(KSInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)ksad_interstitialAdRenderFail:(KSInterstitialAd *)interstitialAd error:(NSError * _Nullable)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

- (void)ksad_interstitialAdWillVisible:(KSInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)ksad_interstitialAdDidVisible:(KSInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)ksad_interstitialAd:(KSInterstitialAd *)interstitialAd didSkip:(NSTimeInterval)playDuration
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)ksad_interstitialAdDidClick:(KSInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)ksad_interstitialAdWillClose:(KSInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)ksad_interstitialAdDidClose:(KSInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.interstitialAd = nil;
    [self AdClose];
}

- (void)ksad_interstitialAdDidCloseOtherController:(KSInterstitialAd *)interstitialAd interactionType:(KSAdInteractionType)interactionType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
@end
