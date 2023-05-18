#import "TradPlusBigoRewardedAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <BigoADS/BigoRewardVideoAdLoader.h>
#import "TradPlusBigoSDKLoader.h"
#import "TPBigoAdapterBaseInfo.h"
#import <BigoADS/BigoAdSdk.h>

@interface TradPlusBigoRewardedAdapter ()<BigoRewardVideoAdLoaderDelegate, BigoRewardVideoAdInteractionDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) BigoRewardVideoAd *rewardVideoAd;
@property (nonatomic, strong) BigoAdLoader *adLoader;
@property (nonatomic, copy) NSString *slotId;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;
@property (nonatomic, assign) BOOL isS2SBidding;
@end

@implementation TradPlusBigoRewardedAdapter

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
    else if([event isEqualToString:@"S2SBidding"])
    {
        [self initSDKS2SBidding];
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
    if(appId == nil  ||  appId.length <= 5)
    {
        MSLogTrace(@"Bigo init Config Error %@",config);
        return;
    }
    if([TradPlusBigoSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusBigoSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusBigoSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_BigoAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [[BigoAdSdk sharedInstance] getSDKVersionName];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_BigoAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

#pragma mark - S2SBidding
- (void)initSDKS2SBidding
{
    self.isS2SBidding = YES;
    [self initSDKWithWaterfallItem:self.waterfallItem initSource:2];
}

- (void)getBiddingToken
{
    NSString *token = [[BigoAdSdk sharedInstance] getBidderToken];
    if(token == nil)
    {
        token = @"";
    }
    NSString *version = [[BigoAdSdk sharedInstance] getSDKVersionName];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{@"token":token,@"version":version};
    [self ADLoadExtraCallbackWithEvent:@"S2SBiddingFinish" info:dic];
}

- (void)failS2SBiddingWithErrorStr:(NSString *)errorStr
{
    NSDictionary *dic = @{@"error":errorStr};
    [self ADLoadExtraCallbackWithEvent:@"S2SBiddingFail" info:dic];
}

- (void)initSDKWithWaterfallItem:(TradPlusAdWaterfallItem *)item initSource:(NSInteger)initSource
{
    NSString *appId = item.config[@"appId"];
    self.slotId = item.config[@"placementId"];
    if(appId == nil || self.slotId == nil || appId.length <= 5)
    {
        MSLogTrace(@"Bigo init Config Error %@",item.config);
        [self AdConfigError];
        return;
    }
    if([TradPlusBigoSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusBigoSDKLoader sharedInstance].initSource = initSource;
    }
    [[TradPlusBigoSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    [self initSDKWithWaterfallItem:item initSource:3];
}

- (void)loadAd
{
    if([self.waterfallItem.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [self.waterfallItem.extraInfoDictionary[@"always_reward"] integerValue] == 1;
    }
    self.adLoader = [[BigoRewardVideoAdLoader alloc] initWithRewardVideoAdLoaderDelegate:self];
    BigoRewardVideoAdRequest *request = [[BigoRewardVideoAdRequest alloc] initWithSlotId:self.slotId];
    NSString *bidToken = nil;
    if(self.waterfallItem.adsourceplacement != nil)
    {
        bidToken = self.waterfallItem.adsourceplacement.adm;
    }
    if(bidToken != nil)
    {
        [request setServerBidPayload:bidToken];
    }
    [self.adLoader loadAd:request];
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.rewardVideoAd show:rootViewController];
}


#pragma mark - TPSDKLoaderDelegate

- (void)tpInitFinish
{
    if(self.isS2SBidding)
    {
        [self getBiddingToken];
    }
    else
    {
        [self loadAd];
    }
}

- (void)tpInitFailWithError:(NSError *)error
{
    if(self.isS2SBidding)
    {
        NSString *errorStr = @"S2S Init Fail";
        if(error != nil)
        {
            errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.localizedDescription];
        }
        [self failS2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        [self AdLoadFailWithError:error];
    }
}
 
- (BOOL)isReady
{
    return !self.rewardVideoAd.isExpired;
}

- (id)getCustomObject
{
    return self.rewardVideoAd;
}

#pragma mark - BigoRewardVideoAdInteractionDelegate
- (void)onAdRewarded:(BigoRewardVideoAd *)ad{
    self.shouldReward = YES;
}

#pragma mark - BigoRewardVideoAdLoaderDelegate
- (void)onRewardVideoAdLoaded:(BigoRewardVideoAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    
    [ad setRewardVideoAdInteractionDelegate:self];
    self.rewardVideoAd = ad;
    
    [self AdLoadFinsh];
}

- (void)onRewardVideoAdLoadError:(BigoAdError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    NSInteger errorCode = 403;
    NSString *errorMsg = @"Load Fail";
    if(error != nil)
    {
        errorCode = error.errorCode;
        errorMsg = error.errorMsg;
    }
    NSError *loadError = [NSError errorWithDomain:@"Bigo.reward" code:errorCode userInfo:@{NSLocalizedDescriptionKey:errorMsg}];
    [self AdLoadFailWithError:loadError];
}

#pragma mark - BigoAdInteractionDelegate
- (void)onAd:(BigoAd *)ad error:(BigoAdError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    NSInteger errorCode = 403;
    NSString *errorMsg = @"Show Fail";
    if(error != nil)
    {
        errorCode = error.errorCode;
        errorMsg = error.errorMsg;
    }
    NSError *showError = [NSError errorWithDomain:@"Bigo.reward" code:errorCode userInfo:@{NSLocalizedDescriptionKey:errorMsg}];
    [self AdShowFailWithError:showError];
}

- (void)onAdImpression:(BigoAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)onAdClicked:(BigoAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)onAdOpened:(BigoAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)onAdClosed:(BigoAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
    if (self.shouldReward || self.alwaysReward)
        [self AdRewardedWithInfo:nil];
    [self AdClose];
}

@end
