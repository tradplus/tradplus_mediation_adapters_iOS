#import "TradPlusCSJInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <BUAdSDK/BUAdSDK.h>
#import "TradPlusCSJSDKLoader.h"
#import "TPCSJAdapterBaseInfo.h"

@interface TradPlusCSJInterstitialAdapter ()<BUFullscreenVideoAdDelegate,BUNativeExpressFullscreenVideoAdDelegate,TPSDKLoaderDelegate>

@property (nonatomic,assign)BOOL isTemplateRender;
@property (nonatomic,strong)BUFullscreenVideoAd *fullscreenVideoAd;
@property (nonatomic,strong)BUNativeExpressFullscreenVideoAd *expressFullscreenVideoAd;
@property (nonatomic,copy)NSString *placementId;
@property (nonatomic,copy)NSString *appId;
@property (nonatomic,assign) BOOL isC2SBidding;
@property (nonatomic,assign) BOOL didWin;
@property (nonatomic,assign) NSInteger ecpm;
@end

@implementation TradPlusCSJInterstitialAdapter

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
    self.isTemplateRender = YES;
    if(self.waterfallItem.is_template_rendering == 2)
    {
        self.isTemplateRender = NO;
    }
    switch (self.waterfallItem.adsource_type)
    {
        case 3:
        {
            self.expressFullscreenVideoAd = [[BUNativeExpressFullscreenVideoAd alloc] initWithSlotID:self.placementId];
            self.expressFullscreenVideoAd.delegate = self;
            [self.expressFullscreenVideoAd loadAdData];
            break;
        }
        default:
        {
            [self loadFullscreenVideoWithSlotID:self.placementId];
            break;
        }
    }
}

- (void)loadFullscreenVideoWithSlotID:(NSString *)slotID
{
    if(self.isTemplateRender)
    {
        self.expressFullscreenVideoAd = [[BUNativeExpressFullscreenVideoAd alloc] initWithSlotID:slotID];
        self.expressFullscreenVideoAd.delegate = self;
        [self.expressFullscreenVideoAd loadAdData];
    }
    else
    {
        self.fullscreenVideoAd = [[BUFullscreenVideoAd alloc] initWithSlotID:slotID];
        self.fullscreenVideoAd.delegate = self;
        [self.fullscreenVideoAd loadAdData];
    }
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    switch (self.waterfallItem.adsource_type)
    {
        case 3:
        {
            [self.expressFullscreenVideoAd showAdFromRootViewController:rootViewController];
            break;
        }
        default:
        {
            if(self.isTemplateRender)
            {
                [self.expressFullscreenVideoAd showAdFromRootViewController:rootViewController];
            }
            else
            {
                [self.fullscreenVideoAd showAdFromRootViewController:rootViewController];
            }
            break;
        }
    }
}

- (BOOL)isReady
{
    return self.isAdReady;
}

