#import "TradPlusYandexRewardedAdapter.h"
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSLogging.h>
#import <YandexMobileAds/YandexMobileAds.h>
#import "TPYandexAdapterBaseInfo.h"
#import "TradPlusYandexSDKSetting.h"

@interface TradPlusYandexRewardedAdapter ()<YMARewardedAdDelegate>

@property (nonatomic, strong) YMARewardedAd *rewardedVideoAd;
@property (nonatomic, strong) YMABidderTokenLoader *loader;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;
@property (nonatomic, strong) NSMutableDictionary *rewardDic;

@end

@implementation TradPlusYandexRewardedAdapter

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
    else if([event isEqualToString:@"S2SBidding"])
    {
        [self getBiddingToken];
    }
    else
    {
        return NO;
    }
    return YES;
}

- (void)getBiddingToken
{
    [TradPlusYandexSDKSetting showAdapterInfo];
    self.loader = [[YMABidderTokenLoader alloc] init];
    __weak typeof(self) weakSelf = self;
    [self.loader loadBidderTokenWithCompletionHandler:^(NSString * _Nullable bidderToken) {
        if(bidderToken == nil)
        {
            bidderToken = @"";
        }
        NSString *version = [YMAMobileAds SDKVersion];
        if(version == nil)
        {
           version = @"";
        }
        NSDictionary *dic = @{@"token":bidderToken,@"version":version};
        [weakSelf ADLoadExtraCallbackWithEvent:@"S2SBiddingFinish" info:dic];
    }];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_YandexAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [YMAMobileAds SDKVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_YandexAdapter_PlatformSDK_Version
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
    if([item.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [item.extraInfoDictionary[@"always_reward"] integerValue] == 1;
    }
    [TradPlusYandexSDKSetting setPrivacy];
    if(self.waterfallItem.serverSideUserID != nil
       && self.waterfallItem.serverSideUserID.length > 0)
    {
        self.rewardedVideoAd.userID = self.waterfallItem.serverSideUserID;
    }
    self.rewardedVideoAd = [[YMARewardedAd alloc] initWithAdUnitID:placementId];
    self.rewardedVideoAd.delegate = self;
    
    NSString *bidToken = nil;
    if (self.waterfallItem.adsourceplacement != nil)
    {
        bidToken = self.waterfallItem.adsourceplacement.adm;
    }
    if (bidToken)
    {
        YMAMutableAdRequest *request = [[YMAMutableAdRequest alloc] init];
        request.biddingData = bidToken;
        [self.rewardedVideoAd loadWithRequest:request];
    }
    else
        [self.rewardedVideoAd load];
    
}


- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.rewardedVideoAd presentFromViewController:rootViewController];
}

- (BOOL)isReady
{
    return (self.rewardedVideoAd != nil);
}

- (id)getCustomObject
{
    return self.rewardedVideoAd;
}

#pragma mark - YMARewardedAdDelegate

- (void)rewardedAdDidFailToLoad:(YMARewardedAd *)rewardedAd error:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__ ,error);
    [self AdLoadFailWithError:error];
}

- (void)rewardedAdDidLoad:(YMARewardedAd *)rewardedAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)rewardedAdDidAppear:(YMARewardedAd *)rewardedAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedAdDidDisappear:(YMARewardedAd *)rewardedAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
    if (self.shouldReward || self.alwaysReward)
        [self AdRewardedWithInfo:self.rewardDic];
    [self AdClose];
}

- (void)rewardedAdDidClick:(YMARewardedAd *)rewardedAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)rewardedAdDidFailToPresent:(YMARewardedAd *)rewardedAd error:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__ ,error);
    [self AdShowFailWithError:error];
}

- (void)rewardedAd:(YMARewardedAd *)rewardedAd didReward:(id<YMAReward>)reward
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    if(reward != nil)
    {
        dic[@"rewardName"] = reward.type;
        dic[@"rewardNumber"] = @(reward.amount);
    }
    self.rewardDic = [NSMutableDictionary dictionaryWithDictionary:dic];
    self.shouldReward = YES;
}

- (void)rewardedAd:(YMARewardedAd *)rewardedAd
        didTrackImpressionWithData:(nullable id<YMAImpressionData>)impressionData
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}
@end
