#import "TradPlusAppLovinBannerAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <AppLovinSDK/AppLovinSDK.h>
#import "TradPlusAppLovinSDKLoader.h"
#import "TPAppLovinAdapterBaseInfo.h"

@interface TradPlusAppLovinBannerAdapter ()<ALAdLoadDelegate,ALAdDisplayDelegate,ALAdViewEventDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong)ALAdView *adView;
@property (nonatomic,copy)NSString *placementId;
@property (nonatomic,assign)BOOL useBannerSize;
@end

@implementation TradPlusAppLovinBannerAdapter

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
    if(appId == nil || self.placementId == nil || appId.length <= 5)
    {
        [self AdConfigError];
        return;
    }
    
    [[TradPlusAppLovinSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

#pragma mark - TPSDKLoaderDelegate

- (void)tpInitFinish
{
    [self setupAdViewWithSDK:[TradPlusAppLovinSDKLoader sharedInstance].sdk];
}

- (void)tpInitFailWithError:(NSError *)error
{
    [self AdLoadFailWithError:error];
}

- (void)setupAdViewWithSDK:(ALSdk *)sdk
{
    ALAdSize *adSize = ALAdSize.banner;
    CGRect rect = CGRectZero;
    rect.size = CGSizeMake(320, 50);
    if(self.waterfallItem.ad_size == 3)
    {
        adSize = ALAdSize.leader;
        rect.size = CGSizeMake(728, 90);
    }
    else if(self.waterfallItem.ad_size == 2)
    {
        adSize = ALAdSize.mrec;
        rect.size = CGSizeMake(300, 250);
        if(self.waterfallItem.bannerSize.height > 0)
        {
            self.useBannerSize = YES;
            rect.size.height = self.waterfallItem.bannerSize.height;
        }
    }
    if(self.waterfallItem.bannerSize.width > 0)
    {
        self.useBannerSize = YES;
        rect.size.width = self.waterfallItem.bannerSize.width;
    }
    self.adView = [[ALAdView alloc] initWithSdk:sdk size:adSize zoneIdentifier:self.placementId];
    self.adView.frame = rect;
    self.adView.adLoadDelegate = self;
    self.adView.adDisplayDelegate = self;
    self.adView.adEventDelegate = self;
    [self.adView loadNextAd];
}

- (void)bannerDidAddSubView:(UIView *)subView
{
    if(!self.useBannerSize)
    {
        CGRect rect = self.adView.frame;
        rect.size.width = subView.bounds.size.width;
        if(self.waterfallItem.ad_size == 2)
        {
            rect.size.height = subView.bounds.size.height;
        }
        self.adView.frame = rect;
    }
    [self setBannerCenterWithBanner:self.adView subView:subView];
    [self AdShow];
}

- (BOOL)isReady
{
    return (self.adView != nil);
}

- (id)getCustomObject
{
    return self.adView;
}

#pragma mark - MAAdDelegate

- (void)adService:(ALAdService *)adService didLoadAd:(ALAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)adService:(ALAdService *)adService didFailToLoadAdWithError:(int)code
{
    MSLogTrace(@"%s %ld", __PRETTY_FUNCTION__,(long)code);
    NSError *loadError = [NSError errorWithDomain:@"AppLovin" code:code userInfo:@{NSLocalizedDescriptionKey:@"load fail"}];
    [self AdLoadFailWithError:loadError];
}

- (void)ad:(ALAd *)ad wasDisplayedIn:(UIView *)view
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)ad:(ALAd *)ad wasHiddenIn:(UIView *)view
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)ad:(ALAd *)ad wasClickedIn:(UIView *)view
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}
@end
