#import "TradPlusPangleRewardedAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <PAGAdSDK/PAGSdk.h>
#import <PAGAdSDK/PAGRewardedAd.h>
#import <PAGAdSDK/PAGRewardModel.h>
#import "TradPlusPangleSDKLoader.h"
#import "TPPangleAdapterBaseInfo.h"

@interface TradPlusPangleRewardedAdapter ()<TPSDKLoaderDelegate,PAGRewardedAdDelegate>

@property (nonatomic,strong)PAGRewardedAd *rewardedAd;
@property (nonatomic,copy)NSString *appId;
@property (nonatomic,copy)NSString *placementId;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;
@property (nonatomic, assign) BOOL isS2SBidding;
@property (nonatomic,strong)NSMutableDictionary *rewardDic;
@end

@implementation TradPlusPangleRewardedAdapter

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
    if(appId == nil)
    {
        MSLogTrace(@"Pangle init Config Error %@",config);
        return;
    }
    if([TradPlusPangleSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusPangleSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusPangleSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_PangleAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [TradPlusPangleSDKLoader getSDKVersion];
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_PangleAdapter_PlatformSDK_Version
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
    NSString *token = [PAGSdk getBiddingToken:self.appId];
    if(token == nil)
    {
        token = @"";
    }
    NSString *version = [TradPlusPangleSDKLoader getCurrentVersion];
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


#pragma mark - 普通

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    [self initSDKWithWaterfallItem:item initSource:3];
}

- (void)initSDKWithWaterfallItem:(TradPlusAdWaterfallItem *)item initSource:(NSInteger)initSource
{
    self.appId = item.config[@"appId"];
    self.placementId = item.config[@"placementId"];
    if(self.placementId == nil || self.appId == nil)
    {
        [self AdConfigError];
        return;
    }
    if([item.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [item.extraInfoDictionary[@"always_reward"] integerValue] == 1;
    }
    if([TradPlusPangleSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusPangleSDKLoader sharedInstance].initSource = initSource;
    }
    [[TradPlusPangleSDKLoader sharedInstance] initWithAppID:self.appId delegate:self];
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

- (void)loadAd
{
    PAGRewardedRequest *request = [PAGRewardedRequest request];
    NSString *bidToken = nil;
    if(self.waterfallItem.adsourceplacement != nil)
    {
        bidToken = self.waterfallItem.adsourceplacement.adm;
    }
    if(bidToken != nil)
    {
        request.adString = bidToken;
    }
    NSString *mediaExtra = nil;
    if(self.waterfallItem.serverSideUserID != nil
       && self.waterfallItem.serverSideUserID.length > 0)
    {
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
        NSString *userID = self.waterfallItem.serverSideUserID;
        dic[@"user_id"] = userID;
        if(self.waterfallItem.serverSideCustomData != nil
           && self.waterfallItem.serverSideCustomData.length > 0)
        {
            dic[@"custom_data"] = self.waterfallItem.serverSideCustomData;
        }
        NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
        mediaExtra = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        MSLogTrace(@"Pangle mediaExtra : %@", mediaExtra);
    }
    if(mediaExtra != nil)
    {
        request.extraInfo = @{@"media_extra":mediaExtra};
    }
    __weak typeof(self) weakSelf = self;
    [PAGRewardedAd loadAdWithSlotID:self.placementId request:request completionHandler:^(PAGRewardedAd * _Nullable rewardedAd, NSError * _Nullable error) {
        if (error) {
            MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
            [weakSelf AdLoadFailWithError:error];
            return;
        }
        weakSelf.rewardedAd = rewardedAd;
        weakSelf.rewardedAd.delegate = weakSelf;
        [weakSelf AdLoadFinsh];
    }];
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.rewardedAd presentFromRootViewController:rootViewController];
}

- (BOOL)isReady
{
    return (self.rewardedAd != nil);
}

- (id)getCustomObject
{
    return self.rewardedAd;
}

#pragma mark - PAGRewardedAdDelegate

- (void)adDidShow:(PAGRewardedAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)adDidClick:(PAGRewardedAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)adDidDismiss:(PAGRewardedAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if (self.shouldReward || self.alwaysReward){
        [self AdRewardedWithInfo:self.rewardDic];
    }
    [self AdClose];
}

- (void)rewardedAd:(PAGRewardedAd *)rewardedAd userDidEarnReward:(PAGRewardModel *)rewardModel
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.shouldReward = YES;
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    dic[@"rewardName"] = rewardModel.rewardName;
    dic[@"rewardNumber"] = @(rewardModel.rewardAmount);
    self.rewardDic = [NSMutableDictionary dictionaryWithDictionary:dic];
}

- (void)rewardedAd:(PAGRewardedAd *)rewardedAd userEarnRewardFailWithError:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    self.shouldReward = NO;
}
@end
