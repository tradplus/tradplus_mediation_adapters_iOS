#import "TradPlusTapjoyInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TradPlusTapjoySDKLoader.h"
#import <Tapjoy/Tapjoy.h>
#import "TPTapjoyAdapterBaseInfo.h"

@interface TradPlusTapjoyInterstitialAdapter ()<TJPlacementDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) TJPlacement *placement;
@property (nonatomic, copy) NSString *placementId;
@end

@implementation TradPlusTapjoyInterstitialAdapter

- (void)dealloc
{
    
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
    NSString *sdkKey = config[@"Sdk_Key"];
    if(sdkKey == nil)
    {
        MSLogTrace(@"Tapjoy init Config Error %@",config);
        return;
    }
    if([TradPlusTapjoySDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusTapjoySDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusTapjoySDKLoader sharedInstance] initWithSDKKey:sdkKey delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_TapjoyAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [Tapjoy getVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_TapjoyAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *sdkKey = item.config[@"Sdk_Key"];
    self.placementId = item.config[@"placementId"];
    if(sdkKey == nil || self.placementId == nil)
    {
        [self AdConfigError];
        return;
    }
    
    [[TradPlusTapjoySDKLoader sharedInstance] initWithSDKKey:sdkKey delegate:self];
}

- (void)loadAd
{
    self.placement = [TJPlacement placementWithName:self.placementId mediationAgent:@"tradplus" mediationId:nil delegate:self];
    [self.placement requestContent];
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
    return self.placement;
}

- (BOOL)isReady
{
    return (self.placement != nil && self.placement.isContentAvailable);
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.placement showContentWithViewController:rootViewController];
}

#pragma mark- TJPlacementDelegate
- (void)requestDidSucceed:(TJPlacement*)placement
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(placement.isContentAvailable)
    {
        [self AdLoadFinsh];
    }
    else
    {
        NSError *error = [NSError errorWithDomain:@"Tapjoy" code:406 userInfo:@{NSLocalizedDescriptionKey:@"load fail"}];
        [self AdLoadFailWithError:error];
    }
}

- (void)requestDidFail:(TJPlacement*)placement error:(NSError*)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFailWithError:error];
}

- (void)didClick:(TJPlacement*)placement
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)contentDidDisappear:(TJPlacement*)placement
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

- (void)contentDidAppear:(TJPlacement*)placement
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)contentIsReady:(TJPlacement*)placement
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)placement:(TJPlacement*)placement didRequestPurchase:(TJActionRequest*)request productId:(NSString*)productId
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)placement:(TJPlacement*)placement didRequestReward:(TJActionRequest*)request itemId:(NSString*)itemId quantity:(int)quantity
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
@end
