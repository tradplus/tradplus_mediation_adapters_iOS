#import "TradPlusMintegralBannerAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <MTGSDKBanner/MTGBannerAdView.h>
#import "TradPlusMintegralSDKLoader.h"
#import "TPMintegralAdapterBaseInfo.h"

@interface TradPlusMintegralBannerAdapter ()<MTGBannerAdViewDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong)MTGBannerAdView *bannerAdView;
@property (nonatomic,copy)NSString *placementId;
@property (nonatomic,copy)NSString *unitId;
@property (nonatomic,assign)BOOL useBannerSize;
@end

@implementation TradPlusMintegralBannerAdapter

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
    if(self.waterfallItem.bannerSize.width > 0
       && self.waterfallItem.bannerSize.height > 0)
    {
        self.useBannerSize = YES;
        self.bannerAdView = [[MTGBannerAdView alloc] initBannerAdViewWithAdSize:self.waterfallItem.bannerSize placementId:self.placementId unitId:self.unitId rootViewController:self.waterfallItem.bannerRootViewController];
    }
    else
    {
        MTGBannerSizeType sizeType = [self getAdSize];
        self.bannerAdView = [[MTGBannerAdView alloc] initBannerAdViewWithBannerSizeType:sizeType placementId:self.placementId unitId:self.unitId rootViewController:self.waterfallItem.bannerRootViewController];
    }
    self.bannerAdView.delegate = self;
    NSString *bidToken = nil;
    if(self.waterfallItem.adsourceplacement != nil)
    {
        bidToken = self.waterfallItem.adsourceplacement.adm;
    }
    if(bidToken == nil)
    {
        [self.bannerAdView loadBannerAd];
    }
    else
    {
        [self.bannerAdView loadBannerAdWithBidToken:bidToken];
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

- (MTGBannerSizeType)getAdSize
{
    switch (self.waterfallItem.ad_size)
    {
        case 2:
            return MTGLargeBannerType320x90;
        case 3:
            return MTGMediumRectangularBanner300x250;
        default:
            return MTGStandardBannerType320x50;
    }
}


- (void)bannerDidAddSubView:(UIView *)subView
{
    if(!self.useBannerSize)
    {
        CGRect rect = self.bannerAdView.frame;
        if(rect.origin.x > 0)
        {
            rect.origin.x = 0;
        }
        if(subView.bounds.size.width != 0)
        {
            rect.size.width = subView.bounds.size.width;
            rect.size.height = subView.bounds.size.height;
        }
        self.bannerAdView.frame = rect;
    }
    [self setBannerCenterWithBanner:self.bannerAdView subView:subView];
}

- (BOOL)isReady
{
    return (self.bannerAdView != nil);
}

- (id)getCustomObject
{
    return self.bannerAdView;
}

#pragma mark - MTGBannerAdViewDelegate

- (void)adViewLoadSuccess:(MTGBannerAdView *)adView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)adViewLoadFailedWithError:(NSError *)error adView:(MTGBannerAdView *)adView
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

- (void)adViewWillLogImpression:(MTGBannerAdView *)adView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}


- (void)adViewDidClicked:(MTGBannerAdView *)adView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)adViewClosed:(MTGBannerAdView *)adView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

- (void)adViewWillLeaveApplication:(MTGBannerAdView *)adView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)adViewWillOpenFullScreen:(MTGBannerAdView *)adView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)adViewCloseFullScreen:(MTGBannerAdView *)adView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

@end
