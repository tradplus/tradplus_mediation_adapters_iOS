#import "TradPlusInMobiInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <InMobiSDK/InMobiSDK.h>
#import "TradPlusInMobiSDKLoader.h"
#import "TPInMobiAdapterBaseInfo.h"

@interface TradPlusInMobiInterstitialAdapter ()<IMInterstitialDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) IMInterstitial *interstitial;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, assign) BOOL isC2SBidding;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;
@property (nonatomic, strong) NSMutableDictionary *rewardDic;
@end

@implementation TradPlusInMobiInterstitialAdapter

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
    else
    {
        return NO;
    }
    return YES;
}

- (void)initSDKWithInfo:(NSDictionary *)config
{
    NSString *account_id = config[@"account_id"];
    if(account_id == nil || [account_id isKindOfClass:[NSNull class]])
    {
        MSLogTrace(@"InMobi init Config Error %@",config);
        return;
    }
    if([TradPlusInMobiSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusInMobiSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusInMobiSDKLoader sharedInstance] initWithAccountID:account_id delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_InMobiAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [IMSdk getVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_InMobiAdapter_PlatformSDK_Version
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
    NSString *account_id = item.config[@"account_id"];
    self.placementId = item.config[@"placementId"];
    if(account_id == nil || [account_id isKindOfClass:[NSNull class]] || self.placementId == nil)
    {
        MSLogTrace(@"InMobi init Config Error %@",item.config);
        [self AdConfigError];
        return;
    }
    if([item.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [item.extraInfoDictionary[@"always_reward"] integerValue] == 1;
    }
    if([TradPlusInMobiSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusInMobiSDKLoader sharedInstance].initSource = initSource;
    }
    [[TradPlusInMobiSDKLoader sharedInstance] initWithAccountID:account_id delegate:self];
}

- (void)loadAd
{
    self.interstitial = [[IMInterstitial alloc] initWithPlacementId:[self.placementId longLongValue]];
    self.interstitial.delegate = self;
    self.interstitial.extras = [[TradPlusInMobiSDKLoader sharedInstance] getExtras];
    [self.interstitial load];
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.interstitial showFromViewController:rootViewController];
}

- (BOOL)isReady
{
    return (self.interstitial != nil && self.interstitial.isReady);
}

- (id)getCustomObject
{
    return self.interstitial;
}

#pragma mark - C2SBidding

- (void)initSDKC2SBidding
{
    self.isC2SBidding = YES;
    [self initSDKWithWaterfallItem:self.waterfallItem initSource:2];
}

- (void)startC2SBidding
{
    self.interstitial = [[IMInterstitial alloc] initWithPlacementId:[self.placementId longLongValue]];
    self.interstitial.delegate = self;
    self.interstitial.extras = [[TradPlusInMobiSDKLoader sharedInstance] getExtras];
    [self.interstitial.preloadManager preload];
}

- (void)loadAdC2SBidding
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self.interstitial.preloadManager load];
}

- (void)finishC2SBiddingWithMetaInfo:(IMAdMetaInfo*)info
{
    NSString *version = [IMSdk getVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSString *ecpmStr = [NSString stringWithFormat:@"%f",info.getBid];
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
    if(self.isC2SBidding)
    {
        [self startC2SBidding];
    }
    else
    {
        [self loadAd];
    }
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

#pragma mark - IMInterstitialDelegate
-(void)interstitialAdImpressed:(IMInterstitial*)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

-(void)interstitial:(IMInterstitial*)interstitial didReceiveWithMetaInfo:(IMAdMetaInfo*)metaInfo
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self finishC2SBiddingWithMetaInfo:metaInfo];
}

-(void)interstitial:(IMInterstitial*)interstitial didFailToReceiveWithError:(NSError*)error
{
    MSLogTrace(@"%s error %@", __PRETTY_FUNCTION__,error);
    NSString *errorStr = @"C2S Bidding Fail";
    if(error != nil)
    {
        errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.localizedDescription];
    }
    [self failC2SBiddingWithErrorStr:errorStr];
}

-(void)interstitialDidFinishLoading:(IMInterstitial*)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

-(void)interstitial:(IMInterstitial*)interstitial didFailToLoadWithError:(IMRequestStatus *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

-(void)interstitialDidPresent:(IMInterstitial*)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

-(void)interstitialDidDismiss:(IMInterstitial*)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if (self.shouldReward || self.alwaysReward)
        [self AdRewardedWithInfo:self.rewardDic];
    [self AdClose];
}


-(void)interstitial:(IMInterstitial*)interstitial didFailToPresentWithError:(IMRequestStatus*)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdShowFailWithError:error];
}

-(void)interstitial:(IMInterstitial*)interstitial didInteractWithParams:(NSDictionary*)params
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

-(void)interstitial:(IMInterstitial*)interstitial rewardActionCompletedWithRewards:(NSDictionary*)rewards
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__ ,rewards);
    self.rewardDic = [NSMutableDictionary dictionaryWithDictionary:rewards];
    self.shouldReward = YES;
}

-(void)interstitial:(IMInterstitial*)interstitial gotSignals:(NSData*)signals
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

-(void)interstitial:(IMInterstitial*)interstitial failedToGetSignalsWithError:(IMRequestStatus*)status
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

-(void)interstitialWillPresent:(IMInterstitial*)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

-(void)interstitialWillDismiss:(IMInterstitial*)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

-(void)userWillLeaveApplicationFromInterstitial:(IMInterstitial*)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
@end
