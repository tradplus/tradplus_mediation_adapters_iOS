#import "TradPlusOguryInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TradPlusOgurySDKLoader.h"
#import <OguryAds/OguryAds.h>
#import <OgurySdk/Ogury.h>
#import <OguryChoiceManager/OguryChoiceManager.h>
#import "TPOguryAdapterBaseInfo.h"

@interface TradPlusOguryInterstitialAdapter ()<OguryInterstitialAdDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) OguryInterstitialAd *interstitial;
@property (nonatomic, strong) NSString *appId;
@property (nonatomic, strong) NSString *adUnitId;
@property (nonatomic, weak) UIViewController *interstitialRootViewController;

@end

@implementation TradPlusOguryInterstitialAdapter

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
        MSLogTrace(@"Ogury init Config Error %@",config);
        return;
    }
    if([TradPlusOgurySDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusOgurySDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusOgurySDKLoader sharedInstance] initWithAssetKey:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_OguryAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [Ogury getSdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_OguryAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    self.appId = item.config[@"appId"];
    self.adUnitId = item.config[@"placementId"];
    if(self.appId == nil || self.adUnitId == nil)
    {
        [self AdConfigError];
        return;
    }
    [[TradPlusOgurySDKLoader sharedInstance] initWithAssetKey:self.appId delegate:self];
}

- (void)loadAd
{
    [[TradPlusOgurySDKLoader sharedInstance] setPrivacyWithAssetKey:self.appId];
    
    self.interstitial = [[OguryInterstitialAd alloc] initWithAdUnitId:self.adUnitId];
    self.interstitial.delegate = self;
        
    [self.interstitial load];
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
    return self.interstitial;
}

- (BOOL)isReady
{
    return self.interstitial && self.interstitial.isLoaded;
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.interstitial showAdInViewController:rootViewController];
}

#pragma mark - OguryInterstitialAdDelegate

- (void)didLoadOguryInterstitialAd:(OguryInterstitialAd *)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

-(void)oguryAdsInterstitialAdNotLoaded
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSError *error = [NSError errorWithDomain:@"Ogury" code:1001 userInfo:@{NSLocalizedDescriptionKey:@"no fill"}];
    [self AdLoadFailWithError:error];
}

- (void)didDisplayOguryInterstitialAd:(OguryInterstitialAd *)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)didCloseOguryInterstitialAd:(OguryInterstitialAd *)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

- (void)didFailOguryInterstitialAdWithError:(OguryError *)error forAd:(OguryInterstitialAd *)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShowFailWithError:error];
}

- (void)didClickOguryInterstitialAd:(OguryInterstitialAd *)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)didTriggerImpressionOguryInterstitialAd:(OguryInterstitialAd *)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}


@end
