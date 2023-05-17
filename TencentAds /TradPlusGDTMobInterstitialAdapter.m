#import "TradPlusGDTMobInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "GDTSplashAd.h"
#import "GDTSDKConfig.h"
#import "GDTUnifiedInterstitialAd.h"
#import "TradPlusGDTMobSDKLoader.h"
#import "TPGDTMobAdapterBaseInfo.h"

@interface TradPlusGDTMobInterstitialAdapter ()<GDTUnifiedInterstitialAdDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong)GDTUnifiedInterstitialAd *unifiedInterstitialAd;
@property (nonatomic,copy)NSString *bidToken;
@property (nonatomic,copy)NSString *placementId;
@end

@implementation TradPlusGDTMobInterstitialAdapter

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
        self.unifiedInterstitialAd = [[GDTUnifiedInterstitialAd alloc] initWithPlacementId:self.placementId token:self.bidToken];
    }
    else
    {
        self.unifiedInterstitialAd = [[GDTUnifiedInterstitialAd alloc] initWithPlacementId:self.placementId];
    }
    self.unifiedInterstitialAd.delegate = self;
    
    self.unifiedInterstitialAd.videoMuted = YES;
    if(self.waterfallItem.video_mute == 2)
    {
        self.unifiedInterstitialAd.videoMuted = NO;
    }
 
    self.unifiedInterstitialAd.videoAutoPlayOnWWAN = YES;
    if(self.waterfallItem.auto_play_video == 2)
    {
        self.unifiedInterstitialAd.videoAutoPlayOnWWAN = NO;
    }
    
    if(self.waterfallItem.video_max_time > 0)
    {
        self.unifiedInterstitialAd.maxVideoDuration = self.waterfallItem.video_max_time;
    }
    if(self.waterfallItem.full_screen_video == 1)
    {
        [self.unifiedInterstitialAd loadFullScreenAd];
    }
    else
    {
        [self.unifiedInterstitialAd loadAd];
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
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.bidToken != nil)
    {
        [self.unifiedInterstitialAd setBidECPM:self.waterfallItem.adsourceplacement.bid_price];
    }
    if(self.waterfallItem.full_screen_video == 1)
    {
        [self.unifiedInterstitialAd presentFullScreenAdFromRootViewController:rootViewController];
    }
    else
    {
        [self.unifiedInterstitialAd presentAdFromRootViewController:rootViewController];
    }
}

- (BOOL)isReady
{
    return (self.unifiedInterstitialAd != nil && self.unifiedInterstitialAd.isAdValid);
}

- (id)getCustomObject
{
    return self.unifiedInterstitialAd;
}

#pragma mark - GDTUnifiedInterstitialAdDelegate

- (void)unifiedInterstitialSuccessToLoadAd:(GDTUnifiedInterstitialAd *)unifiedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)unifiedInterstitialFailToLoadAd:(GDTUnifiedInterstitialAd *)unifiedInterstitial error:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

- (void)unifiedInterstitialDidDownloadVideo:(GDTUnifiedInterstitialAd *)unifiedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)unifiedInterstitialRenderSuccess:(GDTUnifiedInterstitialAd *)unifiedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)unifiedInterstitialRenderFail:(GDTUnifiedInterstitialAd *)unifiedInterstitial error:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShowFailWithError:error];
}

- (void)unifiedInterstitialWillPresentScreen:(GDTUnifiedInterstitialAd *)unifiedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)unifiedInterstitialDidPresentScreen:(GDTUnifiedInterstitialAd *)unifiedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)unifiedInterstitialFailToPresent:(GDTUnifiedInterstitialAd *)unifiedInterstitial error:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(error)
    {
        [self AdShowFailWithError:error];
    }
}

- (void)unifiedInterstitialDidDismissScreen:(GDTUnifiedInterstitialAd *)unifiedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
     [self AdClose];
}

- (void)unifiedInterstitialWillLeaveApplication:(GDTUnifiedInterstitialAd *)unifiedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)unifiedInterstitialWillExposure:(GDTUnifiedInterstitialAd *)unifiedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)unifiedInterstitialClicked:(GDTUnifiedInterstitialAd *)unifiedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)unifiedInterstitialAdWillPresentFullScreenModal:(GDTUnifiedInterstitialAd *)unifiedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)unifiedInterstitialAdDidPresentFullScreenModal:(GDTUnifiedInterstitialAd *)unifiedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)unifiedInterstitialAdWillDismissFullScreenModal:(GDTUnifiedInterstitialAd *)unifiedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)unifiedInterstitialAdDidDismissFullScreenModal:(GDTUnifiedInterstitialAd *)unifiedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)unifiedInterstitialAd:(GDTUnifiedInterstitialAd *)unifiedInterstitial playerStatusChanged:(GDTMediaPlayerStatus)status
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)unifiedInterstitialAdViewWillPresentVideoVC:(GDTUnifiedInterstitialAd *)unifiedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)unifiedInterstitialAdViewDidPresentVideoVC:(GDTUnifiedInterstitialAd *)unifiedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)unifiedInterstitialAdViewWillDismissVideoVC:(GDTUnifiedInterstitialAd *)unifiedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)unifiedInterstitialAdViewDidDismissVideoVC:(GDTUnifiedInterstitialAd *)unifiedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)unifiedInterstitialAdDidRewardEffective:(GDTUnifiedInterstitialAd *)unifiedInterstitial info:(NSDictionary *)info
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
@end
