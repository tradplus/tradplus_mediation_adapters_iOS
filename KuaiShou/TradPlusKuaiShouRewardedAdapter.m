#import "TradPlusKuaiShouRewardedAdapter.h"
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/MSLogging.h>
#import "TradPlusKuaiShouSDKLoader.h"
#import <KSAdSDK/KSAdSDK.h>
#import "TradPlusKuaiShouRewardedPlayAgain.h"
#import "TPKuaiShouAdapterBaseInfo.h"

@interface TradPlusKuaiShouRewardedAdapter ()<KSRewardedVideoAdDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong)KSRewardedVideoAd *rewardedVideoAd;
@property (nonatomic,copy)NSString *placementId;
@property (nonatomic,strong)TradPlusKuaiShouRewardedPlayAgain *rewardedPlayAgain;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;
@property (nonatomic, assign) BOOL isSkip;
@property (nonatomic, strong) NSMutableDictionary *rewardDic;
@end

@implementation TradPlusKuaiShouRewardedAdapter

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
        MSLogTrace(@"KuaiShou init Config Error %@",config);
        return;
    }
    if([TradPlusKuaiShouSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusKuaiShouSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusKuaiShouSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_KuaiShouAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [KSAdSDKManager SDKVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_KuaiShouAdapter_PlatformSDK_Version
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
    [[TradPlusKuaiShouSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    [[TradPlusKuaiShouSDKLoader sharedInstance] setPersonalizedAd];
    KSRewardedVideoModel *rewardedVideoModel = [[KSRewardedVideoModel alloc] init];
    if(self.waterfallItem.serverSideUserID != nil
       && self.waterfallItem.serverSideUserID.length > 0)
    {
        rewardedVideoModel.userId = self.waterfallItem.serverSideUserID;
        if(self.waterfallItem.serverSideCustomData != nil
           && self.waterfallItem.serverSideCustomData.length > 0)
        {
            rewardedVideoModel.extra = self.waterfallItem.serverSideCustomData;
            MSLogTrace(@"KuaiShou ServerSideVerification ->userID: %@, customData:%@", self.waterfallItem.serverSideUserID, self.waterfallItem.serverSideCustomData);
        }
        else
        {
            MSLogTrace(@"KuaiShou ServerSideVerification ->userID: %@", self.waterfallItem.serverSideUserID);
        }
    }
    BOOL mute = YES;
    if(self.waterfallItem.video_mute == 2)
    {
        mute = NO;
    }
    self.rewardedVideoAd = [[KSRewardedVideoAd alloc] initWithPosId:self.placementId rewardedVideoModel:rewardedVideoModel];
    self.rewardedVideoAd.shouldMuted = mute;
    self.rewardedVideoAd.delegate = self;
    self.rewardedPlayAgain = [[TradPlusKuaiShouRewardedPlayAgain alloc] init];
    self.rewardedPlayAgain.rewardedAdapter = self;
    self.rewardedVideoAd.rewardPlayAgainInteractionDelegate = self.rewardedPlayAgain;
    self.rewardDic = [NSMutableDictionary dictionary];
    
    NSDictionary *dicBidToken = nil;
    if (self.waterfallItem.adsourceplacement != nil)
    {
        NSString *bidToken = self.waterfallItem.adsourceplacement.adm;
        NSData *admData = [bidToken dataUsingEncoding:NSUTF8StringEncoding];
        dicBidToken = [NSJSONSerialization JSONObjectWithData:admData options:0 error:nil];
    }
    if (dicBidToken)
        [self.rewardedVideoAd loadAdDataWithResponseV2:dicBidToken];
    else
        [self.rewardedVideoAd loadAdData];
    
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
    KSAdShowDirection showDirection = KSAdShowDirection_Vertical;
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if(orientation == UIDeviceOrientationLandscapeRight || orientation == UIDeviceOrientationLandscapeLeft)
    {
        showDirection = KSAdShowDirection_Horizontal;
    }
    self.rewardedVideoAd.showDirection = showDirection;
    [self.rewardedVideoAd showAdFromRootViewController:rootViewController];
}

- (BOOL)isReady
{
    return (self.rewardedVideoAd != nil && self.rewardedVideoAd.isValid);
}

- (id)getCustomObject
{
    return self.rewardedVideoAd;
}

- (void)callbackCloseAct
{
    if (self.shouldReward || (self.alwaysReward && !self.isSkip))
        [self AdRewardedWithInfo:self.rewardDic];
    [self AdClose];
}

#pragma mark - KSRewardedVideoAdDelegate

- (void)rewardedVideoAdDidLoad:(KSRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAd:(KSRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *_Nullable)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__ ,error);
    [self AdLoadFailWithError:error];
}

- (void)rewardedVideoAdVideoDidLoad:(KSRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)rewardedVideoAdWillVisible:(KSRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAdDidVisible:(KSRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)rewardedVideoAdWillClose:(KSRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAdDidClose:(KSRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self callbackCloseAct];
}

- (void)rewardedVideoAdDidClick:(KSRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)rewardedVideoAdDidPlayFinish:(KSRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *_Nullable)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(error != nil)
    {
        [self AdShowFailWithError:error];
    }
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}

- (void)rewardedVideoAdDidClickSkip:(KSRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.isSkip = YES;
}

- (void)rewardedVideoAdDidClickSkip:(KSRewardedVideoAd *)rewardedVideoAd currentTime:(NSTimeInterval)currentTime
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.isSkip = YES;
}

- (void)rewardedVideoAdStartPlay:(KSRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardedVideoAd:(KSRewardedVideoAd *)rewardedVideoAd hasReward:(BOOL)hasReward
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(hasReward)
    {
        self.shouldReward = YES;
        self.rewardDic[@"name"] = rewardedVideoAd.rewardedVideoModel.name;
        self.rewardDic[@"amount"] = @(rewardedVideoAd.rewardedVideoModel.amount);
    }
}

- (void)rewardedVideoAd:(KSRewardedVideoAd *)rewardedVideoAd hasReward:(BOOL)hasReward taskType:(KSAdRewardTaskType)taskType currentTaskType:(KSAdRewardTaskType)currentTaskType
{
    self.rewardDic[@"taskType"] = @(taskType);
    self.rewardDic[@"currentTaskType"] = @(currentTaskType);
}

- (void)rewardedVideoAd:(KSRewardedVideoAd *)rewardedVideoAd extraRewardVerify:(KSAdExtraRewardType)extraRewardType
{
    
}
@end
