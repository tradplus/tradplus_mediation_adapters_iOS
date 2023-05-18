#import "TradPlusIronSourceInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <IronSource/IronSource.h>
#import "TPIronSourceManager.h"
#import "TradPlusIronSourceSDKLoader.h"
#import "TPIronSourceAdapterBaseInfo.h"

@interface TradPlusIronSourceInterstitialAdapter ()<IronSourceInterstitialDelegate,TPSDKLoaderDelegate>

@property (nonatomic,copy)NSString *placementId;
@end

@implementation TradPlusIronSourceInterstitialAdapter

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
    CGFloat systemVersion = [[UIDevice currentDevice].systemVersion floatValue];
    if(systemVersion < 10.0)
    {
        MSLogTrace(@"IronSource init Error. can't support os ver less than ios10!");
        return;
    }
    NSString *appId = config[@"appId"];
    if(appId == nil)
    {
        MSLogTrace(@"IronSource init Config Error %@",config);
        return;
    }
    if([TradPlusIronSourceSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusIronSourceSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusIronSourceSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_IronSourceAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [IronSource sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_IronSourceAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    CGFloat systemVersion = [[UIDevice currentDevice].systemVersion floatValue];
    if(systemVersion < 10.0)
    {
        NSError *error = [NSError errorWithDomain:@"IronSource" code:401  userInfo:@{NSLocalizedDescriptionKey: @"can't support os ver less than ios10!"}];
        [self AdLoadFailWithError:error];
        return;
    }
    
    self.placementId = item.config[@"placementId"];
    NSString *appId = item.config[@"appId"];
    if(self.placementId == nil || appId == nil)
    {
        [self AdConfigError];
        return;
    }
    
    [[TradPlusIronSourceSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    [[TPIronSourceManager sharedManager] requestInterstitialAdWithDelegate:self instanceID:self.placementId];
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
    [[TPIronSourceManager sharedManager] presentInterstitialAdFromViewController:rootViewController instanceID:self.placementId];
}

- (id)getCustomObject
{
    return nil;
}

- (BOOL)isReady
{
    return [IronSource hasISDemandOnlyInterstitial:self.placementId];
}

#pragma mark - IronSourceInterstitialDelegate
- (void)interstitialDidLoad:(NSString *)instanceId
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)interstitialDidFailToLoadWithError:(NSError *)error instanceId:(NSString *)instanceId
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFailWithError:error];
}
- (void)interstitialDidOpen:(NSString *)instanceId
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)interstitialDidClose:(NSString *)instanceId
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

- (void)interstitialDidFailToShowWithError:(NSError *)error instanceId:(NSString *)instanceId
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShowFailWithError:error];
}

- (void)didClickInterstitial:(NSString *)instanceId
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}
@end
