#import "TradPlusBaiduSplashAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <BaiduMobAdSDK/BaiduMobAdSplash.h>
#import "TradPlusBaiduSDKSetting.h"
#import "TPBaiduAdapterBaseInfo.h"

@interface TradPlusBaiduSplashAdapter ()<BaiduMobAdSplashDelegate>

@property (nonatomic, strong) BaiduMobAdSplash *splash;
@property (nonatomic, copy) NSString *appId;
@property (nonatomic, strong) UIView *splashView;
@property (nonatomic, weak) UIWindow *window;
@property (nonatomic, assign) BOOL isC2SBidding;
@end

@implementation TradPlusBaiduSplashAdapter

#pragma mark - Extra
- (BOOL)extraActWithEvent:(NSString *)event info:(NSDictionary *)config
{
    if([event isEqualToString:@"AdapterVersion"])
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

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_BaiduAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = SDK_VERSION_IN_MSSP;
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_BaiduAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}


- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    self.appId = item.config[@"appId"];
    NSString *placementId = item.config[@"placementId"];
    if(placementId == nil || self.appId == nil)
    {
        [self AdConfigError];
        return;
    }
    [[TradPlusBaiduSDKSetting sharedInstance] setPersonalizedAd];
    self.splash = [[BaiduMobAdSplash alloc] init];
    self.splash.delegate = self;
    self.splash.AdUnitTag = placementId;
    CGSize size = [UIScreen mainScreen].bounds.size;
    if(item.splashBottomSize.height > 0)
    {
        size.height -= item.splashBottomSize.height;
    }
    self.splash.adSize = size;
    [self.splash load];
}

- (id)getCustomObject
{
    return self.splash;
}

- (BOOL)isReady
{
    return (self.splash != nil);
}

- (void)showAdInWindow:(UIWindow *)window bottomView:(UIView *)bottomView
{
    self.splashView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    if(bottomView != nil)
    {
        CGRect rect = bottomView.frame;
        rect.origin.y = [UIScreen mainScreen].bounds.size.height - rect.size.height;
        bottomView.frame = rect;
        [self.splashView addSubview:bottomView];
    }
    self.window = window;
    [self.splash showInContainerView:self.splashView];
}

- (void)removeSplashAd
{
    if(self.splashView != nil)
    {
        [self.splashView removeFromSuperview];
    }
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
        NSError *loadError = [NSError errorWithDomain:@"baidu.splash" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S Splash not ready"}];
        [self AdLoadFailWithError:loadError];
    }
}

- (void)finishC2SBiddingWithEcpm:(NSString *)ecpmStr
{
    NSString *version = SDK_VERSION_IN_MSSP;
    if(version == nil)
    {
        version = @"";
    }
    if(ecpmStr == nil)
    {
        ecpmStr = @"0";
    }
    NSDictionary *dic = @{@"ecpm":ecpmStr,@"version":version};
    [self ADLoadExtraCallbackWithEvent:@"C2SBiddingFinish" info:dic];
}

- (void)failC2SBiddingWithErrorStr:(NSString *)errorStr
{
    NSDictionary *dic = @{@"error":errorStr};
    [self ADLoadExtraCallbackWithEvent:@"C2SBiddingFail" info:dic];
}

#pragma mark -BaiduMobAdSplashDelegate

- (NSString *)publisherId
{
    return self.appId;
}

- (void)splashDidReady:(BaiduMobAdSplash *)splash
             AndAdType:(NSString *)adType
         VideoDuration:(NSInteger)videoDuration
{
    MSLogTrace(@"%s",__FUNCTION__);
    if(self.isC2SBidding)
    {
        [self finishC2SBiddingWithEcpm:[splash getECPMLevel]];
    }
    else
    {
        [self AdLoadFinsh];
    }
}

- (void)splashAdLoadFailCode:(NSString *)errCode message:(NSString *)message splashAd:(BaiduMobAdSplash *)nativeAd
{
    MSLogTrace(@"%s",__FUNCTION__);
    [self removeSplashAd];
    if(errCode == nil)
    {
        errCode = @"4001";
    }
    if(self.isC2SBidding)
    {
        if(message == nil)
        {
            message = @"C2S Bidding Fail";
        }
        NSString *errorStr = [NSString stringWithFormat:@"errCode: %@, errMsg: %@", errCode, message];
        [self failC2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        if(message == nil)
        {
            message = @"load faile";
        }
        NSError *error = [NSError errorWithDomain:@"Baidu" code:[errCode integerValue] userInfo:@{NSLocalizedDescriptionKey: message}];
        [self AdLoadFailWithError:error];
    }
}

- (void)splashDidExposure:(BaiduMobAdSplash *)splash
{
    MSLogTrace(@"%s",__FUNCTION__);
    [self AdShow];
}

- (void)splashSuccessPresentScreen:(BaiduMobAdSplash *)splash
{
    MSLogTrace(@"%s",__FUNCTION__);
    [self.window addSubview:self.splashView];
}

- (void)splashlFailPresentScreen:(BaiduMobAdSplash *)splash withError:(BaiduMobFailReason) reason
{
    MSLogTrace(@"%s",__FUNCTION__);
    NSError *error = [NSError errorWithDomain:@"Baidu" code:reason userInfo:@{NSLocalizedDescriptionKey: @"show faile"}];
    [self AdShowFailWithError:error];
    [self removeSplashAd];
}

- (void)splashDidClicked:(BaiduMobAdSplash *)splash
{
    MSLogTrace(@"%s",__FUNCTION__);
    [self AdClick];
}

- (void)splashDidDismissScreen:(BaiduMobAdSplash *)splas
{
    MSLogTrace(@"%s",__FUNCTION__);
    [self AdClose];
    [self removeSplashAd];
}

- (void)splashDidDismissLp:(BaiduMobAdSplash *)splash
{
    MSLogTrace(@"%s",__FUNCTION__);
}

- (void)splashAdLoadSuccess:(BaiduMobAdSplash *)splash
{
    MSLogTrace(@"%s",__FUNCTION__);
}
@end
