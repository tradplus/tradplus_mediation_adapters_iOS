#import "TradPlusMyTargetRewardedAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <MyTargetSDK/MyTargetSDK.h>
#import "TPMyTargetAdapterBaseInfo.h"
#import "TradPlusMyTargetSDKSetting.h"

@interface TradPlusMyTargetRewardedAdapter ()<MTRGRewardedAdDelegate>

@property (nonatomic, strong) MTRGRewardedAd *rewardedAd;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;
@property (nonatomic, strong) NSMutableDictionary *rewardDic;
@end

@implementation TradPlusMyTargetRewardedAdapter

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
    NSDictionary *dic = @{@"version":TP_MyTargetAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [MTRGVersion currentVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_MyTargetAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *slotId = item.config[@"slot_id"];
    if(slotId == nil)
    {
        [self AdConfigError];
        return;;
    }
    
    [TradPlusMyTargetSDKSetting setPrivacy];
    
    self.rewardedAd = [MTRGRewardedAd rewardedAdWithSlotId:[slotId intValue]];
    self.rewardedAd.delegate = self;
    
    if([item.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [item.extraInfoDictionary[@"always_reward"] integerValue] == 1;
    }
    
    NSString *bidToken = nil;
    if(item.adsourceplacement != nil)
    {
        bidToken = item.adsourceplacement.adm;
    }
    if(bidToken == nil)
    {
        [self.rewardedAd load];
    }
    else
    {
        [self.rewardedAd loadFromBid:bidToken];
    }
}


- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.rewardedAd showWithController:rootViewController];
}

- (BOOL)isReady
{
    return self.isAdReady;
}

- (id)getCustomObject
{
    return self.rewardedAd;
}

#pragma mark - MTRGRewardedAdDelegate
- (void)onLoadWithRewardedAd:(MTRGRewardedAd *)rewardedAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)onNoAdWithReason:(NSString *)reason rewardedAd:(MTRGRewardedAd *)rewardedAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSError *error = [NSError errorWithDomain:@"MyTarget No Ad" code:400 userInfo:@{NSLocalizedDescriptionKey:reason}];
    [self AdLoadFailWithError:error];
}

- (void)onReward:(MTRGReward *)reward rewardedAd:(MTRGRewardedAd *)rewardedAd
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,reward.type);
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    dic[@"type"] = reward.type;
    self.rewardDic = [NSMutableDictionary dictionaryWithDictionary:dic];
    self.shouldReward = YES;
}

- (void)onClickWithRewardedAd:(MTRGRewardedAd *)rewardedAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)onCloseWithRewardedAd:(MTRGRewardedAd *)rewardedAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
    if (self.shouldReward || self.alwaysReward)
        [self AdRewardedWithInfo:self.rewardDic];
    [self AdClose];
}

- (void)onDisplayWithRewardedAd:(MTRGRewardedAd *)rewardedAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)onLeaveApplicationWithRewardedAd:(MTRGRewardedAd *)rewardedAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
@end
