#import "TradPlusSigmobSplashAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <WindSDK/WindSDK.h>
#import "TradPlusSigmobSDKLoader.h"
#import "TPSigmobAdapterBaseInfo.h"

@interface TradPlusSigmobSplashAdapter ()<WindSplashAdViewDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) WindSplashAdView *splashAd;
@property (nonatomic, copy) NSString *placementId;
@end

@implementation TradPlusSigmobSplashAdapter

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
    else
    {
        return NO;
    }
    return YES;
}

- (void)initSDKWithInfo:(NSDictionary *)config
{
    NSString *appId = config[@"appId"];
    NSString *appKey = config[@"AppKey"];
    if(appId == nil || appKey == nil)
    {
        MSLogTrace(@"Sigmob init Config Error %@",config);
        return;
    }
    if([TradPlusSigmobSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusSigmobSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusSigmobSDKLoader sharedInstance] initWithAppID:appId appKey:appKey delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_SigmobAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [WindAds sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_SigmobAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *appId = item.config[@"appId"];
    NSString *appKey = item.config[@"AppKey"];
    self.placementId = item.config[@"placementId"];
    if(appId == nil || appKey == nil || self.placementId == nil)
    {
        [self AdConfigError];
        return;
    }
    [[TradPlusSigmobSDKLoader sharedInstance] initWithAppID:appId appKey:appKey delegate:self];
}

- (void)loadAd
{
    [[TradPlusSigmobSDKLoader sharedInstance] setPersonalizedAd];
    WindAdRequest *request = [[WindAdRequest alloc] init];
    request.placementId = self.placementId;
    self.splashAd = [[WindSplashAdView alloc] initWithRequest:request];
    self.splashAd.rootViewController = self.waterfallItem.splashWindow.rootViewController;
    self.splashAd.delegate = self;
    NSString *bidToken = nil;
    if(self.waterfallItem.adsourceplacement != nil)
    {
        bidToken = self.waterfallItem.adsourceplacement.adm;
    }
    if(bidToken == nil)
    {
        [self.splashAd loadAdData];
    }
    else
    {
        [self.splashAd loadAdDataWithBidToken:bidToken];
    }
}

#pragma mark - TPSDKLoaderDelegate
- (void)tpInitFinish
{
    [self loadAd];
}

- (void)tpInitFailWithError:(NSError *)error
{
    [self AdLoadFailWithError:error];
}

- (id)getCustomObject
{
    return self.splashAd;
}

- (BOOL)isReady
{
    return (self.splashAd != nil);
}

- (void)showAdInWindow:(UIWindow *)window bottomView:(UIView *)bottomView
{
    self.splashAd.frame = CGRectMake(0, 0, window.bounds.size.width, window.bounds.size.height);
    [window addSubview:self.splashAd];
}

#pragma mark - WindSplashAdDelegate

- (void)onSplashAdDidLoad:(WindSplashAdView *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

-(void)onSplashAdLoadFail:(WindSplashAdView *)splashAd error:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFailWithError:error];
}


-(void)onSplashAdSuccessPresentScreen:(WindSplashAdView *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

-(void)onSplashAdFailToPresent:(WindSplashAdView *)splashAd withError:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShowFailWithError:error];
}


- (void)onSplashAdClicked:(WindSplashAdView *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)onSplashAdSkiped:(WindSplashAdView *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_splash_skip" info:nil];
}

- (void)onSplashAdWillClosed:(WindSplashAdView *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)onSplashAdClosed:(WindSplashAdView *)splashAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self.splashAd removeFromSuperview];
    self.splashAd.delegate = nil;
    self.splashAd = nil;
    [self AdClose];
}

@end
