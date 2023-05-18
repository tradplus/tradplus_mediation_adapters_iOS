#import "TradPlusMintegralInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TradPlusMintegralSDKLoader.h"
#import <MTGSDKNewInterstitial/MTGSDKNewInterstitial.h>
#import <MTGSDKNewInterstitial/MTGNewInterstitialAdManager.h>
#import "TPMintegralAdapterBaseInfo.h"

@interface TradPlusMintegralInterstitialAdapter ()<MTGNewInterstitialAdDelegate,MTGNewInterstitialBidAdDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong)MTGNewInterstitialAdManager *interstitialAdManager;
@property (nonatomic,strong)MTGNewInterstitialBidAdManager *bidInterstitialAdManager;
@property (nonatomic,assign)BOOL isBidding;
@property (nonatomic,copy)NSString *placementId;
@property (nonatomic,copy)NSString *unitId;
@property (nonatomic,assign)BOOL videoMute;
@end

@implementation TradPlusMintegralInterstitialAdapter

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
    NSString *appKey = config[@"AppKey"];
    if(appId == nil || appKey == nil)
    {
        MSLogTrace(@"Mintegral init Config Error %@",config);
        return;
    }
    if([TradPlusMintegralSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusMintegralSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusMintegralSDKLoader sharedInstance] initWithAppID:appId apiKey:appKey delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_MintegralAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [MTGSDK sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_MintegralAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *appId = item.config[@"appId"];
    NSString *appKey = item.config[@"AppKey"];
    self.placementId = item.config[@"placementId"];
    self.unitId = item.config[@"unitId"];
    self.videoMute = item.video_mute == 2 ? NO:YES;
    if(appId == nil || appKey == nil || self.placementId == nil || self.unitId == nil)
    {
        [self AdConfigError];
        return;
    }
    [[TradPlusMintegralSDKLoader sharedInstance] initWithAppID:appId apiKey:appKey delegate:self];
}

- (void)loadAd
{
    [[TradPlusMintegralSDKLoader sharedInstance] setPersonalizedAd];
    NSString *bidToken = nil;
    self.isBidding = NO;
    if(self.waterfallItem.adsourceplacement != nil)
    {
        self.isBidding = YES;
        bidToken = self.waterfallItem.adsourceplacement.adm;
    }
    
    if(self.waterfallItem.dicCustomValue != nil
       && [self.waterfallItem.dicCustomValue valueForKey:@"video_mute"])
    {
        NSInteger video_mute = [self.waterfallItem.dicCustomValue[@"video_mute"] integerValue];
        if(video_mute == 2)
        {
            self.videoMute = NO;
        }
    }
    if(self.isBidding)
    {
        self.bidInterstitialAdManager = [[MTGNewInterstitialBidAdManager alloc] initWithPlacementId:self.placementId unitId:self.unitId delegate:self];
        self.bidInterstitialAdManager.playVideoMute = self.videoMute;
        [self.bidInterstitialAdManager loadAdWithBidToken:bidToken];
    }
    else
    {
        self.interstitialAdManager = [[MTGNewInterstitialAdManager alloc] initWithPlacementId:self.placementId unitId:self.unitId delegate:self];
        self.interstitialAdManager.playVideoMute = self.videoMute;
        [self.interstitialAdManager loadAd];
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

- (id)getCustomObject
{
    if(self.isBidding)
    {
        return self.bidInterstitialAdManager;
    }
    else
    {
        return self.interstitialAdManager;
    }
}

- (BOOL)isReady
{
    if(self.isBidding)
    {
        if(self.bidInterstitialAdManager != nil)
        {
            return [self.bidInterstitialAdManager isAdReady];
        }
    }
    else
    {
        if(self.interstitialAdManager != nil)
        {
            return [self.interstitialAdManager isAdReady];
        }
    }
    return NO;
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    if(self.isBidding)
    {
        [self.bidInterstitialAdManager showFromViewController:rootViewController];
    }
    else
    {
        [self.interstitialAdManager showFromViewController:rootViewController];
    }
}

#pragma mark - MTGNewInterstitialAdDelegate
- (void)newInterstitialAdLoadSuccess:(MTGNewInterstitialAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)newInterstitialAdResourceLoadSuccess:(MTGNewInterstitialAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)newInterstitialAdLoadFail:(nonnull NSError *)error adManager:(MTGNewInterstitialAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s error:%@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

- (void)newInterstitialAdShowSuccess:(MTGNewInterstitialAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)newInterstitialAdShowFail:(nonnull NSError *)error adManager:(MTGNewInterstitialAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s error:%@", __PRETTY_FUNCTION__,error);
    [self AdShowFailWithError:error];
}


- (void)newInterstitialAdPlayCompleted:(MTGNewInterstitialAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}

- (void)newInterstitialAdEndCardShowSuccess:(MTGNewInterstitialAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)newInterstitialAdClicked:(MTGNewInterstitialAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)newInterstitialAdDismissedWithConverted:(BOOL)converted adManager:(MTGNewInterstitialAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)newInterstitialAdDidClosed:(MTGNewInterstitialAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

- (void)newInterstitialAdRewarded:(BOOL)rewardedOrNot alertWindowStatus:(MTGNIAlertWindowStatus)alertWindowStatus adManager:(MTGNewInterstitialAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

#pragma mark - MTGNewInterstitialBidAdDelegate

- (void)newInterstitialBidAdLoadSuccess:(MTGNewInterstitialBidAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)newInterstitialBidAdResourceLoadSuccess:(MTGNewInterstitialBidAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)newInterstitialBidAdLoadFail:(nonnull NSError *)error adManager:(MTGNewInterstitialBidAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s error:%@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

- (void)newInterstitialBidAdShowSuccess:(MTGNewInterstitialBidAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)newInterstitialBidAdShowSuccessWithBidToken:(nonnull NSString * )bidToken adManager:(MTGNewInterstitialBidAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)newInterstitialBidAdShowFail:(nonnull NSError *)error adManager:(MTGNewInterstitialBidAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s error:%@", __PRETTY_FUNCTION__,error);
    [self AdShowFailWithError:error];
}

- (void)newInterstitialBidAdPlayCompleted:(MTGNewInterstitialBidAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}

- (void)newInterstitialBidAdEndCardShowSuccess:(MTGNewInterstitialBidAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)newInterstitialBidAdClicked:(MTGNewInterstitialBidAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}


- (void)newInterstitialBidAdDismissedWithConverted:(BOOL)converted adManager:(MTGNewInterstitialBidAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)newInterstitialBidAdDidClosed:(MTGNewInterstitialBidAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

- (void)newInterstitialBidAdRewarded:(BOOL)rewardedOrNot alertWindowStatus:(MTGNIAlertWindowStatus)alertWindowStatus adManager:(MTGNewInterstitialBidAdManager *_Nonnull)adManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
@end
