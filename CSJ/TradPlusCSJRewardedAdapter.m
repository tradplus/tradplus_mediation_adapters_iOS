#import "TradPlusCSJRewardedAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <BUAdSDK/BUAdSDK.h>
#import "TradPlusCSJSDKLoader.h"
#import "TradPlusCSJRewardedPlayAgain.h"
#import "TradPlusCSJExpressRewardedPlayAgain.h"
#import "TPCSJAdapterBaseInfo.h"

@interface TradPlusCSJRewardedAdapter ()<BUNativeExpressRewardedVideoAdDelegate,BURewardedVideoAdDelegate,TPSDKLoaderDelegate>

@property (nonatomic,assign)BOOL isTemplateRender;
@property (nonatomic,strong)BUNativeExpressRewardedVideoAd *expressRewardedVideoAd;
@property (nonatomic,strong)BURewardedVideoAd *rewardedVideoAd;
@property (nonatomic,strong)TradPlusCSJRewardedPlayAgain *rewardedPlayAgainObj;
@property (nonatomic,strong)TradPlusCSJExpressRewardedPlayAgain *expressRewardedPlayAgainObj;
@property (nonatomic,copy)NSString *appId;
@property (nonatomic,copy)NSString *placementId;
@property (nonatomic,assign) NSInteger ecpm;
@property (nonatomic,assign) BOOL shouldReward;
@property (nonatomic,assign) BOOL alwaysReward;
@property (nonatomic,assign) BOOL isSkip;
@property (nonatomic,assign) BOOL isC2SBidding;
@property (nonatomic,assign) BOOL didWin;
@end

