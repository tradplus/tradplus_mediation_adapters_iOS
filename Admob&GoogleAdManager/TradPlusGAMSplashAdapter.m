#import "TradPlusGAMSplashAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MSConsentManager.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <GoogleMobileAds/GoogleMobileAds.h>
#import "TPAdMobAdapterBaseInfo.h"
#import "TPGoogleAdMobAdapterConfig.h"

@interface TradPlusGAMSplashAdapter ()<GADFullScreenContentDelegate>

@property (nonatomic,strong)GADAppOpenAd *appOpenAd;
@end

@implementation TradPlusGAMSplashAdapter

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
    else
    {
        return NO;
    }
    return YES;
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_AdMobAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [NSString stringWithFormat:@"%s",GoogleMobileAdsVersionString];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_AdMobAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *placementId = item.config[@"placementId"];
    if(placementId == nil)
    {
        [self AdConfigError];
        return;
    }
    [TPGoogleAdMobAdapterConfig setPrivacy:@{}];
    
    GAMRequest *request = [GAMRequest request];
    if (![MSConsentManager sharedManager].canCollectPersonalInfo
        || !gTPOpenPersonalizedAd)
    {
        MSLogTrace(@"***********");
        MSLogTrace(@"GAM non-personalized ads");
        MSLogTrace(@"***********");
        GADExtras *extras = [[GADExtras alloc] init];
        extras.additionalParameters = @{@"npa": @"1"};
        [request registerAdNetworkExtras:extras];
    }
    request.requestAgent = @"TradPlusAd";
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    
    __weak typeof(self) weakSelf = self;
    [GADAppOpenAd loadWithAdUnitID:placementId request:request orientation:orientation completionHandler:^(GADAppOpenAd * _Nullable appOpenAd, NSError * _Nullable error) {
        if(error == nil)
        {
            weakSelf.appOpenAd = appOpenAd;
            [weakSelf AdLoadFinsh];
        }
        else
        {
            [weakSelf AdLoadFailWithError:error];
        }
    }];
}

- (id)getCustomObject
{
    return self.appOpenAd;
}

- (BOOL)isReady
{
    return (self.appOpenAd != nil);
}

- (UIViewController *)getTopViewController:(UIViewController *)viewController
{
    while (viewController != nil && viewController.presentedViewController != nil)
    {
        viewController = viewController.presentedViewController;
    }
    return viewController;
}

- (void)showAdInWindow:(UIWindow *)window bottomView:(UIView *)bottomView
{
    UIViewController *rootViewController = window.rootViewController;
    NSError *error;
    if([self.appOpenAd canPresentFromRootViewController:rootViewController error:&error])
    {
        self.appOpenAd.fullScreenContentDelegate = self;
        [self.appOpenAd presentFromRootViewController:rootViewController];
    }
    else
    {
        UIViewController *topViewController = [self getTopViewController:rootViewController];
        if([self.appOpenAd canPresentFromRootViewController:topViewController error:&error])
        {
            self.appOpenAd.fullScreenContentDelegate = self;
            [self.appOpenAd presentFromRootViewController:topViewController];
        }
        else
        {
            [self AdShowFailWithError:error];
        }
    }
}

#pragma mark -GADFullScreenContentDelegate

- (void)adDidRecordImpression:(nonnull id<GADFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)adDidRecordClick:(nonnull id<GADFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)ad:(nonnull id<GADFullScreenPresentingAd>)ad
    didFailToPresentFullScreenContentWithError:(nonnull NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShowFailWithError:error];
}

- (void)adWillDismissFullScreenContent:(nonnull id<GADFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)adDidDismissFullScreenContent:(nonnull id<GADFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.appOpenAd.fullScreenContentDelegate = nil;
    self.appOpenAd = nil;
    [self AdClose];
}
@end
