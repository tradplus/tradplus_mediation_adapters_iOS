#import "TradPlusAdColonyBannerAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <AdColony/AdColony.h>
#import "TradPlusAdColonySDKLoader.h"
#import "TPAdColonyAdapterBaseInfo.h"

@interface TradPlusAdColonyBannerAdapter ()<AdColonyAdViewDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) AdColonyAdView *adView;
@property (nonatomic, copy) NSString *zoneId;
@end

@implementation TradPlusAdColonyBannerAdapter

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
    AdColonyAdSize adSize = [self getAdSize];
    if(self.waterfallItem.bannerSize.width > 0 && self.waterfallItem.bannerSize.height > 0)
    {
        adSize = AdColonyAdSizeFromCGSize(self.waterfallItem.bannerSize);
    }
    [AdColony requestAdViewInZone:self.zoneId
                         withSize:adSize
                   viewController:self.waterfallItem.bannerRootViewController
                      andDelegate:self];
}

- (AdColonyAdSize)getAdSize
{
    switch (self.waterfallItem.ad_size)
    {
        case 1:
            return kAdColonyAdSizeBanner;
        case 2:
            return kAdColonyAdSizeMediumRectangle;
        case 3:
            return kAdColonyAdSizeLeaderboard;
        case 4:
            return kAdColonyAdSizeSkyscraper;
        default:
        {
            CGFloat width = [self.waterfallItem.ad_size_info[@"X"] floatValue];
            CGFloat height = [self.waterfallItem.ad_size_info[@"Y"] floatValue];
            if(width == 0)
                width = 320;
            if(height == 0)
                height = 50;
            return AdColonyAdSizeMake(width, height);
        }
    }
}

- (void)bannerDidAddSubView:(UIView *)subView
{
    [self setBannerCenterWithBanner:self.adView subView:subView];
    [self AdShow];
}

- (void)adViewWillDestroy
{
    [self.adView destroy];
}

- (BOOL)isReady
{
    return (self.adView != nil);
}

- (id)getCustomObject
{
    return self.adView;
}

#pragma mark - AdColonyAdViewDelegate

- (void)adColonyAdViewDidLoad:(AdColonyAdView * _Nonnull)adView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.adView = adView;
    [self AdLoadFinsh];
}

- (void)adColonyAdViewDidFailToLoad:(AdColonyAdRequestError * _Nonnull)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

- (void)adColonyAdViewDidReceiveClick:(AdColonyAdView * _Nonnull)adView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

@end
