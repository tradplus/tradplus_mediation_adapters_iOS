#import "TradPlusGDTMobSplashAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "GDTSplashAd.h"
#import "GDTSplashZoomOutView+TPDraggable.h"
#import "GDTSDKConfig.h"
#import "TradPlusGDTMobSDKLoader.h"
#import "TPGDTMobAdapterBaseInfo.h"

@interface TradPlusGDTMobSplashAdapter ()<GDTSplashAdDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong) GDTSplashAd *splashAdView;
@property (nonatomic,copy) NSString *bidToken;
@property (nonatomic,copy) NSString *placementId;
@end

@implementation TradPlusGDTMobSplashAdapter

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
        MSLogTrace(@"GDTMob init Config Error %@",config);
        return;
    }
    if([TradPlusGDTMobSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusGDTMobSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusGDTMobSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_GDTMobAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [GDTSDKConfig sdkVersion];
    if(version == nil)
    {
       version = @"";
    }
    NSDictionary *dic = @{
       @"version":version,
       @"adaptedVersion":TP_GDTMobAdapter_PlatformSDK_Version
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
    self.bidToken = nil;
    if(item.adsourceplacement != nil)
    {
        self.bidToken = item.adsourceplacement.adm;
    }
    [[TradPlusGDTMobSDKLoader sharedInstance] setAudioSessionSettingWithExtraInfo:self.waterfallItem.extraInfoDictionary];
    [[TradPlusGDTMobSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    [[TradPlusGDTMobSDKLoader sharedInstance] setPersonalizedAd];
    if(self.bidToken != nil)
    {
        self.splashAdView = [[GDTSplashAd alloc] initWithPlacementId:self.placementId token:self.bidToken];
    }
    else
    {
        self.splashAdView = [[GDTSplashAd alloc] initWithPlacementId:self.placementId];
    }
    self.splashAdView.delegate = self;
    self.splashAdView.needZoomOut = (self.waterfallItem.zoom_out == 1);
    [self.splashAdView loadAd];
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
    return (self.splashAdView != nil && self.splashAdView.isAdValid);
}

- (id)getCustomObject
{
    return self.splashAdView;
}

- (void)showAdInWindow:(UIWindow *)window bottomView:(UIView *)bottomView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.bidToken != nil)
    {
        [self.splashAdView setBidECPM:self.waterfallItem.adsourceplacement.bid_price];
    }
    if(self.splashAdView.splashZoomOutView)
    {
        UIViewController *rootViewController = self.waterfallItem.splashWindow.rootViewController;
        [rootViewController.view addSubview:self.splashAdView.splashZoomOutView];
        self.splashAdView.splashZoomOutView.rootViewController = rootViewController;
        [self.splashAdView.splashZoomOutView supportDrag];
    }
    [self.splashAdView showAdInWindow:window withBottomView:bottomView skipView:nil];
}

#pragma mark - GDTSplashAdDelegate
- (void)splashAdSuccessPresentScreen:(GDTSplashAd *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)splashAdDidLoad:(GDTSplashAd *)splashAd
{
    [self AdLoadFinsh];
}

- (void)splashAdFailToPresent:(GDTSplashAd *)splashAd withError:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.isAdReady)
    {
        [self AdShowFailWithError:error];
    }
    else
    {
        [self AdLoadFailWithError:error];
    }
}

- (void)splashAdApplicationWillEnterBackground:(GDTSplashAd *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)splashAdExposured:(GDTSplashAd *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)splashAdClicked:(GDTSplashAd *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)splashAdWillClosed:(GDTSplashAd *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)splashAdClosed:(GDTSplashAd *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

- (void)splashAdWillPresentFullScreenModal:(GDTSplashAd *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)splashAdDidPresentFullScreenModal:(GDTSplashAd *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)splashAdWillDismissFullScreenModal:(GDTSplashAd *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)splashAdDidDismissFullScreenModal:(GDTSplashAd *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)splashAdLifeTime:(NSUInteger)time
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

#pragma mark - GDTSplashZoomOutViewDelegate
- (void)splashZoomOutViewDidClick:(GDTSplashZoomOutView *)splashZoomOutView
{
    MSLogTrace(@"%s",__FUNCTION__);
    [self AdClick];
}

- (void)splashZoomOutViewAdDidClose:(GDTSplashZoomOutView *)splashZoomOutView
{
    MSLogTrace(@"%s",__FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_splash_zoom_close" info:nil];
}

- (void)splashZoomOutViewAdVideoFinished:(GDTSplashZoomOutView *)splashZoomOutView
{
    MSLogTrace(@"%s",__FUNCTION__);
}

- (void)splashZoomOutViewAdDidPresentFullScreenModal:(GDTSplashZoomOutView *)splashZoomOutView
{
    MSLogTrace(@"%s",__FUNCTION__);
}

- (void)splashZoomOutViewAdDidDismissFullScreenModal:(GDTSplashZoomOutView *)splashZoomOutView
{
    MSLogTrace(@"%s",__FUNCTION__);
}
@end
