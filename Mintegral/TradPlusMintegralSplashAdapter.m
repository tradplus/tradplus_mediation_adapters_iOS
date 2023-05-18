#import "TradPlusMintegralSplashAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TradPlusMintegralSDKLoader.h"
#import <MTGSDKSplash/MTGSplashAD.h>
#import "TPMintegralAdapterBaseInfo.h"

@interface TradPlusMintegralSplashAdapter ()<MTGSplashADDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong)MTGSplashAD *splashAD;
@property (nonatomic,copy)NSString *placementId;
@property (nonatomic,copy)NSString *unitId;
@property (nonatomic,assign)BOOL isBidding;
@end

@implementation TradPlusMintegralSplashAdapter

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
    NSString *appKey = config[@"AppKey"];
    if(appId == nil || appKey == nil)
    {
        MSLogTrace(@"Mintegral init Config Error %@",config);
        return;
    }
    if([TradPlusMintegralSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusMintegralSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusMintegralSDKLoader sharedInstance] initWithAppID:appId apiKey:appKey delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_MintegralAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [MTGSDK sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_MintegralAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *appId = item.config[@"appId"];
    NSString *appKey = item.config[@"AppKey"];
    self.placementId = item.config[@"placementId"];
    self.unitId = item.config[@"unitId"];
    if(appId == nil || appKey == nil || self.placementId == nil || self.unitId == nil)
    {
        [self AdConfigError];
        return;
    }
    [[TradPlusMintegralSDKLoader sharedInstance] initWithAppID:appId apiKey:appKey delegate:self];
}

- (void)loadAd
{
    [[TradPlusMintegralSDKLoader sharedInstance] setPersonalizedAd];
    MTGInterfaceOrientation orientation = MTGInterfaceOrientationAll;
    if(self.waterfallItem.direction == 1)
    {
        orientation = MTGInterfaceOrientationPortrait;
    }
    else if(self.waterfallItem.direction == 2)
    {
        orientation = MTGInterfaceOrientationLandscape;
    }
    BOOL allowSkip = YES;
    if(self.waterfallItem.is_skipable == 2)
    {
        allowSkip = NO;
    }
    self.splashAD = [[MTGSplashAD alloc] initWithPlacementID:self.placementId unitID:self.unitId countdown:self.waterfallItem.countdown_time allowSkip:allowSkip customViewSize:self.waterfallItem.splashBottomSize preferredOrientation:orientation];
    self.splashAD.delegate = self;
    NSString *bidToken = nil;
    self.isBidding = NO;
    if(self.waterfallItem.adsourceplacement != nil)
    {
        self.isBidding = YES;
        bidToken = self.waterfallItem.adsourceplacement.adm;
    }
    if(bidToken == nil)
    {
        [self.splashAD preload];
    }
    else
    {
        [self.splashAD preloadWithBidToken:bidToken];
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

- (id)getCustomObject
{
    return self.splashAD;
}

- (BOOL)isReady
{
    if(self.isBidding)
    {
        return (self.splashAD != nil && [self.splashAD isBiddingADReadyToShow]);
    }
    else
    {
        return (self.splashAD != nil && [self.splashAD isADReadyToShow]);
    }
}

- (void)showAdInWindow:(UIWindow *)window bottomView:(UIView *)bottomView
{
    if(self.isBidding)
    {
        [self.splashAD showBiddingADInKeyWindow:window customView:bottomView];
    }
    else
    {
        [self.splashAD showInKeyWindow:window customView:bottomView];
    }
}

#pragma mark - MTGSplashADDelegate

- (void)splashADPreloadSuccess:(MTGSplashAD *)splashAD
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}
- (void)splashADPreloadFail:(MTGSplashAD *)splashAD error:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFailWithError:error];
}
- (void)splashADLoadSuccess:(MTGSplashAD *)splashAD
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    
}
- (void)splashADLoadFail:(MTGSplashAD *)splashAD error:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    
}
- (void)splashADShowSuccess:(MTGSplashAD *)splashAD
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}
- (void)splashADShowFail:(MTGSplashAD *)splashAD error:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShowFailWithError:error];
}
- (void)splashADDidLeaveApplication:(MTGSplashAD *)splashAD
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
- (void)splashADDidClick:(MTGSplashAD *)splashAD
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}
- (void)splashADWillClose:(MTGSplashAD *)splashAD
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
- (void)splashADDidClose:(MTGSplashAD *)splashAD
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}
- (void)splashAD:(MTGSplashAD *)splashAD timeLeft:(NSUInteger)time
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)splashZoomOutADViewDidShow:(MTGSplashAD *)splashAD
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_splash_zoom_show" info:nil];
}

- (void)splashZoomOutADViewClosed:(MTGSplashAD *)splashAD
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_splash_zoom_close" info:nil];
}
@end
