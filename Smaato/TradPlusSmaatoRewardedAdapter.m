#import "TradPlusSmaatoRewardedAdapter.h"
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSLogging.h>
#import <SmaatoSDKRewardedAds/SmaatoSDKRewardedAds.h>
#import "TradPlusSmaatoSDKLoader.h"
#import "TPSmaatoAdapterBaseInfo.h"

@interface TradPlusSmaatoRewardedAdapter ()<SMARewardedInterstitialDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) SMARewardedInterstitial *rewarded;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, assign) BOOL didRewarded;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;
@end

@implementation TradPlusSmaatoRewardedAdapter

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
        MSLogTrace(@"Smaato init Config Error %@",config);
        return;
    }
    if([TradPlusSmaatoSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusSmaatoSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusSmaatoSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_SmaatoAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [SmaatoSDK sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_SmaatoAdapter_PlatformSDK_Version
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
    if([item.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [item.extraInfoDictionary[@"always_reward"] integerValue] == 1;
    }
    [[TradPlusSmaatoSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    [SmaatoSDK loadRewardedInterstitialForAdSpaceId:self.placementId delegate:self];
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
    return self.rewarded;
}

- (BOOL)isReady
{
    return (self.rewarded != nil
            && self.rewarded.availableForPresentation);
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.rewarded showFromViewController:rootViewController];
}

#pragma mark - SMARewardedInterstitialDelegate

- (void)rewardedInterstitialDidLoad:(SMARewardedInterstitial *_Nonnull)rewardedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.rewarded = rewardedInterstitial;
    [self AdLoadFinsh];
}

- (void)rewardedInterstitialDidFail:(SMARewardedInterstitial *_Nullable)rewardedInterstitial withError:(NSError *_Nonnull)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

- (void)rewardedInterstitialDidTTLExpire:(SMARewardedInterstitial *_Nonnull)rewardedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedInterstitialDidReward:(SMARewardedInterstitial *_Nonnull)rewardedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(!self.didRewarded)
    {
        self.didRewarded = YES;
        self.shouldReward = YES;
    }
}

- (void)rewardedInterstitialDidAppear:(SMARewardedInterstitial *_Nonnull)rewardedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)rewardedInterstitialDidDisappear:(SMARewardedInterstitial *_Nonnull)rewardedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
    if (self.shouldReward || self.alwaysReward)
        [self AdRewardedWithInfo:nil];
    [self AdClose];
}

- (void)rewardedInterstitialDidClick:(SMARewardedInterstitial *_Nonnull)rewardedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)rewardedInterstitialWillAppear:(SMARewardedInterstitial *_Nonnull)rewardedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedInterstitialWillDisappear:(SMARewardedInterstitial *_Nonnull)rewardedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedInterstitialDidStart:(SMARewardedInterstitial *_Nonnull)rewardedInterstitial
{
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedInterstitialWillLeaveApplication:(SMARewardedInterstitial *_Nonnull)rewardedInterstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
@end
