#import "TradPlusMaioRewardedAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <Maio/Maio.h>
#import "TradPlusMaioSDKLoader.h"
#import "TPMaioAdapterBaseInfo.h"

@interface TradPlusMaioRewardedAdapter ()<MaioDelegate,TPSDKLoaderDelegate>

@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;
@property (nonatomic, assign) BOOL isSkip;
@property (nonatomic, strong) NSMutableDictionary *rewardDic;
@end

@implementation TradPlusMaioRewardedAdapter

- (void)dealloc
{
    [Maio removeDelegateObject:self];
}

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
        MSLogTrace(@"Maio init Config Error %@",config);
        return;
    }
    if([TradPlusMaioSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusMaioSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusMaioSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_MaioAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [Maio sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_MaioAdapter_PlatformSDK_Version
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
    [[TradPlusMaioSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    [Maio addDelegateObject:self];
    if([Maio canShowAtZoneId:self.placementId])
    {
        [self AdLoadFinsh];
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


- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [Maio showAtZoneId:self.placementId vc:rootViewController];
}

- (BOOL)isReady
{
    return [Maio canShowAtZoneId:self.placementId];
}

- (id)getCustomObject
{
    return nil;
}

#pragma mark - MaioDelegate

- (void)maioDidChangeCanShow:(NSString *)zoneId newValue:(BOOL)newValue
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if([zoneId isEqualToString:self.placementId])
    {
        [self AdLoadFinsh];
    }
}


- (void)maioWillStartAd:(NSString *)zoneId
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if (![self.placementId isEqualToString:zoneId])
    {
        return;
    }
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}


- (void)maioDidFinishAd:(NSString *)zoneId playtime:(NSInteger)playtime skipped:(BOOL)skipped rewardParam:(NSString *)rewardParam
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if([zoneId isEqualToString:self.placementId])
    {
        if(skipped)
        {
            self.isSkip = YES;
        }
        else
        {
            NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
            if(rewardParam != nil)
            {
                dic[@"rewardParam"] = rewardParam;
            }
            self.rewardDic = [NSMutableDictionary dictionaryWithDictionary:dic];
            self.shouldReward = YES;
        }
    }
}

- (void)maioDidClickAd:(NSString *)zoneId
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if (![self.placementId isEqualToString:zoneId])
    {
        return;
    }
    [self AdClick];
}


- (void)maioDidCloseAd:(NSString *)zoneId
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if (![self.placementId isEqualToString:zoneId])
    {
        return;
    }
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
    if (self.shouldReward || (self.alwaysReward && !self.isSkip))
        [self AdRewardedWithInfo:self.rewardDic];
    [self AdClose];
}


- (void)maioDidFail:(NSString *)zoneId reason:(MaioFailReason)reason
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if (![self.placementId isEqualToString:zoneId])
    {
        return;
    }
    NSError *error = [NSError errorWithDomain:@"Maio" code:reason userInfo:@{NSLocalizedDescriptionKey:@"Load Fail"}];
    [self AdLoadFailWithError:error];
}
@end
