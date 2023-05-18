#import "TradPlusVungleInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TPVungleRouter.h"
#import "TradPlusVungleSDKLoader.h"
#import "TPVungleAdapterBaseInfo.h"

@interface TradPlusVungleInterstitialAdapter ()<TPVungleRouterDelegate,TPSDKLoaderDelegate>

@property (nonatomic,copy)NSString *placementId;
@property (nonatomic,copy)NSString *bidToken;
@property (nonatomic, assign) BOOL videoMute;

@end

@implementation TradPlusVungleInterstitialAdapter

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
        MSLogTrace(@"Vungle init Config Error %@",config);
        return;
    }
    if([TradPlusVungleSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusVungleSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusVungleSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_VungleAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = VungleSDKVersion;
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_VungleAdapter_PlatformSDK_Version
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
    
    self.videoMute = YES;
    if(item.video_mute == 2)
    {
        self.videoMute = NO;
    }
    [[TradPlusVungleSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    if(self.waterfallItem.adsourceplacement != nil)
    {
        self.bidToken = self.waterfallItem.adsourceplacement.adm;
    }
    [[TPVungleRouter sharedRouter] requestInterstitialAdWithPlacementId:self.placementId delegate:self bidToken:self.bidToken];
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
    [[VungleSDK sharedSDK] setMuted:self.videoMute];
    [[TPVungleRouter sharedRouter] presentInterstitialAdFromViewController:rootViewController options:nil forPlacementId:self.placementId bidToken:self.bidToken];
}

- (void)adViewWillDestroy
{
    [[TPVungleRouter sharedRouter] clearDelegateForPlacementId:self.placementId];
}

- (id)getCustomObject
{
    return nil;
}

- (BOOL)isReady
{
    return [[TPVungleRouter sharedRouter] isAdAvailableForPlacementId:self.placementId bidToken:self.bidToken];
}

#pragma mark - TPVungleRouterDelegate

- (void)vungleAdDidLoad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)vungleAdWasTapped
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)vungleAdDidFailToLoad:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFailWithError:error];
}

- (void)vungleAdDidFailToPlay:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShowFailWithError:error];
}

- (void)vungleAdWillAppear
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)vungleAdWillDisappear
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

- (void)vungleAdDidShow
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}
@end
