#import "TradPlusKuaiShouSplashAdapter.h"
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/MSLogging.h>
#import "TradPlusKuaiShouSDKLoader.h"
#import <KSAdSDK/KSAdSDK.h>
#import "TPKuaiShouAdapterBaseInfo.h"

@interface TradPlusKuaiShouSplashAdapter ()<KSSplashAdViewDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong)KSSplashAdView *splashAdView;
@property (nonatomic,copy)NSString *placementId;
@end

@implementation TradPlusKuaiShouSplashAdapter

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
    [[TradPlusKuaiShouSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    [[TradPlusKuaiShouSDKLoader sharedInstance] setPersonalizedAd];
    self.splashAdView = [[KSSplashAdView alloc] initWithPosId:self.placementId];
    self.splashAdView.delegate = self;
    self.splashAdView.rootViewController = self.waterfallItem.splashWindow.rootViewController;
    
    NSDictionary *dicBidToken = nil;
    if (self.waterfallItem.adsourceplacement != nil)
    {
        NSString *bidToken = self.waterfallItem.adsourceplacement.adm;
        NSData *admData = [bidToken dataUsingEncoding:NSUTF8StringEncoding];
        dicBidToken = [NSJSONSerialization JSONObjectWithData:admData options:0 error:nil];
    }
    if (dicBidToken)
        [self.splashAdView loadAdDataWithResponseV2:dicBidToken];
    else
        [self.splashAdView loadAdData];
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

- (BOOL)isReady
{
    return self.isAdReady;
}

- (id)getCustomObject
{
    return self.splashAdView;
}

- (void)showAdInWindow:(UIWindow *)window bottomView:(UIView *)bottomView
{
    [self.splashAdView showInView:window];
}

#pragma mark - KSSplashAdViewDelegate

- (void)ksad_splashAdDidLoad:(KSSplashAdView *)splashAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)ksad_splashAdContentDidLoad:(KSSplashAdView *)splashAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)ksad_splashAd:(KSSplashAdView *)splashAdView didFailWithError:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFailWithError:error];
    if(self.splashAdView != nil)
    {
        [self.splashAdView removeFromSuperview];
    }
}

- (void)ksad_splashAdDidVisible:(KSSplashAdView *)splashAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)ksad_splashAdVideoDidBeginPlay:(KSSplashAdView *)splashAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)ksad_splashAd:(KSSplashAdView *)splashAdView didClick:(BOOL)inMiniWindow
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)ksad_splashAd:(KSSplashAdView *)splashAdView willZoomTo:(inout CGRect *)frame
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)ksad_splashAd:(KSSplashAdView *)splashAdView willMoveTo:(inout CGRect *)frame
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)ksad_splashAd:(KSSplashAdView *)splashAdView didSkip:(NSTimeInterval)showDuration
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_splash_skip" info:nil];
    [self removeSplashAd];
}

- (void)ksad_splashAdDidCloseConversionVC:(KSSplashAdView *)splashAdView interactionType:(KSAdInteractionType)interactType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self removeSplashAd];
}

- (void)ksad_splashAdDidAutoDismiss:(KSSplashAdView *)splashAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self removeSplashAd];
}

- (void)ksad_splashAdDidClose:(KSSplashAdView *)splashAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self removeSplashAd];
}

- (void)removeSplashAd
{
    if(self.splashAdView)
    {
        [self AdClose];
        [self.splashAdView removeFromSuperview];
        self.splashAdView = nil;
    }
}
@end
