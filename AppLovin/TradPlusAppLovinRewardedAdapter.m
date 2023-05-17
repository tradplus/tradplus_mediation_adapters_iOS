#import "TradPlusAppLovinRewardedAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <AppLovinSDK/AppLovinSDK.h>
#import "TradPlusAppLovinSDKLoader.h"
#import "TPAppLovinAdapterBaseInfo.h"

@interface TradPlusAppLovinRewardedAdapter ()<ALAdLoadDelegate,ALAdDisplayDelegate,ALAdVideoPlaybackDelegate,ALAdRewardDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong)ALIncentivizedInterstitialAd *interstitial;
@property (nonatomic,strong)ALAd *ad;
@property (nonatomic,copy)NSString *placementId;
@property (nonatomic,assign)BOOL shouldReward;
@property (nonatomic,assign)BOOL alwaysReward;
@property (nonatomic, strong) NSMutableDictionary *rewardDic;
@end

@implementation TradPlusAppLovinRewardedAdapter

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
    if(appId == nil  ||  appId.length <= 5)
    {
        MSLogTrace(@"AppLovin init Config Error %@",config);
        return;
    }
    if([TradPlusAppLovinSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusAppLovinSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusAppLovinSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_AppLovinAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [ALSdk version];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_AppLovinAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *appId = item.config[@"appId"];
    self.placementId = item.config[@"placementId"];
    if(appId == nil  || self.placementId == nil || appId.length <= 5)
    {
        [self AdConfigError];
        return;
    }
    
    if([item.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [item.extraInfoDictionary[@"always_reward"] integerValue] == 1;
    }
    
    if(self.waterfallItem.serverSideUserID != nil
       && self.waterfallItem.serverSideUserID.length > 0)
    {
        [[TradPlusAppLovinSDKLoader sharedInstance] setUserID:self.waterfallItem.serverSideUserID];
    }
    [[TradPlusAppLovinSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

#pragma mark - TPSDKLoaderDelegate

- (void)tpInitFinish
{
    [self setupAdViewWithSDK:[TradPlusAppLovinSDKLoader sharedInstance].sdk placementId:self.placementId];
}

- (void)tpInitFailWithError:(NSError *)error
{
    [self AdLoadFailWithError:error];
}

- (void)setupAdViewWithSDK:(ALSdk *)sdk placementId:(NSString *)placementId
{
    self.interstitial = [[ALIncentivizedInterstitialAd alloc] initWithSdk:sdk];
    self.interstitial.adDisplayDelegate = self;
    self.interstitial.adVideoPlaybackDelegate = self;
    [sdk.adService loadNextAdForZoneIdentifier:placementId andNotify:self];
}

- (id)getCustomObject
{
    return self.interstitial;
}

- (BOOL)isReady
{
    return (self.ad != nil);
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.interstitial showAd:self.ad andNotify:self];
}

#pragma mark - ALAdLoadDelegate
- (void)adService:(ALAdService *)adService didLoadAd:(ALAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.ad = ad;
    [self AdLoadFinsh];
}

- (void)adService:(ALAdService *)adService didFailToLoadAdWithError:(int)code
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSError *loadError = [NSError errorWithDomain:@"AppLovin" code:code userInfo:@{NSLocalizedDescriptionKey:@"load fail"}];
    [self AdLoadFailWithError:loadError];
}

#pragma mark - ALAdDisplayDelegate
- (void)ad:(ALAd *)ad wasDisplayedIn:(UIView *)view
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)ad:(ALAd *)ad wasHiddenIn:(UIView *)view
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if (self.shouldReward || self.alwaysReward)
        [self AdRewardedWithInfo:self.rewardDic];
    [self AdClose];
}

- (void)ad:(ALAd *)ad wasClickedIn:(UIView *)view
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

#pragma mark - ALAdVideoPlaybackDelegate
- (void)videoPlaybackBeganInAd:(ALAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)videoPlaybackEndedInAd:(ALAd *)ad atPlaybackPercent:(NSNumber *)percentPlayed fullyWatched:(BOOL)wasFullyWatched
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}

#pragma mark - ALAdRewardDelegate
- (void)rewardValidationRequestForAd:(ALAd *)ad didSucceedWithResponse:(NSDictionary *)response
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.rewardDic = [NSMutableDictionary dictionaryWithDictionary:response];
    self.shouldReward = YES;
}

- (void)rewardValidationRequestForAd:(ALAd *)ad didExceedQuotaWithResponse:(NSDictionary *)response
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__ ,response);
}


- (void)rewardValidationRequestForAd:(ALAd *)ad wasRejectedWithResponse:(NSDictionary *)response
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,response);
}

- (void)rewardValidationRequestForAd:(ALAd *)ad didFailWithError:(NSInteger)responseCode
{
    MSLogTrace(@"%s %ld", __PRETTY_FUNCTION__,(long)responseCode);
}
@end
