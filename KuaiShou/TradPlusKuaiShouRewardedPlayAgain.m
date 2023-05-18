#import "TradPlusKuaiShouRewardedPlayAgain.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>

@interface TradPlusKuaiShouRewardedPlayAgain()

@property (nonatomic,assign)BOOL didShow;
@end

@implementation TradPlusKuaiShouRewardedPlayAgain

- (void)rewardedVideoAdDidLoad:(KSRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAd:(KSRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *_Nullable)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAdVideoDidLoad:(KSRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAdWillVisible:(KSRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAdDidVisible:(KSRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.rewardedAdapter != nil)
    {
        if(!self.didShow)
        {
            self.didShow = YES;
            [self.rewardedAdapter ADShowExtraCallbackWithEvent:@"playAgain_show" info:nil];
            [self.rewardedAdapter ADShowExtraCallbackWithEvent:@"playAgain_play_begin" info:nil];
        }
    }
}

- (void)rewardedVideoAdWillClose:(KSRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAdDidClose:(KSRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self.rewardedAdapter callbackCloseAct];
}


- (void)rewardedVideoAdDidClick:(KSRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.rewardedAdapter != nil)
    {
        [self.rewardedAdapter ADShowExtraCallbackWithEvent:@"playAgain_click" info:nil];
    }
}

- (void)rewardedVideoAdDidPlayFinish:(KSRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *_Nullable)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.rewardedAdapter != nil)
    {
        if(error != nil)
        {
            [self.rewardedAdapter ADShowExtraCallbackWithEvent:@"playAgain_showFail" info:@{@"error":error}];
        }
        [self.rewardedAdapter ADShowExtraCallbackWithEvent:@"playAgain_play_end" info:nil];
    }
}

- (void)rewardedVideoAdDidClickSkip:(KSRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAdDidClickSkip:(KSRewardedVideoAd *)rewardedVideoAd currentTime:(NSTimeInterval)currentTime
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAdStartPlay:(KSRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAd:(KSRewardedVideoAd *)rewardedVideoAd hasReward:(BOOL)hasReward
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAd:(KSRewardedVideoAd *)rewardedVideoAd hasReward:(BOOL)hasReward taskType:(KSAdRewardTaskType)taskType currentTaskType:(KSAdRewardTaskType)currentTaskType
{
    if(self.rewardedAdapter != nil)
    {
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
        dic[@"name"] = rewardedVideoAd.rewardedVideoModel.name;
        dic[@"amount"] = @(rewardedVideoAd.rewardedVideoModel.amount);
        dic[@"taskType"] = @(taskType);
        dic[@"currentTaskType"] = @(currentTaskType);
        [self.rewardedAdapter AdPlayAgainRewardedWithInfo:dic];
    }
}
@end
