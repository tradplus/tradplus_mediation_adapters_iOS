#import "TradPlusVerveRewardedAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <HyBid/HyBid.h>
#import "TradPlusVerveSDKLoader.h"
#import "TPVerveAdapterBaseInfo.h"

@interface TradPlusVerveRewardedAdapter ()<HyBidRewardedAdDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong) HyBidRewardedAd *rewarded;
@property (nonatomic,copy) NSString *placementId;
@property (nonatomic,assign) BOOL isC2SBidding;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;
@end

@implementation TradPlusVerveRewardedAdapter

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
    else if([event isEqualToString:@"C2SBidding"])
    {
        [self initSDKC2SBidding];
    }
    else if([event isEqualToString:@"LoadAdC2SBidding"])
    {
        [self loadAdC2SBidding];
    }
    else if([event isEqualToString:@"SetTestMode"])
    {
        [[TradPlusVerveSDKLoader sharedInstance] setTestMode];
    }
    else
    {
        return NO;
    }
    return YES;
}

- (void)initSDKWithInfo:(NSDictionary *)config
{
    NSString *appId = config[@"appToken"];
    if(appId == nil  ||  appId.length <= 5)
    {
        MSLogTrace(@"Verve init Config Error %@",config);
        return;
    }
    if([TradPlusVerveSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusVerveSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusVerveSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_VerveAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [HyBid sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_VerveAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

#pragma mark - load

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    [self initSDKWithWaterfallItem:item initSource:3];
}

- (void)initSDKWithWaterfallItem:(TradPlusAdWaterfallItem *)item initSource:(NSInteger)initSource
{
    NSString *appId = item.config[@"appToken"];
    self.placementId = item.config[@"placementId"];
    if(appId == nil  || self.placementId == nil || appId.length <= 5)
    {
        MSLogTrace(@"Verve init Config Error %@",item.config);
        [self AdConfigError];
        return;
    }
    if([item.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [item.extraInfoDictionary[@"always_reward"] integerValue] == 1;
    }
    if([TradPlusVerveSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusVerveSDKLoader sharedInstance].initSource = initSource;
    }
    [[TradPlusVerveSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAdWithPlacementId:(NSString *)placementId
{
    self.rewarded = [[HyBidRewardedAd alloc] initWithZoneID:placementId andWithDelegate:self];
    self.rewarded.isMediation = YES;
    [self.rewarded load];
}

- (id)getCustomObject
{
    return self.rewarded;
}

- (BOOL)isReady
{
    return self.rewarded.isReady;
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.rewarded showFromViewController:rootViewController];
}

#pragma mark - C2SBidding

- (void)initSDKC2SBidding
{
    self.isC2SBidding = YES;
    [self initSDKWithWaterfallItem:self.waterfallItem initSource:2];
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
        NSError *loadError = [NSError errorWithDomain:@"verve.reward" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S Rewarded not ready"}];
        [self AdLoadFailWithError:loadError];
    }
}

- (void)finishC2SBiddingWithAd:(HyBidAd *)ad
{
    NSString *version = [HyBid sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSString *ecpmStr = [NSString stringWithFormat:@"%@",ad.eCPM];
    NSDictionary *dic = @{@"ecpm":ecpmStr,@"version":version};
    [self ADLoadExtraCallbackWithEvent:@"C2SBiddingFinish" info:dic];
}

- (void)failC2SBiddingWithErrorStr:(NSString *)errorStr
{
    NSDictionary *dic = @{@"error":errorStr};
    [self ADLoadExtraCallbackWithEvent:@"C2SBiddingFail" info:dic];
}

#pragma mark - TPSDKLoaderDelegate

- (void)tpInitFinish
{
    [self loadAdWithPlacementId:self.placementId];
}

- (void)tpInitFailWithError:(NSError *)error
{
    if(self.isC2SBidding)
    {
        NSString *errorStr = @"C2S Init Fail";
        if(error != nil)
        {
            errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.localizedDescription];
        }
        [self failC2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        [self AdLoadFailWithError:error];
    }
}

#pragma mark - MAAdDelegate

- (void)rewardedDidLoad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.isC2SBidding)
    {
        [self finishC2SBiddingWithAd:self.rewarded.ad];
    }
    else
    {
        [self AdLoadFinsh];
    }
}

- (void)rewardedDidFailWithError:(NSError *)error
{
    MSLogTrace(@"%s error: %@", __PRETTY_FUNCTION__,error);
    if(self.isC2SBidding)
    {
        NSString *errorStr = @"C2S Bidding Fail";
        if(error != nil)
        {
            errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.description];
        }
        [self failC2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        [self AdLoadFailWithError:error];
    }
}

- (void)rewardedDidTrackImpression
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)rewardedDidDismiss
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
    if (self.shouldReward || self.alwaysReward)
        [self AdRewardedWithInfo:nil];
    [self AdClose];
}

- (void)rewardedDidTrackClick
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)onReward
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.shouldReward = YES;
}


@end
