#import "TradPlusUnityInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <UnityAds/UnityAds.h>
#import "TradPlusUnitySDKLoader.h"
#import "TPUnityAdapterBaseInfo.h"

@interface TradPlusUnityInterstitialAdapter ()<UnityAdsLoadDelegate,UnityAdsShowDelegate,TPSDKLoaderDelegate>

@property (nonatomic,copy)NSString *placementId;
@end

@implementation TradPlusUnityInterstitialAdapter

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
    if(appId == nil)
    {
        MSLogTrace(@"Unity init Config Error %@",config);
        return;
    }
    if([TradPlusUnitySDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusUnitySDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusUnitySDKLoader sharedInstance] initWithGameID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_UnityAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [UnityAds getVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_UnityAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *appId = item.config[@"appId"];
    self.placementId = item.config[@"placementId"];
    if(self.placementId == nil)
    {
        self.placementId = item.config[@"zoneId"];
    }
    if(appId == nil || self.placementId == nil)
    {
        [self AdConfigError];
        return;
    }
    [[TradPlusUnitySDKLoader sharedInstance] initWithGameID:appId delegate:self];
}

- (void)loadAd
{
    [[TradPlusUnitySDKLoader sharedInstance] setPersonalizedAd];
    [UnityAds load:self.placementId  loadDelegate:self];
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

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [UnityAds show:rootViewController placementId:self.placementId showDelegate:self];
}

- (id)getCustomObject
{
    return nil;
}

- (BOOL)isReady
{
    return self.isAdReady;
}

#pragma mark -UnityAdsLoadDelegate
- (void)unityAdsAdLoaded: (NSString *)placementId
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)unityAdsAdFailedToLoad: (NSString *)placementId
                     withError: (UnityAdsLoadError)error
                   withMessage: (NSString *)message
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSError *loadError = [NSError errorWithDomain:@"unity" code:error userInfo:@{NSLocalizedDescriptionKey:message}];
    [self AdLoadFailWithError:loadError];
}

- (void)unityAdsShowClick: (NSString *)placementId
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)unityAdsShowComplete: (NSString *)placementId withFinishState: (UnityAdsShowCompletionState)state
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
    [self AdClose];
}

- (void)unityAdsShowFailed: (NSString *)placementId withError: (UnityAdsShowError)error withMessage: (NSString *)message
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSError *showError = [NSError errorWithDomain:@"unity" code:error userInfo:@{NSLocalizedDescriptionKey:message}];
    [self AdShowFailWithError:showError];
}

- (void)unityAdsShowStart: (NSString *)placementId
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

@end
