import "TradPlusMintegralRewardedAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TradPlusMintegralSDKLoader.h"
#import <MTGSDKReward/MTGRewardAdManager.h>
#import <MTGSDKReward/MTGBidRewardAdManager.h>
#import "TPMintegralAdapterBaseInfo.h"

@interface TradPlusMintegralRewardedAdapter ()<MTGRewardAdLoadDelegate,MTGRewardAdShowDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong)MTGRewardAdManager *rewardAdManager;
@property (nonatomic,copy)NSString *placementId;
@property (nonatomic,copy)NSString *unitId;
@property (nonatomic,assign)BOOL isBidding;
@property (nonatomic,copy)NSString *userID;
@property (nonatomic,copy)NSString *customData;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;
@property (nonatomic, strong) NSMutableDictionary *rewardDic;
@property (nonatomic, assign) BOOL videoMute;
@end

@implementation TradPlusMintegralRewardedAdapter

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
    if([item.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [item.extraInfoDictionary[@"always_reward"] integerValue] == 1;
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
    self.userID = nil;
    if(self.waterfallItem.serverSideUserID != nil
       && self.waterfallItem.serverSideUserID.length > 0)
    {
        self.userID = self.waterfallItem.serverSideUserID;
    }
    self.customData = nil;
    if(self.waterfallItem.serverSideCustomData && self.waterfallItem.serverSideCustomData.length > 0)
    {
        self.customData = self.waterfallItem.serverSideCustomData;
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
    if(bidToken == nil)
    {
        [MTGRewardAdManager sharedInstance].playVideoMute = self.videoMute;
        [[MTGRewardAdManager sharedInstance] loadVideoWithPlacementId:self.placementId unitId:self.unitId delegate:self];
    }
    else
    {
        [MTGBidRewardAdManager sharedInstance].playVideoMute = self.videoMute;
        [[MTGBidRewardAdManager sharedInstance] loadVideoWithBidToken:bidToken placementId:self.placementId unitId:self.unitId delegate:self];
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
    return nil;
}

- (BOOL)isReady
{
    if(self.isBidding)
    {
        return [[MTGBidRewardAdManager sharedInstance] isVideoReadyToPlayWithPlacementId:self.placementId unitId:self.unitId];
    }
    else
    {
        return [[MTGRewardAdManager sharedInstance] isVideoReadyToPlayWithPlacementId:self.placementId unitId:self.unitId];
    }
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    if(self.isBidding)
    {
        [[MTGBidRewardAdManager sharedInstance] showVideoWithPlacementId:self.placementId unitId:self.unitId userId:self.userID userExtra:self.customData delegate:self viewController:rootViewController];
    }
    else
    {
        [[MTGRewardAdManager sharedInstance] showVideoWithPlacementId:self.placementId unitId:self.unitId userId:self.userID userExtra:self.customData delegate:self viewController:rootViewController];
    }
    MSLogTrace(@"MTGRewardAd ServerSideVerification ->userID: %@, customData:%@", self.userID, self.customData);
}

#pragma mark - MTGRewardAdLoadDelegate

- (void)onAdLoadSuccess:(nullable NSString *)placementId unitId:(nullable NSString *)unitId
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)onVideoAdLoadSuccess:(nullable NSString *)placementId unitId:(nullable NSString *)unitId
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}


- (void)onVideoAdLoadFailed:(nullable NSString *)placementId unitId:(nullable NSString *)unitId error:(nonnull NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFailWithError:error];
}

- (void)onVideoAdShowSuccess:(nullable NSString *)placementId unitId:(nullable NSString *)unitId
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)onVideoAdShowFailed:(nullable NSString *)placementId unitId:(nullable NSString *)unitId withError:(nonnull NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShowFailWithError:error];
}

- (void)onVideoAdDidClosed:(nullable NSString *)placementId unitId:(nullable NSString *)unitId
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if (self.shouldReward || self.alwaysReward)
        [self AdRewardedWithInfo:self.rewardDic];
    [self AdClose];
}

- (void)onVideoAdClicked:(nullable NSString *)placementId unitId:(nullable NSString *)unitId
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)onVideoAdDismissed:(nullable NSString *)placementId unitId:(nullable NSString *)unitId withConverted:(BOOL)converted withRewardInfo:(nullable MTGRewardAdInfo *)rewardInfo
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(converted)
    {
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
        dic[@"rewardId"] = rewardInfo.rewardId;
        dic[@"rewardName"] = rewardInfo.rewardName;
        dic[@"rewardNumber"] = @(rewardInfo.rewardAmount);
        self.rewardDic = [NSMutableDictionary dictionaryWithDictionary:dic];
        self.shouldReward = YES;
    }
}


- (void) onVideoPlayCompleted:(nullable NSString *)placementId unitId:(nullable NSString *)unitId
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}


- (void) onVideoEndCardShowSuccess:(nullable NSString *)placementId unitId:(nullable NSString *)unitId
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

@end
