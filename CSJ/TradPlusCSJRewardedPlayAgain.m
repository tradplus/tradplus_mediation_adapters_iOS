#import "TradPlusCSJRewardedPlayAgain.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>

@interface TradPlusCSJRewardedPlayAgain()

@property (nonatomic,assign)BOOL didShow;
@end

@implementation TradPlusCSJRewardedPlayAgain

- (void)rewardedVideoAdDidLoad:(BURewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAd:(BURewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *_Nullable)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAdVideoDidLoad:(BURewardedVideoAd *)rewardedVideoAd;
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAdWillVisible:(BURewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAdDidVisible:(BURewardedVideoAd *)rewardedVideoAd
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

- (void)rewardedVideoAdWillClose:(BURewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAdDidClose:(BURewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAdDidClick:(BURewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.rewardedAdapter != nil)
    {
        [self.rewardedAdapter ADShowExtraCallbackWithEvent:@"playAgain_click" info:nil];
    }
}

- (void)rewardedVideoAdDidPlayFinish:(BURewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *_Nullable)error
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

- (void)rewardedVideoAdServerRewardDidSucceed:(BURewardedVideoAd *)rewardedVideoAd verify:(BOOL)verify
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.rewardedAdapter != nil)
    {
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        dic[@"rewardType"] = @(rewardedVideoAd.rewardedVideoModel.rewardType);
        dic[@"rewardPropose"] = @(rewardedVideoAd.rewardedVideoModel.rewardPropose);
        dic[@"rewardName"] = rewardedVideoAd.rewardedVideoModel.rewardName;
        dic[@"rewardAmount"] = @(rewardedVideoAd.rewardedVideoModel.rewardAmount);
        [self.rewardedAdapter AdPlayAgainRewardedWithInfo:dic];
    }
}

- (void)rewardedVideoAdServerRewardDidFail:(BURewardedVideoAd *)rewardedVideoAd error:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAdDidClickSkip:(BURewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAdCallback:(BURewardedVideoAd *)rewardedVideoAd withType:(BURewardedVideoAdType)rewardedVideoAdType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

@end
