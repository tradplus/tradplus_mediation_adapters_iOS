#import "TradPlusMyTargetNativeAdapter.h"
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSLogging.h>
#import <MyTargetSDK/MyTargetSDK.h>
#import "TPMyTargetAdapterBaseInfo.h"
#import "TradPlusMyTargetSDKSetting.h"

@interface TradPlusMyTargetNativeAdapter()<MTRGNativeAdDelegate,MTRGNativeBannerAdDelegate>

@property (nonatomic, assign) BOOL isNativeBanner;
@property (nonatomic, strong) MTRGNativeAd *nativeAd;
@property (nonatomic, strong) MTRGNativeBanner *nativeBanner;
@property (nonatomic, strong) MTRGNativeBannerAd *nativeBannerAd;
@property (nonatomic, strong) MTRGIconAdView *iconAdView;
@property (nonatomic, strong) MTRGMediaAdView *mediaView;
@end

@implementation TradPlusMyTargetNativeAdapter

#pragma mark - Extra
- (BOOL)extraActWithEvent:(NSString *)event info:(NSDictionary *)config
{
    if([event isEqualToString:@"AdapterVersion"])
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

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_MyTargetAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [MTRGVersion currentVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_MyTargetAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *slotId = item.config[@"slot_id"];
    if(slotId == nil)
    {
        [self AdConfigError];
        return;
    }
    
    [TradPlusMyTargetSDKSetting setPrivacy];
    
    self.waterfallItem.nativeType = TPNativeADTYPE_Feed;
    if(item.secType  == 2)
    {
        self.isNativeBanner = YES;
    }
    NSString *bidToken = nil;
    if(item.adsourceplacement != nil)
    {
        bidToken = item.adsourceplacement.adm;
    }
    if(!self.isNativeBanner)
    {
        self.nativeAd = [MTRGNativeAd nativeAdWithSlotId:[slotId integerValue]];
        self.nativeAd.delegate = self;
        if(bidToken == nil)
        {
            [self.nativeAd load];
        }
        else
        {
            [self.nativeAd loadFromBid:bidToken];
        }
    }
    else
    {
        self.nativeBannerAd = [MTRGNativeBannerAd nativeBannerAdWithSlotId:[slotId integerValue]];
        self.nativeBannerAd.delegate = self;
        if (bidToken == nil)
        {
            [self.nativeBannerAd load];
        }
        else
        {
            [self.nativeBannerAd loadFromBid:bidToken];
        }
    }
}

- (BOOL)isReady
{
    return (self.nativeBanner != nil);
}

- (id)getCustomObject
{
    if(!self.isNativeBanner)
    {
        return self.nativeAd;
    }
    else
    {
        return self.nativeBannerAd;
    }
}

- (UIView *)endRender:(NSDictionary *)viewInfo clickView:(NSArray *)array
{
    UIView *adView = [viewInfo valueForKey:kTPRendererAdView];
    MTRGNativeAdContainer * nativeAdContainer = [MTRGNativeAdContainer createWithAdView:adView];
    nativeAdContainer.frame = adView.bounds;
    
    if([viewInfo valueForKey:kTPRendererTitleLable])
    {
        UIView *view = viewInfo[kTPRendererTitleLable];
        nativeAdContainer.titleView = view;
    }
    if([viewInfo valueForKey:kTPRendererTextLable])
    {
        UIView *view = viewInfo[kTPRendererTextLable];
        nativeAdContainer.descriptionView = view;
    }
    if([viewInfo valueForKey:kTPRendererCtaLabel])
    {
        UIView *view = viewInfo[kTPRendererCtaLabel];
        nativeAdContainer.ctaView = view;
    }
    nativeAdContainer.iconView = self.iconAdView;
    if(!self.isNativeBanner && self.mediaView != nil)
    {
        nativeAdContainer.mediaView = self.mediaView;
    }
    if(!self.isNativeBanner)
    {
        [self.nativeAd registerView:nativeAdContainer withController:self.rootViewController];
    }
    else
    {
        [self.nativeBannerAd registerView:nativeAdContainer withController:self.rootViewController];
    }
    return nativeAdContainer;
}

#pragma mark - MTRGNativeAdDelegate
- (void)onLoadWithNativePromoBanner:(MTRGNativePromoBanner *)promoBanner nativeAd:(MTRGNativeAd *)nativeAd
{
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    res.title = promoBanner.title;
    res.body = promoBanner.descriptionText;
    res.ctaText = promoBanner.ctaText;
    res.rating = promoBanner.rating;
    res.advertisingLabel = promoBanner.advertisingLabel;
    res.ageRestrictions = promoBanner.ageRestrictions;
    res.disclaimer = promoBanner.disclaimer;
    res.category = promoBanner.category;
    res.subcategory = promoBanner.subcategory;
    res.domain = promoBanner.domain;
    res.votes = promoBanner.votes;
    self.iconAdView = [MTRGNativeViewsFactory createIconAdView];
    res.iconView = self.iconAdView;
    self.mediaView = [MTRGNativeViewsFactory createMediaAdView];
    res.mediaView = self.mediaView;
    self.nativeBanner = promoBanner;
    self.waterfallItem.adRes = res;
    [self AdLoadFinsh];
}


- (void)onNoAdWithReason:(NSString *)reason nativeAd:(MTRGNativeAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSError *error = [NSError errorWithDomain:@"MyTarget No Ad" code:400 userInfo:@{NSLocalizedDescriptionKey:reason}];
    [self AdLoadFailWithError:error];
}

- (void)onAdShowWithNativeAd:(MTRGNativeAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)onAdClickWithNativeAd:(MTRGNativeAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

#pragma mark - MTRGNativeBannerAdDelegate

- (void)onLoadWithNativeBanner:(MTRGNativeBanner *)banner nativeBannerAd:(MTRGNativeBannerAd *)nativeBannerAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    res.title = banner.title;
    res.body = banner.descriptionText;
    res.ctaText = banner.ctaText;
    res.rating = banner.rating;
    res.advertisingLabel = banner.advertisingLabel;
    res.ageRestrictions = banner.ageRestrictions;
    res.disclaimer = banner.disclaimer;
    res.domain = banner.domain;
    res.votes = banner.votes;
    self.iconAdView = [MTRGNativeViewsFactory createIconAdView];
    res.iconView = self.iconAdView;
    self.nativeBanner = banner;
    self.waterfallItem.adRes = res;
    [self AdLoadFinsh];
}



- (void)onNoAdWithReason:(NSString *)reason nativeBannerAd:(MTRGNativeBannerAd *)nativeBannerAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSError *error = [NSError errorWithDomain:@"MyTarget No Ad" code:400 userInfo:@{NSLocalizedDescriptionKey:reason}];
    [self AdLoadFailWithError:error];
}

- (void)onAdShowWithNativeBannerAd:(MTRGNativeBannerAd *)nativeBannerAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)onAdClickWithNativeBannerAd:(MTRGNativeBannerAd *)nativeBannerAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}
@end
