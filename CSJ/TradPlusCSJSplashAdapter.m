#import "TradPlusCSJSplashAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <BUAdSDK/BUAdSDK.h>
#import "TradPlusCSJSDKLoader.h"
#import "TPCSJAdapterBaseInfo.h"

@interface TradPlusCSJSplashAdapter ()<BUSplashAdDelegate, BUSplashZoomOutDelegate, TPSDKLoaderDelegate>
@property (nonatomic,strong)BUSplashAd *splashAd;
@property (nonatomic,copy)NSString *placementId;
@property (nonatomic,assign)BOOL didClosed;
@property (nonatomic,copy)NSString *appId;
@property (nonatomic,weak)UIView *bottomView;
@property (nonatomic,strong)UIViewController *adViewController;
@property (nonatomic,assign) BOOL isC2SBidding;
@property (nonatomic,assign) BOOL didWin;
@property (nonatomic,assign) NSInteger ecpm;
@end

@implementation TradPlusCSJSplashAdapter

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
    CGSize size = [UIScreen mainScreen].bounds.size;
    if(self.waterfallItem.splashBottomSize.height > 0)
    {
        size.height -= self.waterfallItem.splashBottomSize.height;
    }
    self.splashAd = [[BUSplashAd alloc] initWithSlotID:self.placementId adSize:size];
    self.splashAd.delegate = self;
    self.splashAd.zoomOutDelegate = self;
    self.splashAd.supportZoomOutView = self.waterfallItem.zoom_out == 1;
    [self.splashAd loadAdData];
}

- (BOOL)isReady
{
    return self.isAdReady;
}

- (id)getCustomObject
{
    return self.splashAd;
}

- (void)showAdInWindow:(UIWindow *)window bottomView:(UIView *)bottomView
{
    UIViewController *rootViewController;
    if(window.rootViewController != nil)
    {
        rootViewController = window.rootViewController;
    }
    else
    {
        self.adViewController = [[UIViewController alloc] init];
        self.adViewController.view.frame = [UIScreen mainScreen].bounds;
        rootViewController = self.adViewController;
        [window addSubview:self.adViewController.view];
    }
    if(bottomView != nil)
    {
        self.bottomView = bottomView;
        CGRect rect = self.bottomView.bounds;
        rect.origin.y = [UIScreen mainScreen].bounds.size.height - rect.size.height;
        self.bottomView.frame = rect;
        [rootViewController.view addSubview:self.bottomView];
    }
    [self.splashAd showSplashViewInRootViewController:rootViewController];
}

- (void)clear
{
    if(self.bottomView != nil)
    {
        [self.bottomView removeFromSuperview];
    }
    if(self.adViewController != nil)
    {
        [self.adViewController.view removeFromSuperview];
        self.adViewController = nil;
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
        NSError *loadError = [NSError errorWithDomain:@"CSJ.splash" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S Splash not ready"}];
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
    [self.splashAd win:@(self.ecpm)];
    MSLogTrace(@"sendC2SWin:%@",@(self.ecpm));
}

- (void)sendC2SLoss:(NSDictionary *)config
{
    if(self.didWin)
    {
        return;
    }
    NSString *topPirce = config[@"topPirce"];
    [self.splashAd loss:@([topPirce integerValue]) lossReason:@"102" winBidder:nil];
    MSLogTrace(@"sendC2SLoss:%@",topPirce);
}

#pragma mark - BUSplashAdDelegate
- (void)splashAdLoadSuccess:(BUSplashAd *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)splashAdRenderFail:(nonnull BUSplashAd *)splashAd error:(BUAdError * _Nullable)error {
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__, error);
    [self AdLoadFailWithError:error];
}

- (void)splashAdRenderSuccess:(BUSplashAd *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.isAdReady = YES;
    if(self.isC2SBidding)
    {
        if(![splashAd.mediaExt valueForKey:@"price"])
        {
            NSString *errorStr = @"C2S Bidding Fail.[竞价失败，请确认是否已开启穿山甲竞价功能]";
            MSLogInfo(@"%@", errorStr);
            [self failC2SBiddingWithErrorStr:errorStr];
            return;
        }
        self.ecpm = [[splashAd.mediaExt valueForKey:@"price"] integerValue];
        [self finishC2SBidding];
    }
    else
    {
        [self AdLoadFinsh];
    }
}

- (void)splashAdLoadFail:(BUSplashAd *)splashAd error:(BUAdError *_Nullable)error
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

- (void)splashAdDidShow:(BUSplashAd *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)splashAdDidClick:(BUSplashAd *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)splashAdDidClose:(BUSplashAd *)splashAd closeType:(BUSplashAdCloseType)closeType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if (closeType == BUSplashAdCloseType_ClickSkip)
    {
        [self ADShowExtraCallbackWithEvent:@"tradplus_splash_skip" info:nil];
    }
    if(!self.splashAd.zoomOutView)
    {
        [self AdClose];
    }
    else {
        [self ADShowExtraCallbackWithEvent:@"tradplus_splash_zoom_show" info:nil];
    }
    [self clear];
}


- (void)splashAdViewControllerDidClose:(nonnull BUSplashAd *)splashAd {
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)splashAdWillShow:(nonnull BUSplashAd *)splashAd {
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)splashDidCloseOtherController:(nonnull BUSplashAd *)splashAd interactionType:(BUInteractionType)interactionType {
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)splashVideoAdDidPlayFinish:(nonnull BUSplashAd *)splashAd didFailWithError:(nonnull NSError *)error {
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


#pragma mark - BUSplashZoomOutViewDelegate
- (void)splashZoomOutReadyToShow:(BUSplashAd *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if (self.splashAd.zoomOutView)
    {
        [self.splashAd showZoomOutViewInRootViewController:self.waterfallItem.splashWindow.rootViewController];
    }
}

- (void)splashZoomOutViewDidClick:(BUSplashAd *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
    [self ADShowExtraCallbackWithEvent:@"tradplus_splash_zoom_close" info:nil];
    [self AdClose];
}

- (void)splashZoomOutViewDidClose:(BUSplashAd *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_splash_zoom_close" info:nil];
    [self AdClose];
}

@end
