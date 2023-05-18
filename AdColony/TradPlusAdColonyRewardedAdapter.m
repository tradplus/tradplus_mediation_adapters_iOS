#import "TradPlusAdColonyRewardedAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <AdColony/AdColony.h>
#import "TradPlusAdColonySDKLoader.h"
#import "TPAdColonyAdapterBaseInfo.h"

@interface TradPlusAdColonyRewardedAdapter ()<AdColonyInterstitialDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) AdColonyInterstitial *interstitial;
@property (nonatomic, strong) AdColonyZone *colonyZone;
@property (nonatomic, copy) NSString *zoneId;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;
@property (nonatomic, strong) NSMutableDictionary *rewardDic;
@end

@implementation TradPlusAdColonyRewardedAdapter

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
    NSString *strAllZoneIds = config[@"adcolonyZ"];
    if(appId == nil || strAllZoneIds == nil)
    {
        MSLogTrace(@"AdColony init Config Error %@",config);
        return;
    }
    NSArray *allZoneIds = [strAllZoneIds componentsSeparatedByString:@","];
    if([TradPlusAdColonySDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusAdColonySDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusAdColonySDKLoader sharedInstance] initWithAppID:appId zoneIDs:allZoneIds delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_AdColonyAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [AdColony getSDKVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_AdColonyAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *appId = item.config[@"appId"];
    self.zoneId = item.config[@"placementId"];
    NSString *strAllZoneIds = item.config[@"adcolonyZ"];
    if(appId == nil || strAllZoneIds == nil || self.zoneId == nil)
    {
        [self AdConfigError];
        return;
    }
    
    if([item.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [item.extraInfoDictionary[@"always_reward"] integerValue] == 1;
    }
    
    NSArray *allZoneIds = [strAllZoneIds componentsSeparatedByString:@","];
    [[TradPlusAdColonySDKLoader sharedInstance] initWithAppID:appId zoneIDs:allZoneIds delegate:self];
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

- (void)loadAd
{
    NSString *userId = nil;
    if(self.waterfallItem.serverSideUserID != nil
       && self.waterfallItem.serverSideUserID.length > 0)
    {
        userId = self.waterfallItem.serverSideUserID;
        AdColonyAppOptions *appOptions = [AdColony getAppOptions];
        if(appOptions != nil)
        {
            appOptions.userID = userId;
            [AdColony setAppOptions:appOptions];
            MSLogTrace(@"AdConlony ServerSideVerification ->userID: %@", userId);
        }
    }
    
    AdColonyAdOptions *adOptions = [AdColonyAdOptions new];
    adOptions.showPrePopup = NO;
    adOptions.showPostPopup = NO;
    [AdColony requestInterstitialInZone:self.zoneId options:adOptions andDelegate:self];
}

- (id)getCustomObject
{
    return self.interstitial;
}

- (BOOL)isReady
{
    return (self.interstitial != nil && !self.interstitial.expired);
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.interstitial showWithPresentingViewController:rootViewController];
}

#pragma mark - AdColonyInterstitialDelegate
- (void)adColonyInterstitialDidLoad:(AdColonyInterstitial * _Nonnull)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.interstitial = interstitial;
    self.colonyZone = [AdColony zoneForID:self.zoneId];
    __weak typeof(self) weakSelf = self;
    [self.colonyZone setReward:^(BOOL success, NSString * _Nonnull name, int amount) {
        if(success)
        {
            MSLogTrace(@"AdRewarded");
            NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
            dic[@"rewardName"] = name;
            dic[@"rewardNumber"] = @(amount);
            weakSelf.shouldReward = YES;
            weakSelf.rewardDic = [NSMutableDictionary dictionaryWithDictionary:dic];
        }
    }];
    [self AdLoadFinsh];
}

- (void)adColonyInterstitialDidFailToLoad:(AdColonyAdRequestError * _Nonnull)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFailWithError:error];
}

- (void)adColonyInterstitialDidReceiveClick:(AdColonyInterstitial * _Nonnull)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)adColonyInterstitialDidClose:(AdColonyInterstitial * _Nonnull)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
    if (self.shouldReward || self.alwaysReward)
        [self AdRewardedWithInfo:self.rewardDic];
    [self AdClose];
}

- (void)adColonyInterstitialWillOpen:(AdColonyInterstitial * _Nonnull)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)adColonyInterstitialExpired:(AdColonyInterstitial * _Nonnull)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)adColonyInterstitialWillLeaveApplication:(AdColonyInterstitial * _Nonnull)interstitial
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
@end