@implementation TradPlusCSJRewardedAdapter

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
    else if([event isEqualToString:@"C2SLoss"])
    {
        [self sendC2SLoss:config];
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
        MSLogTrace(@"CSJ init Config Error %@",config);
        return;
    }
    if([TradPlusCSJSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusCSJSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusCSJSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_CSJAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [TradPlusCSJSDKLoader getSDKVersion];
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_CSJAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
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
    if([TradPlusCSJSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusCSJSDKLoader sharedInstance].initSource = initSource;
    }
    [[TradPlusCSJSDKLoader sharedInstance] setAllowModifyAudioSessionSettingWithExtraInfo:self.waterfallItem.extraInfoDictionary];
    [[TradPlusCSJSDKLoader sharedInstance] initWithAppID:self.appId delegate:self];
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

- (void)loadAd
{
    [[TradPlusCSJSDKLoader sharedInstance] setPersonalizedAd];
    BURewardedVideoModel *model = [[BURewardedVideoModel alloc] init];
    if(self.waterfallItem.serverSideUserID != nil
       && self.waterfallItem.serverSideUserID.length > 0)
    {
        NSString *userID = self.waterfallItem.serverSideUserID;
        model.userId = userID;
        MSLogTrace(@"CSJ ServerSideVerification setUserId ->userID: %@", userID);
    }
    else{
        model.userId = self.appId;
    }
    if(self.waterfallItem.serverSideCustomData != nil
       && self.waterfallItem.serverSideCustomData.length > 0)
    {
        model.extra = self.waterfallItem.serverSideCustomData;
    }
    self.isTemplateRender = YES;
    if(self.waterfallItem.is_template_rendering == 2)
    {
        self.isTemplateRender = NO;
    }
    if(self.isTemplateRender)
    {
        self.expressRewardedVideoAd = [[BUNativeExpressRewardedVideoAd alloc] initWithSlotID:self.placementId rewardedVideoModel:model];
        self.expressRewardedVideoAd.delegate = self;
        self.expressRewardedPlayAgainObj = [[TradPlusCSJExpressRewardedPlayAgain alloc] init];
        self.expressRewardedPlayAgainObj.rewardedAdapter = self;
        self.expressRewardedVideoAd.rewardPlayAgainInteractionDelegate = self.expressRewardedPlayAgainObj;
        [self.expressRewardedVideoAd loadAdData];
    }
    else
    {
        self.rewardedVideoAd = [[BURewardedVideoAd alloc] initWithSlotID:self.placementId rewardedVideoModel:model];
        self.rewardedVideoAd.delegate = self;
        self.rewardedPlayAgainObj = [[TradPlusCSJRewardedPlayAgain alloc] init];
        self.rewardedPlayAgainObj.rewardedAdapter = self;
        self.rewardedVideoAd.rewardPlayAgainInteractionDelegate = self.rewardedPlayAgainObj;
        [self.rewardedVideoAd loadAdData];
    }
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    if(self.isTemplateRender)
    {
        [self.expressRewardedVideoAd showAdFromRootViewController:rootViewController];
    }
    else
    {
        [self.rewardedVideoAd showAdFromRootViewController:rootViewController];
    }
    
}

- (BOOL)isReady
{
    return self.isAdReady;
}

- (id)getCustomObject
{
    if(self.isTemplateRender)
    {
        return self.expressRewardedVideoAd;
    }
    else
    {
        return self.rewardedVideoAd;
    }
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
        [self sendC2SWin];
        [self AdLoadFinsh];
    }
    else
    {
        NSError *loadError = [NSError errorWithDomain:@"CSJ.rewarded" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S Rewarded not ready"}];
        [self AdLoadFailWithError:loadError];
    }
}

- (void)finishC2SBidding
{
    NSString *version = [TradPlusCSJSDKLoader getSDKVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSString *ecpm = [NSString stringWithFormat:@"%@",@(self.ecpm)];
    NSDictionary *dic = @{@"ecpm":ecpm,@"version":version};
    [self ADLoadExtraCallbackWithEvent:@"C2SBiddingFinish" info:dic];
}

- (void)failC2SBiddingWithErrorStr:(NSString *)errorStr
{
    NSDictionary *dic = @{@"error":errorStr};
    [self ADLoadExtraCallbackWithEvent:@"C2SBiddingFail" info:dic];
}

- (void)sendC2SWin
{
    if(!self.isC2SBidding)
    {
        return;
    }
    self.didWin = YES;
    if(self.isTemplateRender)
    {
        [self.expressRewardedVideoAd win:@(self.ecpm)];
    }
    else
    {
        [self.rewardedVideoAd win:@(self.ecpm)];
    }
}

- (void)sendC2SLoss:(NSDictionary *)config
{
    if(self.didWin)
    {
        return;
    }
    NSString *topPirce = config[@"topPirce"];
    if(self.isTemplateRender)
    {
        [self.expressRewardedVideoAd loss:@([topPirce integerValue]) lossReason:@"102" winBidder:nil];
    }
    else
    {
        [self.rewardedVideoAd loss:@([topPirce integerValue]) lossReason:@"102" winBidder:nil];
    }
}

#pragma mark - BUNativeExpressRewardedVideoAdDelegate

- (void)nativeExpressRewardedVideoAdDidLoad:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeExpressRewardedVideoAd:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *_Nullable)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
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

- (void)nativeExpressRewardedVideoAdCallback:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd withType:(BUNativeExpressRewardedVideoAdType)nativeExpressVideoType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeExpressRewardedVideoAdDidDownLoadVideo:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.isAdReady = YES;
    if(self.isC2SBidding)
    {
        if(![rewardedVideoAd.mediaExt valueForKey:@"price"])
        {
            NSString *errorStr = @"C2S Bidding Fail.[竞价失败，请确认是否已开启穿山甲竞价功能]";
            MSLogInfo(@"%@", errorStr);
            [self failC2SBiddingWithErrorStr:errorStr];
            return;
        }
        self.ecpm = [[rewardedVideoAd.mediaExt valueForKey:@"price"] integerValue];
        [self finishC2SBidding];
    }
    else
    {
        [self AdLoadFinsh];
    }
}


- (void)nativeExpressRewardedVideoAdViewRenderSuccess:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)nativeExpressRewardedVideoAdViewRenderFail:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd error:(NSError *_Nullable)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdShowFailWithError:error];
}


