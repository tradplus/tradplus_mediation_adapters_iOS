#import "TradPlusKlevinSplashAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TradPlusKlevinSDKLoader.h"
#import <KlevinAdSDK/KlevinAdSDK.h>
#import <KlevinAdSDK/KLNSplashAd.h>
#import "TPKlevinAdapterBaseInfo.h"

@interface TradPlusKlevinSplashAdapter ()<KLNSplashAdDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong)NSString *placementId;
@property (nonatomic,strong)KLNSplashAd *splashAd;
@property (nonatomic,assign)BOOL isC2SBidding;
@end

@implementation TradPlusKlevinSplashAdapter

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
    
    [[TradPlusKlevinSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    [[TradPlusKlevinSDKLoader sharedInstance] setPersonalizedAd];
    KLNSplashAdRequest *req = [[KLNSplashAdRequest alloc] initWithPosId:self.placementId];
    __weak typeof(self) weakSelf = self;
    [KLNSplashAd loadWithRequest:req completionHandler:^(KLNSplashAd * _Nullable splashAd, NSError * _Nullable error) {
        if(error == nil)
        {
            weakSelf.splashAd = splashAd;
            if(self.isC2SBidding)
            {
                [self finishC2SBiddingWithEcpm:splashAd.eCPM];
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
        NSError *loadError = [NSError errorWithDomain:@"Klevin" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S Splash not ready"}];
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

- (void)showAdInWindow:(UIWindow *)window bottomView:(UIView *)bottomView
{
    UIViewController *rootViewController = window.rootViewController;
    NSError *error;
    if(rootViewController != nil)
    {
        self.splashAd.delegate = self;
        self.splashAd.viewController = rootViewController;
        [window addSubview:self.splashAd.adView];
    }
    else
    {
        [self AdShowFailWithError:error];
    }
}

- (BOOL)isReady
{
    return (self.splashAd != nil);
}

- (id)getCustomObject
{
    return self.splashAd;
}

#pragma mark - KLNFullScreenContentDelegate

- (void)kln_splashAdWillExpose:(KLNSplashAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)kln_splashAdDidClick:(KLNSplashAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)kln_splashAdClickSkip:(KLNSplashAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_splash_skip" info:nil];
}

- (void)kln_splashAdDidCloseOtherController:(KLNSplashAd *)ad interactionType:(KLNInteractionType)interactionType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)kln_splashAdClosed:(KLNSplashAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self.splashAd.adView removeFromSuperview];
    [self.splashAd removeSplashAd];
    self.splashAd = nil;
    [self AdClose];
}
@end
