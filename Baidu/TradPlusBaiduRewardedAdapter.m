#import "TradPlusBaiduRewardedAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <BaiduMobAdSDK/BaiduMobAdRewardVideo.h>
#import "TradPlusBaiduSDKSetting.h"
#import "TPBaiduAdapterBaseInfo.h"

@interface TradPlusBaiduRewardedAdapter ()<BaiduMobAdRewardVideoDelegate>

@property (nonatomic, strong) BaiduMobAdRewardVideo *rewardedVideoAd;
@property (nonatomic, assign) BOOL isC2SBidding;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;
@property (nonatomic, assign) BOOL isSkip;
@end

@implementation TradPlusBaiduRewardedAdapter

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
    else if([event isEqualToString:@"C2SBidding"])
    {
        [self initSDKC2SBidding];
    }
    else if([event isEqualToString:@"LoadAdC2SBidding"])
    {
        [self loadAdC2SBidding];
    }
    else
    {
        return NO;
    }
    return YES;
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_BaiduAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = SDK_VERSION_IN_MSSP;
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_BaiduAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *appId = item.config[@"appId"];
    NSString *placementId = item.config[@"placementId"];
    if(placementId == nil || appId == nil)
    {
        [self AdConfigError];
        return;
    }
    
    if([item.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [item.extraInfoDictionary[@"always_reward"] integerValue] == 1;
    }
    
    [[TradPlusBaiduSDKSetting sharedInstance] setPersonalizedAd];
    self.rewardedVideoAd = [[BaiduMobAdRewardVideo alloc] init];
    self.rewardedVideoAd.delegate = self;
    self.rewardedVideoAd.AdUnitTag = placementId;
    self.rewardedVideoAd.publisherId = appId;
    if(item.serverSideUserID != nil && item.serverSideUserID.length > 0)
    {
        self.rewardedVideoAd.userID = item.serverSideUserID;
    }
    if(item.serverSideCustomData != nil && item.serverSideCustomData.length > 0)
    {
        self.rewardedVideoAd.extraInfo = item.serverSideCustomData;
    }
    [self.rewardedVideoAd load];
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.rewardedVideoAd showFromViewController:rootViewController];    
}

- (BOOL)isReady
{
    return self.rewardedVideoAd.isReady;
}

- (id)getCustomObject
{
    return self.rewardedVideoAd;
}

#pragma mark - C2SBidding

- (void)initSDKC2SBidding
{
    self.isC2SBidding = YES;
    [self loadAdWithWaterfallItem:self.waterfallItem];
}

- (void)loadAdC2SBidding
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if([self isReady])
    {
        [self AdLoadFinsh];
    }
    else
    {
        NSError *loadError = [NSError errorWithDomain:@"baidu.rewarded" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S Rewarded not ready"}];
        [self AdLoadFailWithError:loadError];
    }
}

- (void)finishC2SBiddingWithEcpm:(NSString *)ecpmStr
{
    NSString *version = SDK_VERSION_IN_MSSP;
    if(version == nil)
    {
        version = @"";
    }
    if(ecpmStr == nil)
    {
        ecpmStr = @"0";
    }
    NSDictionary *dic = @{@"ecpm":ecpmStr,@"version":version};
    [self ADLoadExtraCallbackWithEvent:@"C2SBiddingFinish" info:dic];
}

- (void)failC2SBiddingWithErrorStr:(NSString *)errorStr
{
    NSDictionary *dic = @{@"error":errorStr};
    [self ADLoadExtraCallbackWithEvent:@"C2SBiddingFail" info:dic];
}

#pragma mark - BaiduMobAdRewardVideoDelegate

- (void)rewardedAdLoadSuccess:(BaiduMobAdRewardVideo *)video
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedAdLoadFailCode:(NSString *)errCode message:(NSString *)message rewardedAd:(BaiduMobAdRewardVideo *)video
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(errCode == nil)
    {
        errCode = @"4001";
    }
    if(self.isC2SBidding)
    {
        if(message == nil)
        {
            message = @"C2S Bidding Fail";
        }
        NSString *errorStr = [NSString stringWithFormat:@"errCode: %@, errMsg: %@", errCode, message];
        [self failC2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        if(message == nil)
        {
            message = @"load faile";
        }
        NSError *error = [NSError errorWithDomain:@"Baidu" code:[errCode integerValue] userInfo:@{NSLocalizedDescriptionKey: message}];
        [self AdLoadFailWithError:error];
    }
}

- (void)rewardedVideoAdLoaded:(BaiduMobAdRewardVideo *)video
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.isC2SBidding)
    {
        [self finishC2SBiddingWithEcpm:[video getECPMLevel]];
    }
    else
    {
        [self AdLoadFinsh];
    }
}

- (void)rewardedVideoAdLoadFailed:(BaiduMobAdRewardVideo *)video withError:(BaiduMobFailReason)reason
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.isC2SBidding)
    {
        NSString *errorStr = @"C2S Bidding Fail";
        [self failC2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        NSError *error = [NSError errorWithDomain:@"Baidu" code:reason userInfo:@{NSLocalizedDescriptionKey: @"load failed"}];
        [self AdLoadFailWithError:error];
    }
}

- (void)rewardedVideoAdDidStarted:(BaiduMobAdRewardVideo *)video
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)rewardedVideoAdShowFailed:(BaiduMobAdRewardVideo *)video withError:(BaiduMobFailReason)reason
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSString *strError = [NSString stringWithFormat:@"show fail, reason:%d", reason];
    NSError *error = [NSError errorWithDomain:@"Baidu" code:reason userInfo:@{NSLocalizedDescriptionKey: strError}];
    [self AdShowFailWithError:error];
}

- (void)rewardedVideoAdDidPlayFinish:(BaiduMobAdRewardVideo *)video
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}

- (void)rewardedVideoAdRewardDidSuccess:(BaiduMobAdRewardVideo *)video verify:(BOOL)verify
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.shouldReward = YES;
}

- (void)rewardedVideoAdDidSkip:(BaiduMobAdRewardVideo *)video withPlayingProgress:(CGFloat)progress
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.isSkip = YES;
}

- (void)rewardedVideoAdDidClose:(BaiduMobAdRewardVideo *)video withPlayingProgress:(CGFloat)progress
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if (self.shouldReward || (self.alwaysReward && !self.isSkip))
        [self AdRewardedWithInfo:nil];
    [self AdClose];
}

- (void)rewardedVideoAdDidClick:(BaiduMobAdRewardVideo *)video withPlayingProgress:(CGFloat)progress
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

@end
