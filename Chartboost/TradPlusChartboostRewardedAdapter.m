#import "TradPlusChartboostRewardedAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <ChartboostSDK/Chartboost.h>
#import "TradPlusChartboostSDKLoader.h"
#import "TPChartboostAdapterBaseInfo.h"

@interface TradPlusChartboostRewardedAdapter ()<CHBRewardedDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong)CHBRewarded *rewarded;
@property (nonatomic,copy)NSString *placementId;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;
@property (nonatomic, strong) NSMutableDictionary *rewardDic;
@end

@implementation TradPlusChartboostRewardedAdapter

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
    NSString *appSignature = config[@"appSign"];
    if(appId == nil || appSignature == nil)
    {
        MSLogTrace(@"Chartboost init Config Error %@",config);
        return;
    }
    if([TradPlusChartboostSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusChartboostSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusChartboostSDKLoader sharedInstance] initWithAppId:appId appSignature:appSignature delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_ChartboostAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [Chartboost getSDKVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_ChartboostAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    self.placementId = item.config[@"placementId"];
    NSString *appId = item.config[@"appId"];
    NSString *appSignature = item.config[@"appSign"];
    if(self.placementId == nil || appId == nil || appSignature == nil)
    {
        [self AdConfigError];
        return;
    }
    if([item.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [item.extraInfoDictionary[@"always_reward"] integerValue] == 1;
    }
    [[TradPlusChartboostSDKLoader sharedInstance] initWithAppId:appId appSignature:appSignature delegate:self];
}

- (void)loadAd
{
    self.rewarded = [[CHBRewarded alloc] initWithLocation:self.placementId delegate:self];
    [self.rewarded cache];
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
    return (self.rewarded != nil && self.rewarded.isCached);
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.rewarded showFromViewController:rootViewController];
}

#pragma mark - CHBRewardedDelegate
- (void)didCacheAd:(CHBCacheEvent *)event error:(nullable CHBCacheError *)error;
{
    MSLogTrace(@"%s->%@", __PRETTY_FUNCTION__, error);
    if(error == nil)
    {
        [self AdLoadFinsh];
    }
    else
    {
        NSError *loadError = [NSError errorWithDomain:@"Chartboost" code:error.code userInfo:@{NSLocalizedDescriptionKey:@"load fail"}];
        [self AdLoadFailWithError:loadError];
    }
}

- (void)didShowAd:(CHBShowEvent *)event error:(nullable CHBShowError *)error
{
    MSLogTrace(@"%s->%@", __PRETTY_FUNCTION__, error);
    if (error == nil)
    {
        [self AdShow];
        [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
    }
    else
    {
        NSError *showError = [NSError errorWithDomain:@"Chartboost" code:error.code userInfo:@{NSLocalizedDescriptionKey:@"show fail"}];
        [self AdShowFailWithError:showError];
    }
}

- (void)didClickAd:(CHBClickEvent *)event error:(nullable CHBClickError *)error
{
    MSLogTrace(@"%s->%@", __PRETTY_FUNCTION__, error);
    [self AdClick];
}

- (void)didDismissAd:(CHBDismissEvent *)event
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
    if (self.shouldReward || self.alwaysReward)
        [self AdRewardedWithInfo:self.rewardDic];
    [self AdClose];
}

- (void)didEarnReward:(CHBRewardEvent *)event
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.rewardDic = [NSMutableDictionary dictionary];
    self.rewardDic[@"rewardAmount"] = @(event.reward);
    self.shouldReward = YES;
}

@end
