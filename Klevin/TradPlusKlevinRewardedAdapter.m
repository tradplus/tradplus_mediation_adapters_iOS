#import "TradPlusKlevinRewardedAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TradPlusKlevinSDKLoader.h"
#import <KlevinAdSDK/KlevinAdSDK.h>
#import <KlevinAdSDK/KLNRewardedAd.h>
#import "TPKlevinAdapterBaseInfo.h"

@interface TradPlusKlevinRewardedAdapter ()<KLNFullScreenContentDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong)NSString *placementId;
@property (nonatomic,strong)KLNRewardedAd *rewardedAd;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;
@property (nonatomic, assign) BOOL isSkip;
@property (nonatomic, strong) NSMutableDictionary *rewardDic;
@property (nonatomic,assign)BOOL isC2SBidding;
@end

@implementation TradPlusKlevinRewardedAdapter

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
    NSString *appId = config[@"appId"];
    if(appId == nil)
    {
        MSLogTrace(@"Klevin init Config Error %@",config);
        return;
    }
    if([TradPlusKlevinSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusKlevinSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusKlevinSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_KlevinAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [KlevinAdSDK sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_KlevinAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    self.placementId = item.config[@"placementId"];
    NSString *appId = item.config[@"appId"];
    if(self.placementId == nil || appId == nil)
    {
        [self AdConfigError];
        return;
    }
    if([item.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [item.extraInfoDictionary[@"always_reward"] integerValue] == 1;
    }
    [[TradPlusKlevinSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    [[TradPlusKlevinSDKLoader sharedInstance] setPersonalizedAd];
    KLNRewardedAdRequest *req = [[KLNRewardedAdRequest alloc] initWithPosId:self.placementId];
    BOOL mute = YES;
    if(self.waterfallItem.video_mute == 2)
    {
        mute = NO;
    }
    req.autoMute = mute;
    __weak typeof(self) weakSelf = self;
    [KLNRewardedAd loadWithRequest:req completionHandler:^(KLNRewardedAd * _Nullable rewardedAd, NSError * _Nullable error) {
        if(error == nil)
        {
            weakSelf.rewardedAd = rewardedAd;
            if(self.isC2SBidding)
            {
                [self finishC2SBiddingWithEcpm:rewardedAd.eCPM];
            }
            else
            {
                [weakSelf AdLoadFinsh];
            }
        }
        else
        {
            MSLogTrace(@"%s %@", __PRETTY_FUNCTION__ ,error);
            if(self.isC2SBidding)
            {
                NSString *errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.description];
                [self failC2SBiddingWithErrorStr:errorStr];
            }
            else
            {
                [self AdLoadFailWithError:error];
            }
         }
    }];
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
        NSError *loadError = [NSError errorWithDomain:@"Klevin" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S Rewarded not ready"}];
        if(self.isC2SBidding)
        {
            NSString *errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)loadError.code, loadError.description];
            [self failC2SBiddingWithErrorStr:errorStr];
        }
        else
        {
            [self AdLoadFailWithError:loadError];
        }
    }
}

- (void)finishC2SBiddingWithEcpm:(NSInteger)ecpm
{
    NSString *version = TP_KlevinAdapter_PlatformSDK_Version;
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{@"ecpm":[NSString stringWithFormat:@"%ld", (long)ecpm],@"version":version};
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
    [self loadAd];
}

- (void)tpInitFailWithError:(NSError *)error
{
    if(self.isC2SBidding)
    {
        NSString *errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.description];
        [self failC2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        [self AdLoadFailWithError:error];
    }
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    NSError *error;
    if([self.rewardedAd canPresentFromRootViewController:rootViewController error:&error])
    {
        self.rewardedAd.fullScreenContentDelegate = self;
        __weak typeof(self) weakSelf = self;
        [self.rewardedAd presentFromRootViewController:rootViewController userDidEarnRewardHandler:^{
            [weakSelf reward];
        }];
    }
    else
    {
        MSLogTrace(@"%s %@", __PRETTY_FUNCTION__ ,error);
        [self AdShowFailWithError:error];
    }
}

- (void)reward
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    if(self.rewardedAd.adReward != nil)
    {
        dic[@"rewardName"] = self.rewardedAd.adReward.type;
        dic[@"rewardNumber"] = self.rewardedAd.adReward.amount;
    }
    self.rewardDic = [NSMutableDictionary dictionaryWithDictionary:dic];
    self.shouldReward = YES;
}

- (BOOL)isReady
{
    return (self.rewardedAd != nil);
}

- (id)getCustomObject
{
    return self.rewardedAd;
}


#pragma mark - KLNFullScreenContentDelegate
- (void)adDidRecordImpression:(nonnull id<KLNFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)adDidRecordClick:(nonnull id<KLNFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)adDidDismissFullScreenContent:(nonnull id<KLNFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
    if (self.shouldReward || (self.alwaysReward && !self.isSkip))
        [self AdRewardedWithInfo:self.rewardDic];
    [self AdClose];
}

- (void)ad:(nonnull id<KLNFullScreenPresentingAd>)ad
    didFailToPresentFullScreenContentWithError:(nonnull NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdShowFailWithError:error];
}

- (void)adDidRecordSkip:(nonnull id<KLNFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.isSkip = YES;
}

- (void)adDidPresentFullScreenContent:(nonnull id<KLNFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

@end