- (id)getCustomObject
{
    switch (self.waterfallItem.adsource_type)
    {
        case 3:
        {
            return self.expressFullscreenVideoAd;
        }
        default:
        {
            if(self.isTemplateRender)
            {
                return self.expressFullscreenVideoAd;
            }
            else
            {
                return self.fullscreenVideoAd;
            }
        }
    }
    return nil;
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
        NSError *loadError = [NSError errorWithDomain:@"CSJ.interstitial" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S Interstitial not ready"}];
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
    switch (self.waterfallItem.adsource_type)
    {
        case 3://新插屏广告
        {
            [self.expressFullscreenVideoAd win:@(self.ecpm)];
        }
        default://全屏视频
        {
            if(self.isTemplateRender)
            {
                [self.expressFullscreenVideoAd win:@(self.ecpm)];
            }
            else
            {
                [self.fullscreenVideoAd win:@(self.ecpm)];
            }
        }
    }
}

- (void)sendC2SLoss:(NSDictionary *)config
{
    if(self.didWin)
    {
        return;
    }
    NSString *topPirce = config[@"topPirce"];
    switch (self.waterfallItem.adsource_type)
    {
        case 3://新插屏广告
        {
            [self.expressFullscreenVideoAd loss:@([topPirce integerValue]) lossReason:@"102" winBidder:nil];
        }
        default://全屏视频
        {
            if(self.isTemplateRender)
            {
                [self.expressFullscreenVideoAd loss:@([topPirce integerValue]) lossReason:@"102" winBidder:nil];
            }
            else
            {
                [self.fullscreenVideoAd loss:@([topPirce integerValue]) lossReason:@"102" winBidder:nil];
            }
        }
    }
}

#pragma mark - BUFullscreenVideoAdDelegate

- (void)fullscreenVideoMaterialMetaAdDidLoad:(BUFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)fullscreenVideoAd:(BUFullscreenVideoAd *)fullscreenVideoAd didFailWithError:(NSError *_Nullable)error
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


- (void)fullscreenVideoAdVideoDataDidLoad:(BUFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.isAdReady = YES;
    if(self.isC2SBidding)
    {
        if(![fullscreenVideoAd.mediaExt valueForKey:@"price"])
        {
            NSString *errorStr = @"C2S Bidding Fail.[竞价失败，请确认是否已开启穿山甲竞价功能]";
            MSLogInfo(@"%@", errorStr);
            [self failC2SBiddingWithErrorStr:errorStr];
            return;
        }
        self.ecpm = [[fullscreenVideoAd.mediaExt valueForKey:@"price"] integerValue];
        [self finishC2SBidding];
    }
    else
    {
        [self AdLoadFinsh];
    }
}


- (void)fullscreenVideoAdWillVisible:(BUFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)fullscreenVideoAdDidVisible:(BUFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)fullscreenVideoAdDidClick:(BUFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)fullscreenVideoAdWillClose:(BUFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)fullscreenVideoAdDidClose:(BUFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

- (void)fullscreenVideoAdDidPlayFinish:(BUFullscreenVideoAd *)fullscreenVideoAd didFailWithError:(NSError *_Nullable)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}

- (void)fullscreenVideoAdDidClickSkip:(BUFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)fullscreenVideoAdCallback:(BUFullscreenVideoAd *)fullscreenVideoAd withType:(BUFullScreenVideoAdType)fullscreenVideoAdType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

#pragma mark - BUNativeExpressFullscreenVideoAdDelegate

- (void)nativeExpressFullscreenVideoAdDidLoad:(BUNativeExpressFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeExpressFullscreenVideoAd:(BUNativeExpressFullscreenVideoAd *)fullscreenVideoAd didFailWithError:(NSError *_Nullable)error
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

- (void)nativeExpressFullscreenVideoAdViewRenderSuccess:(BUNativeExpressFullscreenVideoAd *)rewardedVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeExpressFullscreenVideoAdViewRenderFail:(BUNativeExpressFullscreenVideoAd *)rewardedVideoAd error:(NSError *_Nullable)error
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

- (void)nativeExpressFullscreenVideoAdDidDownLoadVideo:(BUNativeExpressFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.isAdReady = YES;
    if(self.isC2SBidding)
    {
        if(![fullscreenVideoAd.mediaExt valueForKey:@"price"])
        {
            NSString *errorStr = @"C2S Bidding Fail.[竞价失败，请确认是否已开启穿山甲竞价功能]";
            MSLogInfo(@"%@", errorStr);
            [self failC2SBiddingWithErrorStr:errorStr];
            return;
        }
        self.ecpm = [[fullscreenVideoAd.mediaExt valueForKey:@"price"] integerValue];
        [self finishC2SBidding];
    }
    else
    {
        [self AdLoadFinsh];
    }
}


- (void)nativeExpressFullscreenVideoAdWillVisible:(BUNativeExpressFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)nativeExpressFullscreenVideoAdDidVisible:(BUNativeExpressFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}


- (void)nativeExpressFullscreenVideoAdDidClick:(BUNativeExpressFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}


- (void)nativeExpressFullscreenVideoAdDidClickSkip:(BUNativeExpressFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)nativeExpressFullscreenVideoAdWillClose:(BUNativeExpressFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)nativeExpressFullscreenVideoAdDidClose:(BUNativeExpressFullscreenVideoAd *)fullscreenVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}


- (void)nativeExpressFullscreenVideoAdDidPlayFinish:(BUNativeExpressFullscreenVideoAd *)fullscreenVideoAd didFailWithError:(NSError *_Nullable)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    if(error != nil)
    {
        [self AdShowFailWithError:error];
    }
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}


- (void)nativeExpressFullscreenVideoAdCallback:(BUNativeExpressFullscreenVideoAd *)fullscreenVideoAd withType:(BUNativeExpressFullScreenAdType) nativeExpressVideoAdType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)nativeExpressFullscreenVideoAdDidCloseOtherController:(BUNativeExpressFullscreenVideoAd *)fullscreenVideoAd interactionType:(BUInteractionType)interactionType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
@end
