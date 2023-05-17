#import "TradPlusAdMobNativeAdapter.h"
#import "TPGoogleAdMobAdapterConfig.h"
#import <GoogleMobileAds/GoogleMobileAds.h>
#import <TradPlusAds/MSConsentManager.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSLogging.h>
#import "TPAdMobAdapterBaseInfo.h"

@interface TradPlusAdMobNativeAdapter()<GADAdLoaderDelegate,GADNativeAdLoaderDelegate,GADNativeAdDelegate>

@property (nonatomic,strong)GADAdLoader *adLoader;
@property (nonatomic,strong)GADNativeAd *nativeAd;
@property (nonatomic,strong)GADMediaView *mediaView;
@property (nonatomic,assign)BOOL isNativeBanner;
@end

@implementation TradPlusAdMobNativeAdapter

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

//版本号
- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_AdMobAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

//三方SDK版本号
- (void)platformSDKVersionCallback
{
    NSString *version = [NSString stringWithFormat:@"%s",GoogleMobileAdsVersionString];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_AdMobAdapter_PlatformSDK_Version
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
    self.waterfallItem.nativeType = TPNativeADTYPE_Feed;
    if(item.secType == 2)
    {
        self.isNativeBanner = YES;
    }
    [TPGoogleAdMobAdapterConfig setPrivacy:@{}];
    GADRequest *request = [GADRequest request];
    
    GADNativeAdViewAdOptions *nativeAdViewAdOptions = [[GADNativeAdViewAdOptions alloc] init];
    GADAdChoicesPosition pos = [[NSUserDefaults standardUserDefaults] integerForKey:@"AdMobAdChoicesPosition"];
    
    if(self.waterfallItem.extraInfoDictionary != nil
       && [self.waterfallItem.extraInfoDictionary valueForKey:@"localParams"])
    {
        id localParams = self.waterfallItem.extraInfoDictionary[@"localParams"];
        if([localParams isKindOfClass:[NSDictionary class]])
        {
            if([localParams valueForKey:@"google_neighboring_contenturls"])
            {
                id neighboringContentURLStrings = localParams[@"google_neighboring_contenturls"];
                if([neighboringContentURLStrings isKindOfClass:[NSArray class]])
                {
                    NSArray *urlStrings = neighboringContentURLStrings;
                    if(urlStrings.count == 1)
                    {
                        MSLogTrace(@"set request.contentURL = %@",urlStrings.firstObject);
                        request.contentURL = urlStrings.firstObject;
                    }
                    else if(urlStrings.count > 1)
                    {
                        MSLogTrace(@"set request.neighboringContentURLStrings = %@",urlStrings);
                        request.neighboringContentURLStrings = urlStrings;
                    }
                }
            }
            
            if([localParams valueForKey:@"adchoices_position"])
            {
                id position = localParams[@"adchoices_position"];
                if([position isKindOfClass:[NSNumber class]])
                {
                    pos = [position integerValue];
                }
            }
        }
    }
    
    nativeAdViewAdOptions.preferredAdChoicesPosition = pos;
    request.requestAgent = @"TradPlus";
    if (![MSConsentManager sharedManager].canCollectPersonalInfo
        || !gTPOpenPersonalizedAd)
    {
        MSLogTrace(@"***********");
        MSLogTrace(@"admob non-personalized ads");
        MSLogTrace(@"***********");
        GADExtras *extras = [[GADExtras alloc] init];
        extras.additionalParameters = @{@"npa": @"1"};
        [request registerAdNetworkExtras:extras];
    }
    
    GADMediaAspectRatio mediaAspectRatio = GADMediaAspectRatioUnknown;
    switch (self.waterfallItem.ad_size)
    {
        case 2:
        {
            mediaAspectRatio = GADMediaAspectRatioAny;
            break;
        }
        case 3:
        {
            mediaAspectRatio = GADMediaAspectRatioLandscape;
            break;
        }
        case 4:
        {
            mediaAspectRatio = GADMediaAspectRatioPortrait;
            break;
        }
        case 5:
        {
            mediaAspectRatio = GADMediaAspectRatioSquare;
            break;
        }
    }
    
    GADNativeAdImageAdLoaderOptions *nativeAdImageLoaderOptions =
          [[GADNativeAdImageAdLoaderOptions alloc] init];
    nativeAdImageLoaderOptions.shouldRequestMultipleImages = NO;
        
    GADNativeAdMediaAdLoaderOptions *nativeAdMediaAdLoaderOptions =
        [[GADNativeAdMediaAdLoaderOptions alloc] init];
    nativeAdMediaAdLoaderOptions.mediaAspectRatio = mediaAspectRatio;

    self.adLoader =
          [[GADAdLoader alloc] initWithAdUnitID:placementId
                             rootViewController:nil
                                        adTypes:@[ GADAdLoaderAdTypeNative ]
                                        options:@[ nativeAdImageLoaderOptions, nativeAdViewAdOptions, nativeAdMediaAdLoaderOptions ]];
    self.adLoader.delegate = self;
      
    [self.adLoader loadRequest:request];
}

