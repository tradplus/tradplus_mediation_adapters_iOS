#import "TradPlusCSJExpressRewardedPlayAgain.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>

@interface TradPlusCSJExpressRewardedPlayAgain()
@property (nonatomic,assign)BOOL didShow;
@end

@implementation TradPlusCSJExpressRewardedPlayAgain

- (void)nativeExpressRewardedVideoAdDidLoad:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeExpressRewardedVideoAd:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *_Nullable)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeExpressRewardedVideoAdCallback:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd withType:(BUNativeExpressRewardedVideoAdType)nativeExpressVideoType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeExpressRewardedVideoAdDidDownLoadVideo:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeExpressRewardedVideoAdViewRenderSuccess:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeExpressRewardedVideoAdViewRenderFail:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd error:(NSError *_Nullable)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeExpressRewardedVideoAdWillVisible:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeExpressRewardedVideoAdDidVisible:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
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

- (void)nativeExpressRewardedVideoAdWillClose:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeExpressRewardedVideoAdDidClose:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeExpressRewardedVideoAdDidClick:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.rewardedAdapter != nil)
    {
        [self.rewardedAdapter ADShowExtraCallbackWithEvent:@"playAgain_click" info:nil];
    }
}

- (void)nativeExpressRewardedVideoAdDidClickSkip:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeExpressRewardedVideoAdDidPlayFinish:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *_Nullable)error
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

- (void)nativeExpressRewardedVideoAdServerRewardDidSucceed:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd verify:(BOOL)verify
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

- (void)nativeExpressRewardedVideoAdServerRewardDidFail:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd error:(NSError *_Nullable)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeExpressRewardedVideoAdDidCloseOtherController:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd interactionType:(BUInteractionType)interactionType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

@end
