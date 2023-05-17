#import "TradPlusFacebookRewardedAdapter.h"
#import "TPFacebookAdapterConfig.h"
#import <FBAudienceNetwork/FBAudienceNetwork.h>
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TPFacebookAdapterBaseInfo.h"

@interface TradPlusFacebookRewardedAdapter ()<FBRewardedVideoAdDelegate, FBRewardedInterstitialAdDelegate>

@property (nonatomic, strong) FBRewardedVideoAd *rewardedVideoAd;
@property (nonatomic, strong) FBRewardedInterstitialAd *rewardedInterstitialAd;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;
@property (nonatomic, assign) BOOL isRewardedVideoAd;
@end

@implementation TradPlusFacebookRewardedAdapter

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
    NSDictionary *dic = @{@"version":TP_FacebookAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = FB_AD_SDK_VERSION;
    if(version == nil)
    {
       version = @"";
    }
    NSDictionary *dic = @{
       @"version":version,
       @"adaptedVersion":TP_FacebookAdapter_PlatformSDK_Version
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
    [TPFacebookAdapterConfig setPrivacy:@{}];
    if([item.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [item.extraInfoDictionary[@"always_reward"] integerValue] == 1;
    }
    self.isRewardedVideoAd = item.full_screen_video != 2;
    if (self.isRewardedVideoAd)
    {
        self.rewardedVideoAd = [[FBRewardedVideoAd alloc] initWithPlacementID:placementId];
        self.rewardedVideoAd.delegate = self;
    }
    else {
        self.rewardedInterstitialAd = [[FBRewardedInterstitialAd alloc] initWithPlacementID:placementId];
        self.rewardedInterstitialAd.delegate = self;
    }
    
    if(self.waterfallItem.serverSideUserID != nil && self.waterfallItem.serverSideUserID.length > 0)
    {
        NSString *userID = self.waterfallItem.serverSideUserID;
        NSString *customData = @"";
        if(self.waterfallItem.serverSideCustomData != nil)
        {
            customData = self.waterfallItem.serverSideCustomData;
        }
        if (self.isRewardedVideoAd)
            [self.rewardedVideoAd setRewardDataWithUserID:userID withCurrency:customData];
        else
            [self.rewardedInterstitialAd setRewardDataWithUserID:userID withCurrency:customData];
        MSLogTrace(@"FBRewardedVideoAd ServerSideVerification ->userID: %@, customData:%@", userID, customData);
    }
    
    NSString *bidToken = nil;
    if(item.adsourceplacement != nil)
    {
        bidToken = item.adsourceplacement.adm;
    }
    if(bidToken == nil)
    {
        if (self.isRewardedVideoAd)
            [self.rewardedVideoAd loadAd];
        else
            [self.rewardedInterstitialAd loadAd];
    }
    else
    {
        if (self.isRewardedVideoAd)
            [self.rewardedVideoAd loadAdWithBidPayload:bidToken];
        else
            [self.rewardedInterstitialAd loadAdWithBidPayload:bidToken];
    }
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    if (self.isRewardedVideoAd)
        [self.rewardedVideoAd showAdFromRootViewController:rootViewController];
    else
        [self.rewardedInterstitialAd showAdFromRootViewController:rootViewController animated:YES];
}

- (id)getCustomObject
{
    if (self.isRewardedVideoAd)
        return self.rewardedVideoAd;
    else
        return self.rewardedInterstitialAd;
}

- (BOOL)isReady
{
    if (self.isRewardedVideoAd)
        return (self.rewardedVideoAd != nil && self.rewardedVideoAd.isAdValid);
    else
        return (self.rewardedInterstitialAd != nil && self.rewardedInterstitialAd.isAdValid);
}

#pragma mark - FBRewardedVideoAdDelegate

- (void)rewardedVideoAdDidLoad:(FBRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)rewardedVideoAd:(FBRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFailWithError:error];
}

- (void)rewardedVideoAdWillLogImpression:(FBRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)rewardedVideoAdDidClick:(FBRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)rewardedVideoAdDidClose:(FBRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if (self.shouldReward || self.alwaysReward)
        [self AdRewardedWithInfo:nil];
    [self AdClose];
}

- (void)rewardedVideoAdVideoComplete:(FBRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
    self.shouldReward = YES;
}

- (void)rewardedVideoAdWillClose:(FBRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAdServerRewardDidSucceed:(FBRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAdServerRewardDidFail:(FBRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

#pragma mark FBRewardedInterstitialAdDelegate
- (void)rewardedInterstitialAdDidClick:(FBRewardedInterstitialAd *)rewardedInterstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)rewardedInterstitialAdDidLoad:(FBRewardedInterstitialAd *)rewardedInterstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)rewardedInterstitialAdDidClose:(FBRewardedInterstitialAd *)rewardedInterstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if (self.shouldReward || self.alwaysReward)
        [self AdRewardedWithInfo:nil];
    [self AdClose];
}

- (void)rewardedInterstitialAdWillClose:(FBRewardedInterstitialAd *)rewardedInterstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedInterstitialAd:(FBRewardedInterstitialAd *)rewardedInterstitialAd didFailWithError:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__, error);
    [self AdLoadFailWithError:error];
}

- (void)rewardedInterstitialAdWillLogImpression:(FBRewardedInterstitialAd *)rewardedInterstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)rewardedInterstitialAdVideoComplete:(FBRewardedInterstitialAd *)rewardedInterstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
    self.shouldReward = YES;
}


@end
