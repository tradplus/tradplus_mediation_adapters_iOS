#import "TradPlusStartAppRewardedAdapter.h"
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSLogging.h>
#import <StartApp/StartApp.h>
#import "TradPlusStartAppSDKLoader.h"
#import "TPStartAppAdapterBaseInfo.h"

@interface TradPlusStartAppRewardedAdapter ()<STADelegateProtocol,TPSDKLoaderDelegate>

@property (nonatomic, strong) STAStartAppAd *startAppRewardedVideoAd;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;
@end

@implementation TradPlusStartAppRewardedAdapter

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
    if([item.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [item.extraInfoDictionary[@"always_reward"] integerValue] == 1;
    }
    [[TradPlusStartAppSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    self.startAppRewardedVideoAd = [[STAStartAppAd alloc] init];
    STAAdPreferences *preferences = [[STAAdPreferences alloc] init];
    preferences.adTag = self.placementId;
    [self.startAppRewardedVideoAd loadRewardedVideoAdWithDelegate:self withAdPreferences:preferences];
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
    return self.startAppRewardedVideoAd;
}

- (BOOL)isReady
{
    return (self.startAppRewardedVideoAd != nil
            && self.startAppRewardedVideoAd.isReady);
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.startAppRewardedVideoAd showAdWithAdTag:self.placementId];
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
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}
- (void)failedShowAd:(STAAbstractAd *)ad withError:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdShowFailWithError:error];
}
- (void)didCloseAd:(STAAbstractAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if (self.shouldReward || self.alwaysReward)
    {
        [self AdRewardedWithInfo:nil];
    }
    [self AdClose];
}
- (void)didClickAd:(STAAbstractAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
    if (self.shouldReward || self.alwaysReward)
    {
        [self AdRewardedWithInfo:nil];
    }
    [self AdClose];
}
- (void)didCompleteVideo:(STAAbstractAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.shouldReward = YES;
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}
- (void)didCloseInAppStore:(STAAbstractAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
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