- (id)getCustomObject
{
    return self.nativeAd;
}

- (BOOL)isReady
{
    return (self.nativeAd != nil);
}

- (UIView *)endRender:(NSDictionary *)viewInfo clickView:(NSArray *)array
{
    GADNativeAdView *nativeAdView = [[GADNativeAdView alloc] init];
    nativeAdView.nativeAd = self.nativeAd;
    if([viewInfo valueForKey:kTPRendererAdView])
    {
        UIView *view = viewInfo[kTPRendererAdView];
        nativeAdView.frame = view.bounds;
        [nativeAdView addSubview:view];
    }
    if([viewInfo valueForKey:kTPRendererTitleLable])
    {
        UIView *view = viewInfo[kTPRendererTitleLable];
        nativeAdView.headlineView = view;
    }
    if([viewInfo valueForKey:kTPRendererTextLable])
    {
        UIView *view = viewInfo[kTPRendererTextLable];
        nativeAdView.bodyView = view;
    }
    if([viewInfo valueForKey:kTPRendererCtaLabel])
    {
        UIView *view = viewInfo[kTPRendererCtaLabel];
        nativeAdView.callToActionView = view;
    }
    if([viewInfo valueForKey:kTPRendererIconView])
    {
        UIView *view = viewInfo[kTPRendererIconView];
        nativeAdView.iconView = view;
    }
    if(self.mediaView != nil)
    {
        nativeAdView.mediaView = self.mediaView;
    }
    return nativeAdView;
}

#pragma mark - GADAdLoaderDelegate
- (void)adLoader:(nonnull GADAdLoader *)adLoader
    didFailToReceiveAdWithError:(nonnull NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

#pragma mark - GADNativeAdLoaderDelegate
- (void)adLoader:(nonnull GADAdLoader *)adLoader didReceiveNativeAd:(nonnull GADNativeAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.nativeAd = nativeAd;
    self.nativeAd.delegate = self;
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    res.title = self.nativeAd.headline;
    res.body = self.nativeAd.body;
    res.ctaText = self.nativeAd.callToAction;
    res.rating = self.nativeAd.starRating;
    res.store = self.nativeAd.store;
    res.price = self.nativeAd.price;
    res.advertiser = self.nativeAd.advertiser;
    if(self.nativeAd.icon != nil)
    {
        if(self.nativeAd.icon.image != nil)
        {
            res.iconImage = self.nativeAd.icon.image;
        }
        else if(self.nativeAd.icon.imageURL != nil)
        {
            res.iconImageURL = self.nativeAd.icon.imageURL.absoluteString;
            if(res.iconImageURL != nil)
            {
                [self.downLoadURLArray addObject:res.iconImageURL];
            }
        }
    }
    if(!self.isNativeBanner)
    {
        self.mediaView = [[GADMediaView alloc] init];
        self.mediaView.mediaContent = self.nativeAd.mediaContent;
        res.mediaView = self.mediaView;
    }
    self.waterfallItem.adRes = res;
    
    __weak typeof(self) weakSelf = self;
    self.nativeAd.paidEventHandler = ^void(GADAdValue *_Nonnull value){
        NSString *imp_ecpm = [NSString stringWithFormat:@"%@",value.value];
        NSString *imp_currency = value.currencyCode;
        NSString *imp_precision = [NSString stringWithFormat:@"%@",@(value.precision)];
        weakSelf.waterfallItem.extraInfoDictionary[@"imp_ecpm"] = imp_ecpm;
        weakSelf.waterfallItem.extraInfoDictionary[@"imp_currency"] = imp_currency;
        weakSelf.waterfallItem.extraInfoDictionary[@"imp_precision"] = imp_precision;
        [weakSelf ADShowExtraCallbackWithEvent:@"tradplus_imp_show1310" info:nil];
    };
    
    [self AdLoadFinsh];
}

#pragma mark - GADNativeAdDelegate

- (void)nativeAdDidRecordImpression:(nonnull GADNativeAd *)nativeAd;
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)nativeAdDidRecordClick:(nonnull GADNativeAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}
@end
