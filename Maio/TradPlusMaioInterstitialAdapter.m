#import "TradPlusMaioInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <Maio/Maio.h>
#import "TradPlusMaioSDKLoader.h"
#import "TPMaioAdapterBaseInfo.h"

@interface TradPlusMaioInterstitialAdapter ()<MaioDelegate,TPSDKLoaderDelegate>

@property (nonatomic, copy) NSString *placementId;
@end

@implementation TradPlusMaioInterstitialAdapter

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
    
- (void)maioDidInitialize
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

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
}


- (void)maioDidFinishAd:(NSString *)zoneId playtime:(NSInteger)playtime skipped:(BOOL)skipped rewardParam:(NSString *)rewardParam
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
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
