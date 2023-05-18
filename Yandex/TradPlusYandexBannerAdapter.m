#import "TradPlusYandexBannerAdapter.h"
#import <YandexMobileAds/YandexMobileAds.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSLogging.h>
#import "TPYandexAdapterBaseInfo.h"
#import "TradPlusYandexSDKSetting.h"

@interface TradPlusYandexBannerAdapter()<YMAAdViewDelegate>

@property (nonatomic, strong) YMAAdView *adView;
@property (nonatomic, strong) YMABidderTokenLoader *loader;
@property (nonatomic, assign) BOOL useBannerSize;
@end

@implementation TradPlusYandexBannerAdapter

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

- (CGSize)getAdSize
{
    CGFloat width = [self.waterfallItem.ad_size_info[@"X"] floatValue];
    CGFloat height = [self.waterfallItem.ad_size_info[@"Y"] floatValue];
    switch (self.waterfallItem.ad_size)
    {
        case 2:
        {
            if(width == 0)
                width = 300;
            if(height == 0)
                height = 250;
            break;
        }
        case 3:
        {
            if(width == 0)
                width = 320;
            if(height == 0)
                height = 100;
            break;
        }
        case 4:
        {
            if(width == 0)
                width = 320;
            if(height == 0)
                height = 50;
            break;
        }
        case 5:
        {
            if(width == 0)
                width = 400;
            if(height == 0)
                height = 240;
            break;
        }
        case 6:
        {
            if(width == 0)
                width = 728;
            if(height == 0)
                height = 90;
            break;
        }
        default:
        {
            if(width == 0)
                width = 240;
            if(height == 0)
                height = 400;
            break;
        }
    }
    return CGSizeMake(width, height);;
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
    
    CGSize viewSize = [self getAdSize];
    
    if(self.waterfallItem.bannerSize.width > 0
       && self.waterfallItem.bannerSize.height > 0)
    {
        self.useBannerSize = YES;
        viewSize.width = self.waterfallItem.bannerSize.width;
        viewSize.height = self.waterfallItem.bannerSize.height;
    }
    
    YMAAdSize *adSize = [YMAAdSize flexibleSizeWithCGSize:viewSize];
    self.adView = [[YMAAdView alloc] initWithAdUnitID:placementId adSize:adSize];
    self.adView.frame = CGRectMake(0, 0, viewSize.width, viewSize.height);
    self.adView.delegate = self;
    NSString *bidToken = nil;
    if(item.adsourceplacement != nil)
    {
        bidToken = item.adsourceplacement.adm;
    }
    if(bidToken == nil)
    {
        [self.adView loadAd];
    }
    else
    {
        YMAMutableAdRequest *request = [[YMAMutableAdRequest alloc] init];
        request.biddingData = bidToken;
        [self.adView loadAdWithRequest:request];
    }
}

- (BOOL)isReady
{
    return (self.adView != nil);
}

- (id)getCustomObject
{
    return self.adView;
}

- (void)bannerDidAddSubView:(UIView *)subView
{
    if(!self.useBannerSize)
    {
        CGRect rect = self.adView.frame;
        rect.size.width = subView.bounds.size.width;
        self.adView.frame = rect;
    }
    [self setBannerCenterWithBanner:self.adView subView:subView];
}


#pragma mark - YMAAdViewDelegate
- (nullable UIViewController *)viewControllerForPresentingModalView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    return self.waterfallItem.bannerRootViewController;
}

- (void)adViewDidLoad:(YMAAdView *)adView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)adViewDidClick:(YMAAdView *)adView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)adView:(YMAAdView *)adView didTrackImpressionWithData:(nullable id<YMAImpressionData>)impressionData
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)adViewDidFailLoading:(YMAAdView *)adView error:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}
@end