- (void)nativeExpressRewardedVideoAdWillVisible:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)nativeExpressRewardedVideoAdDidVisible:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}


- (void)nativeExpressRewardedVideoAdWillClose:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)nativeExpressRewardedVideoAdDidClose:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if (self.shouldReward || (self.alwaysReward && !self.isSkip))
    {
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        dic[@"rewardType"] = @(rewardedVideoAd.rewardedVideoModel.rewardType);
        dic[@"rewardPropose"] = @(rewardedVideoAd.rewardedVideoModel.rewardPropose);
        dic[@"rewardName"] = rewardedVideoAd.rewardedVideoModel.rewardName;
        dic[@"rewardAmount"] = @(rewardedVideoAd.rewardedVideoModel.rewardAmount);
        [self AdRewardedWithInfo:dic];
    }
    [self AdClose];
}

- (void)nativeExpressRewardedVideoAdDidClick:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)nativeExpressRewardedVideoAdDidClickSkip:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.isSkip = YES;
}


- (void)nativeExpressRewardedVideoAdDidPlayFinish:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *_Nullable)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(error != nil)
    {
        [self AdShowFailWithError:error];
    }
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}


- (void)nativeExpressRewardedVideoAdServerRewardDidSucceed:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd verify:(BOOL)verify
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.shouldReward = YES;
}


- (void)nativeExpressRewardedVideoAdServerRewardDidFail:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd error:(NSError *_Nullable)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeExpressRewardedVideoAdDidCloseOtherController:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd interactionType:(BUInteractionType)interactionType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

#pragma mark - BURewardedVideoAdDelegate

- (void)rewardedVideoAdDidLoad:(BURewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)rewardedVideoAd:(BURewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *_Nullable)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
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


- (void)rewardedVideoAdVideoDidLoad:(BURewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.isAdReady = YES;
    if(self.isC2SBidding)
    {
        if(![rewardedVideoAd.mediaExt valueForKey:@"price"])
        {
            NSString *errorStr = @"C2S Bidding Fail.[竞价失败，请确认是否已开启穿山甲竞价功能]";
            MSLogInfo(@"%@", errorStr);
            [self failC2SBiddingWithErrorStr:errorStr];
            return;
        }
        self.ecpm = [[rewardedVideoAd.mediaExt valueForKey:@"price"] integerValue];
        [self finishC2SBidding];
    }
    else
    {
        [self AdLoadFinsh];
    }
}


- (void)rewardedVideoAdWillVisible:(BURewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)rewardedVideoAdDidVisible:(BURewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)rewardedVideoAdWillClose:(BURewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)rewardedVideoAdDidClose:(BURewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if (self.shouldReward || (self.alwaysReward && !self.isSkip))
    {
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        dic[@"rewardType"] = @(rewardedVideoAd.rewardedVideoModel.rewardType);
        dic[@"rewardPropose"] = @(rewardedVideoAd.rewardedVideoModel.rewardPropose);
        dic[@"rewardName"] = rewardedVideoAd.rewardedVideoModel.rewardName;
        dic[@"rewardAmount"] = @(rewardedVideoAd.rewardedVideoModel.rewardAmount);
        [self AdRewardedWithInfo:dic];
    }
    [self AdClose];
}


- (void)rewardedVideoAdDidClick:(BURewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}


- (void)rewardedVideoAdDidPlayFinish:(BURewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *_Nullable)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    if(error != nil)
    {
        [self AdShowFailWithError:error];
    }
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}


- (void)rewardedVideoAdServerRewardDidSucceed:(BURewardedVideoAd *)rewardedVideoAd verify:(BOOL)verify
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.shouldReward = YES;
}


- (void)rewardedVideoAdServerRewardDidFail:(BURewardedVideoAd *)rewardedVideoAd error:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
}


- (void)rewardedVideoAdDidClickSkip:(BURewardedVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.isSkip = YES;
}


- (void)rewardedVideoAdCallback:(BURewardedVideoAd *)rewardedVideoAd withType:(BURewardedVideoAdType)rewardedVideoAdType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
@end
