#import "TradPlusYandexNativeAdapter.h"
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSLogging.h>
#import <YandexMobileAds/YandexMobileAds.h>
#import "TPYandexAdapterBaseInfo.h"
#import "TradPlusYandexSDKSetting.h"

@interface TradPlusYandexNativeAdapter()<YMANativeAdLoaderDelegate, YMANativeAdDelegate>

@property (nonatomic, strong) YMANativeAdLoader *adLoader;
@property (nonatomic, strong) YMANativeAdView *nativeAdView;
@property (nonatomic, strong) YMABidderTokenLoader *loader;
@property (nonatomic, strong) id<YMANativeAd> nativeAd;
@property (nonatomic, assign) BOOL isNativeBanner;

@end

@implementation TradPlusYandexNativeAdapter

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
    else if([event isEqualToString:@"S2SBidding"])
    {
        [self getBiddingToken];
    }
    else
    {
        return NO;
    }
    return YES;
}

- (void)getBiddingToken
{
    [TradPlusYandexSDKSetting showAdapterInfo];
    self.loader = [[YMABidderTokenLoader alloc] init];
    __weak typeof(self) weakSelf = self;
    [self.loader loadBidderTokenWithCompletionHandler:^(NSString * _Nullable bidderToken) {
        if(bidderToken == nil)
        {
            bidderToken = @"";
        }
        NSString *version = [YMAMobileAds SDKVersion];
        if(version == nil)
        {
           version = @"";
        }
        NSDictionary *dic = @{@"token":bidderToken,@"version":version};
        [weakSelf ADLoadExtraCallbackWithEvent:@"S2SBiddingFinish" info:dic];
    }];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_YandexAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [YMAMobileAds SDKVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_YandexAdapter_PlatformSDK_Version
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
    [TradPlusYandexSDKSetting setPrivacy];
    self.waterfallItem.nativeType = TPNativeADTYPE_Feed;
    if(item.secType == 2)
    {
        self.isNativeBanner = YES;
    }
    NSString *bidToken = nil;
    if(self.waterfallItem.adsourceplacement != nil)
    {
        bidToken = self.waterfallItem.adsourceplacement.adm;
    }
    self.adLoader = [[YMANativeAdLoader alloc] init];
    self.adLoader.delegate = self;
    YMAMutableNativeAdRequestConfiguration *requestConfig = [[YMAMutableNativeAdRequestConfiguration alloc] initWithAdUnitID:placementId];
    if (bidToken)
    {
        requestConfig.biddingData = bidToken;
    }
    [self.adLoader loadAdWithRequestConfiguration:requestConfig];
}

- (BOOL)isReady
{
    return self.nativeAd != nil;
}

- (id)getCustomObject
{
    return self.nativeAd;
}

- (UIView *)endRender:(NSDictionary *)viewInfo clickView:(NSArray *)array
{
    self.nativeAdView = [[YMANativeAdView alloc] init];
    if([viewInfo valueForKey:kTPRendererAdView])
    {
        UIView *view = viewInfo[kTPRendererAdView];
        self.nativeAdView.frame = view.bounds;
        [self.nativeAdView addSubview:view];
    }
    if([viewInfo valueForKey:kTPRendererTitleLable])
    {
        UILabel *view = viewInfo[kTPRendererTitleLable];
        view.text = @"";
        UILabel *label = [[UILabel alloc] initWithFrame:view.frame];
        label.textColor = view.textColor;
        label.font = view.font;
        self.nativeAdView.titleLabel = label;
        [self.nativeAdView addSubview:self.nativeAdView.titleLabel];
    }
    if([viewInfo valueForKey:kTPRendererTextLable])
    {
        UILabel *view = viewInfo[kTPRendererTextLable];
        view.text = @"";
        UILabel *label = [[UILabel alloc] initWithFrame:view.frame];
        label.textColor = view.textColor;
        label.font = view.font;
        self.nativeAdView.bodyLabel = label;
        [self.nativeAdView addSubview:self.nativeAdView.bodyLabel];
    }
    if([viewInfo valueForKey:kTPRendererCtaLabel])
    {
        UILabel *ctaLabel = viewInfo[kTPRendererCtaLabel];
        ctaLabel.text = @"";
        UIButton *button = [[UIButton alloc] initWithFrame:ctaLabel.frame];
        [button setTitleColor:ctaLabel.textColor forState:UIControlStateNormal];
        self.nativeAdView.callToActionButton = button;
        [self.nativeAdView addSubview:self.nativeAdView.callToActionButton];
    }
    if([viewInfo valueForKey:kTPRendererIconView])
    {
        UIImageView *view = viewInfo[kTPRendererIconView];
        self.nativeAdView.iconImageView = [[UIImageView alloc] initWithFrame:view.frame];
        [self.nativeAdView addSubview:self.nativeAdView.iconImageView];
    }
    
    if([viewInfo valueForKey:kTPRendererMainImageView])
    {
        UIView *view = viewInfo[kTPRendererMainImageView];
        self.nativeAdView.mediaView = [[YMANativeMediaView alloc] initWithFrame:view.frame];
        [self.nativeAdView addSubview:self.nativeAdView.mediaView];
    }
    else if([viewInfo valueForKey:kTPRendererMediaView])
    {
        UIView *view = viewInfo[kTPRendererMediaView];
        self.nativeAdView.mediaView = [[YMANativeMediaView alloc] initWithFrame:view.frame];
        [self.nativeAdView addSubview:self.nativeAdView.mediaView];
    }
    
    if([viewInfo valueForKey:kTPRendererAdChoiceImageView])
    {
        UIImageView *view = viewInfo[kTPRendererAdChoiceImageView];
        self.nativeAdView.faviconImageView = [[UIImageView alloc] initWithFrame:view.frame];
        [self.nativeAdView addSubview:self.nativeAdView.faviconImageView];
    }
    
    self.nativeAdView.sponsoredLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    self.nativeAdView.sponsoredLabel.textColor = [UIColor clearColor];
    [self.nativeAdView insertSubview:self.nativeAdView.sponsoredLabel atIndex:0];
    self.nativeAdView.warningLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    [self.nativeAdView insertSubview:self.nativeAdView.warningLabel atIndex:0];
    self.nativeAdView.warningLabel.textColor = [UIColor clearColor];
    
    self.nativeAdView.domainLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    self.nativeAdView.domainLabel.textColor = [UIColor clearColor];
    [self.nativeAdView insertSubview:self.nativeAdView.domainLabel atIndex:0];
    
    self.nativeAdView.ageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    self.nativeAdView.ageLabel.textColor = [UIColor clearColor];
    [self.nativeAdView insertSubview:self.nativeAdView.ageLabel atIndex:0];
    
    self.nativeAdView.priceLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    self.nativeAdView.priceLabel.textColor = [UIColor clearColor];
    [self.nativeAdView insertSubview:self.nativeAdView.priceLabel atIndex:0];
    
    self.nativeAdView.reviewCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    self.nativeAdView.reviewCountLabel.textColor = [UIColor clearColor];
    [self.nativeAdView insertSubview:self.nativeAdView.reviewCountLabel atIndex:0];
    
    self.nativeAdView.feedbackButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    self.nativeAdView.feedbackButton.backgroundColor = [UIColor clearColor];
    [self.nativeAdView.feedbackButton setTitleColor:[UIColor clearColor] forState:UIControlStateNormal];
    [self.nativeAdView insertSubview:self.nativeAdView.feedbackButton atIndex:0];
    
    NSError *error = nil;
    [self.nativeAd bindWithAdView:self.nativeAdView error:&error];
    if(error != nil)
    {
        MSLogInfo(@"Yandex native render error : %@",error);
        return nil;
    }
    return self.nativeAdView;
}

#pragma mark - YMANativeAdLoaderDelegate
- (void)nativeAdLoader:(YMANativeAdLoader *)loader didLoadAd:(id<YMANativeAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.nativeAd = ad;
    ad.delegate = self;
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    res.body = ad.adAssets.body;
    res.ctaText = ad.adAssets.callToAction;
    res.rating = ad.adAssets.rating;
    res.title = ad.adAssets.title;
    res.price = ad.adAssets.price;
    res.domain = ad.adAssets.domain;
    res.sponsored = ad.adAssets.sponsored;
    if(!self.isNativeBanner)
    {
        res.mediaView = [[UIView alloc] init];
    }
    self.waterfallItem.adRes = res;
    MSLogTrace(@"Yandex.rating--%@",res.rating);
    [self AdLoadFinsh];
}

- (void)nativeAdLoader:(YMANativeAdLoader *)loader didFailLoadingWithError:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

#pragma mark - YMANativeAdDelegate
- (nullable UIViewController *)viewControllerForPresentingModalView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    UIViewController *viewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (viewController != nil && viewController.presentedViewController != nil)
    {
        viewController = viewController.presentedViewController;
    }
    return viewController;
}

- (void)nativeAd:(id<YMANativeAd>)ad didTrackImpressionWithData:(nullable id<YMAImpressionData>)impressionData
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)nativeAdDidClick:(id<YMANativeAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)closeNativeAd:(id<YMANativeAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}
@end
