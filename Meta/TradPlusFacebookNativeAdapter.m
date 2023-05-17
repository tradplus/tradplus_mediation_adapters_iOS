#import "TradPlusFacebookNativeAdapter.h"
#import <FBAudienceNetwork/FBAudienceNetwork.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import "TPFacebookAdapterConfig.h"
#import "TPFacebookAdapterBaseInfo.h"

@interface TradPlusFacebookNativeAdapter()<FBNativeAdDelegate,FBNativeBannerAdDelegate>

@property (nonatomic,assign)BOOL isNativeBanner;
@property (nonatomic,strong)FBNativeAd *nativeAd;
@property (nonatomic,strong)FBNativeAdView *nativeAdView;
@property (nonatomic,strong)FBMediaView *mediaView;
@property (nonatomic,strong)FBMediaView *iconView;
@property (nonatomic,strong)FBAdOptionsView *adChoiceView;
@property (nonatomic,strong)FBNativeBannerAd *nativeBannerAd;
@property (nonatomic,assign)BOOL isTemplateRender;
@property (nonatomic,strong)FBNativeBannerAdView *bannerAdView;
@end

@implementation TradPlusFacebookNativeAdapter

- (void)dealloc
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

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
    NSDictionary *dic = @{@"version":TP_FacebookAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = FB_AD_SDK_VERSION;
    if(version == nil)
    {
       version = @"";
    }
    NSDictionary *dic = @{
       @"version":version,
       @"adaptedVersion":TP_FacebookAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *placementId = item.config[@"placementId"];
    if(placementId == nil)
    {
        [self AdConfigError];
        return;
    }
    [TPFacebookAdapterConfig setPrivacy:@{}];
    if(item.secType  == 2)
    {
        self.isNativeBanner = YES;
    }
    NSString *bidToken = nil;
    if(item.adsourceplacement != nil)
    {
        bidToken = item.adsourceplacement.adm;
    }
    self.waterfallItem.nativeType = TPNativeADTYPE_Feed;
    if(item.is_template_rendering != 2)
    {
        self.waterfallItem.nativeType = TPNativeADTYPE_Template;
        self.isTemplateRender = YES;
    }
    if(!self.isNativeBanner)
    {
        self.nativeAd = [[FBNativeAd alloc] initWithPlacementID:placementId];
        self.nativeAd.delegate = self;
        if(bidToken == nil)
        {
            [self.nativeAd loadAd];
        }
        else
        {
            [self.nativeAd loadAdWithBidPayload:bidToken];
        }
    }
    else
    {
        self.nativeBannerAd = [[FBNativeBannerAd alloc] initWithPlacementID:placementId];
        self.nativeBannerAd.delegate = self;
        if(bidToken == nil)
        {
            [self.nativeBannerAd loadAd];
        }
        else
        {
            [self.nativeBannerAd loadAdWithBidPayload:bidToken];
        }
    }
}

- (BOOL)isReady
{
    if(!self.isNativeBanner)
    {
        return (self.nativeAd != nil);
    }
    else
    {
        return (self.nativeBannerAd != nil);
    }
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
    UIView *adView = viewInfo[kTPRendererAdView];
    if(!self.nativeBannerAd)
    {
        [self.nativeAd registerViewForInteraction:adView
                                        mediaView:self.mediaView
                                         iconView:self.iconView
                                   viewController:self.rootViewController
                                   clickableViews:array];
    }
    else
    {
        [self.nativeBannerAd registerViewForInteraction:adView
                                               iconView:self.iconView
                                         viewController:self.rootViewController
                                         clickableViews:array];
    }
    return nil;
}


- (void)templateRender:(UIView *)subView
{
    if(self.isNativeBanner)
    {
        CGRect rect = self.bannerAdView.bounds;
        rect.size.width = subView.bounds.size.width;
        self.bannerAdView.frame = rect;
    }
    else if(self.isTemplateRender)
    {
        self.nativeAdView.frame = subView.bounds;
    }
}

#pragma mark - FBNativeAdDelegate
- (void)nativeAdDidLoad:(FBNativeAd *)nativeAd
{
    if(self.nativeAd && self.nativeAd.isAdValid)
    {
        [self.nativeAd unregisterView];
    }
    self.nativeAd = nativeAd;
    
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    if(self.isTemplateRender)
    {
        self.nativeAdView = [FBNativeAdView nativeAdViewWithNativeAd:self.nativeAd];
        res.adView = self.nativeAdView;
    }
    else
    {
        res.title = self.nativeAd.headline;
        res.body = self.nativeAd.bodyText;
        res.ctaText = self.nativeAd.callToAction;
        self.mediaView = [[FBMediaView alloc] init];
        res.mediaView = self.mediaView;
        self.iconView = [[FBMediaView alloc] init];
        res.iconView = self.iconView;
        self.adChoiceView = [[FBAdOptionsView alloc] init];
        self.adChoiceView.backgroundColor = [UIColor clearColor];
        self.adChoiceView.nativeAd = self.nativeAd;
        res.adChoiceView = self.adChoiceView;
        
        res.socialContext = self.nativeAd.socialContext;
        res.linkDescription = self.nativeAd.linkDescription;
        res.advertiser = self.nativeAd.advertiserName;
        res.rawBodyText = self.nativeAd.rawBodyText;
        res.sponsored = self.nativeAd.sponsoredTranslation;
        res.adTranslation = self.nativeAd.adTranslation;
        res.promotedTranslation = self.nativeAd.promotedTranslation;
    }
    self.waterfallItem.adRes = res;
    [self AdLoadFinsh];
}

- (void)nativeAd:(FBNativeAd *)nativeAd didFailWithError:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

- (void)nativeAdWillLogImpression:(FBNativeAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)nativeAdDidClick:(FBNativeAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

#pragma mark - FBNativeBannerAdDelegate

- (void)nativeBannerAdDidLoad:(FBNativeBannerAd *)nativeBannerAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.nativeBannerAd && self.nativeBannerAd.isAdValid)
    {
        [self.nativeBannerAd unregisterView];
    }
    self.nativeBannerAd = nativeBannerAd;
    
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    
    if(!self.isTemplateRender)
    {
        res.title = self.nativeBannerAd.headline;
        res.body = self.nativeBannerAd.bodyText;
        res.ctaText = self.nativeBannerAd.callToAction;
        
        self.iconView = [[FBMediaView alloc] init];
        res.iconView = self.iconView;
        
        self.adChoiceView = [[FBAdOptionsView alloc] init];
        self.adChoiceView.backgroundColor = [UIColor clearColor];
        self.adChoiceView.nativeAd = self.nativeBannerAd;
        res.adChoiceView = self.adChoiceView;
        
        res.socialContext = self.nativeBannerAd.socialContext;
        res.linkDescription = self.nativeBannerAd.linkDescription;
        res.advertiser = self.nativeBannerAd.advertiserName;
        res.rawBodyText = self.nativeBannerAd.rawBodyText;
        res.sponsored = self.nativeBannerAd.sponsoredTranslation;
        res.adTranslation = self.nativeBannerAd.adTranslation;
        res.promotedTranslation = self.nativeBannerAd.promotedTranslation;
    }
    else
    {
        FBNativeBannerAdViewType type = FBNativeBannerAdViewTypeGenericHeight100;
        CGFloat height = 100;
        if(self.waterfallItem.ad_size == 1)
        {
            type = FBNativeBannerAdViewTypeGenericHeight50;
            height = 50;
        }
        else if(self.waterfallItem.ad_size == 3)
        {
            type = FBNativeBannerAdViewTypeGenericHeight120;
            height = 120;
        }
        self.bannerAdView = [FBNativeBannerAdView nativeBannerAdViewWithNativeBannerAd:self.nativeBannerAd withType:type];
        CGRect rect = CGRectZero;
        rect.size = CGSizeMake(320, height);
        self.bannerAdView.frame = rect;
        res.adView = self.bannerAdView;
    }
    self.waterfallItem.adRes = res;
    [self AdLoadFinsh];
}

- (void)nativeBannerAdWillLogImpression:(FBNativeBannerAd *)nativeBannerAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}


- (void)nativeBannerAd:(FBNativeBannerAd *)nativeBannerAd didFailWithError:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}


- (void)nativeBannerAdDidClick:(FBNativeBannerAd *)nativeBannerAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}
@end
