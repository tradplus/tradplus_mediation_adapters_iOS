#import "TradPlusSigmobRewardedAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TradPlusSigmobSDKLoader.h"
#import <WindSDK/WindSDK.h>
#import "TPSigmobAdapterBaseInfo.h"

@interface TradPlusSigmobRewardedAdapter ()<WindRewardVideoAdDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) WindRewardVideoAd *rewardVideoAd;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;
@property (nonatomic, assign) BOOL isSkip;
@end

@implementation TradPlusSigmobRewardedAdapter

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
        MSLogTrace(@"Sigmob init Config Error %@",config);
        return;
    }
    if([TradPlusSigmobSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusSigmobSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusSigmobSDKLoader sharedInstance] initWithAppID:appId appKey:appKey delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_SigmobAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [WindAds sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_SigmobAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}


- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *appId = item.config[@"appId"];
    NSString *appKey = item.config[@"AppKey"];
    self.placementId = item.config[@"placementId"];
    if(appId == nil || appKey == nil || self.placementId == nil)
    {
        [self AdConfigError];
        return;
    }
    if([item.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [item.extraInfoDictionary[@"always_reward"] integerValue] == 1;
    }
    [[TradPlusSigmobSDKLoader sharedInstance] initWithAppID:appId appKey:appKey delegate:self];
}

- (void)loadAd
{
    [[TradPlusSigmobSDKLoader sharedInstance] setPersonalizedAd];
    WindAdRequest *request = [WindAdRequest request];
    request.placementId = self.placementId;
    if(self.waterfallItem.serverSideUserID != nil
       && self.waterfallItem.serverSideUserID.length > 0)
    {
        request.userId = self.waterfallItem.serverSideUserID;
        MSLogTrace(@"SigmobRouter ServerSideVerification ->userID: %@", self.waterfallItem.serverSideUserID);
    }
    
    NSString *bidToken = nil;
    if(self.waterfallItem.adsourceplacement != nil)
    {
        bidToken = self.waterfallItem.adsourceplacement.adm;
    }
    
    self.rewardVideoAd = [[WindRewardVideoAd alloc] initWithRequest:request];
    self.rewardVideoAd.delegate = self;
    if(bidToken == nil)
    {
        [self.rewardVideoAd loadAdData];
    }
    else
    {
        [self.rewardVideoAd loadAdDataWithBidToken:bidToken];
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
    return self.rewardVideoAd;
}

- (BOOL)isReady
{
    return (self.rewardVideoAd != nil
                && self.rewardVideoAd.ready);
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.rewardVideoAd showAdFromRootViewController:rootViewController options:nil];
}

#pragma mark - WindRewardVideoAdDelegate

- (void)rewardVideoAdDidLoad:(WindRewardVideoAd *)rewardVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}


- (void)rewardVideoAdDidLoad:(WindRewardVideoAd *)rewardVideoAd didFailWithError:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFailWithError:error];
}


- (void)rewardVideoAdDidVisible:(WindRewardVideoAd *)rewardVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}


- (void)rewardVideoAdDidClick:(WindRewardVideoAd *)rewardVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)rewardVideoAdDidPlayFinish:(WindRewardVideoAd *)rewardVideoAd didFailWithError:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(error != nil)
    {
        [self AdShowFailWithError:error];
    }
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}

- (void)rewardVideoAdDidClose:(WindRewardVideoAd *)rewardVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if (self.shouldReward || (self.alwaysReward && !self.isSkip))
        [self AdRewardedWithInfo:nil];
   [self AdClose];
}

- (void)rewardVideoAdDidClickSkip:(WindRewardVideoAd *)rewardVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.isSkip = YES;
}

- (void)rewardVideoAdWillVisible:(WindRewardVideoAd *)rewardVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardVideoAdServerResponse:(WindRewardVideoAd *)rewardVideoAd isFillAd:(BOOL)isFillAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardVideoAd:(WindRewardVideoAd *)rewardVideoAd reward:(WindRewardInfo *)reward {
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(reward.isCompeltedView)
    {
        self.shouldReward = YES;
    }
}

@end
