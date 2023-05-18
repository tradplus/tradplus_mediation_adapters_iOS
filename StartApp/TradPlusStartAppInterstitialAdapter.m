#import "TradPlusStartAppInterstitialAdapter.h"
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSLogging.h>
#import <StartApp/StartApp.h>
#import "TradPlusStartAppSDKLoader.h"
#import "TPStartAppAdapterBaseInfo.h"

@interface TradPlusStartAppInterstitialAdapter ()<STADelegateProtocol,TPSDKLoaderDelegate>

@property (nonatomic, strong) STAStartAppAd* startAppInterstitialAd;
@property (nonatomic, copy) NSString *placementId;

@end

@implementation TradPlusStartAppInterstitialAdapter

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
    else if([event isEqualToString:@"SetTestMode"])
    {
        [[TradPlusStartAppSDKLoader sharedInstance] setTestMode];
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
        MSLogTrace(@"StartApp init Config Error %@",config);
        return;
    }
    tp_dispatch_main_async_safe(^{
        if([TradPlusStartAppSDKLoader sharedInstance].initSource == -1)
        {
            [TradPlusStartAppSDKLoader sharedInstance].initSource = 1;
        }
        [[TradPlusStartAppSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
    });
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_StartAppAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [[STAStartAppSDK sharedInstance] version];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_StartAppAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}


- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *appId = item.config[@"appId"];
    self.placementId = item.config[@"placementId"];
    if(appId == nil || self.placementId == nil)
    {
        [self AdConfigError];
        return;
    }
    [[TradPlusStartAppSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    self.startAppInterstitialAd = [[STAStartAppAd alloc] init];
    STAAdPreferences *preferences = [[STAAdPreferences alloc] init];
    preferences.adTag = self.placementId;
    [self.startAppInterstitialAd loadAdWithDelegate:self withAdPreferences:preferences];
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
    return self.startAppInterstitialAd;
}

- (BOOL)isReady
{
    return (self.startAppInterstitialAd != nil
            && self.startAppInterstitialAd.isReady);
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.startAppInterstitialAd showAdWithAdTag:self.placementId];
}

#pragma mark - STADelegateProtocol

- (void)didLoadAd:(STAAbstractAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}
- (void)failedLoadAd:(STAAbstractAd *)ad withError:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}
- (void)didShowAd:(STAAbstractAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}
- (void)failedShowAd:(STAAbstractAd *)ad withError:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdShowFailWithError:error];
}
- (void)didCloseAd:(STAAbstractAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}
- (void)didClickAd:(STAAbstractAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
    [self AdClose];
}
- (void)didCloseInAppStore:(STAAbstractAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
- (void)didCompleteVideo:(STAAbstractAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}
- (void)didShowNativeAdDetails:(STANativeAdDetails *)nativeAdDetails
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
- (void)didClickNativeAdDetails:(STANativeAdDetails *)nativeAdDetails
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
@end
