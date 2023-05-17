#import "TradPlusAdMobBannerAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSConsentManager.h>
#import <GoogleMobileAds/GoogleMobileAds.h>
#import "TPGoogleAdMobAdapterConfig.h"
#import "TPAdMobAdapterBaseInfo.h"

@interface TradPlusAdMobBannerAdapter ()<GADBannerViewDelegate>

@property (nonatomic,strong)GADBannerView *bannerView;
@property (nonatomic,assign)BOOL useBannerSize;
@end

@implementation TradPlusAdMobBannerAdapter

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
    NSDictionary *dic = @{@"version":TP_AdMobAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}


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
    [TPGoogleAdMobAdapterConfig setPrivacy:@{}];
    GADAdSize adSize = [self getAdSize];
    if(self.waterfallItem.bannerSize.width > 0
       && self.waterfallItem.bannerSize.height > 0
       && self.waterfallItem.id == NETWORK_ADMOB)
    {
        self.useBannerSize = YES;
        adSize = GADAdSizeFromCGSize(self.waterfallItem.bannerSize);
    }
    self.bannerView = [[GADBannerView alloc] initWithAdSize:adSize];
    self.bannerView.adUnitID = placementId;
    self.bannerView.rootViewController = self.waterfallItem.bannerRootViewController;
    self.bannerView.delegate = self;
    
    GADRequest *request = [GADRequest request];
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

    if(self.waterfallItem.extraInfoDictionary != nil
       && [self.waterfallItem.extraInfoDictionary valueForKey:@"localParams"])
    {
        id localParams = self.waterfallItem.extraInfoDictionary[@"localParams"];
        if([localParams isKindOfClass:[NSDictionary class]]
           && [localParams valueForKey:@"google_neighboring_contenturls"])
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
    }
    request.requestAgent = @"TradPlusAd";
    [self.bannerView loadRequest:request];
}

- (GADAdSize)getAdSize
{
    switch (self.waterfallItem.ad_size)
    {
        case 1:
            return GADAdSizeBanner;
        case 2:
            return GADAdSizeLargeBanner;
        case 3:
            return GADAdSizeMediumRectangle;
        case 4:
            return GADAdSizeFullBanner;
        case 5:
            return GADAdSizeLeaderboard;
        case 6:
        {
            CGFloat width = [self.waterfallItem.ad_size_info[@"X"] floatValue];
            if(width == 0)
                width = 320;
            return GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width);
        }
        default:
        {
            CGFloat width = [self.waterfallItem.ad_size_info[@"X"] floatValue];
            CGFloat height = [self.waterfallItem.ad_size_info[@"Y"] floatValue];
            if(width == 0)
                width = 320;
            if(height == 0)
                height = 50;
            CGSize size = CGSizeMake(width, height);
            return GADAdSizeFromCGSize(size);
        }
    }
}

- (void)bannerDidAddSubView:(UIView *)subView
{
    if(self.waterfallItem.ad_size == 6)
    {
        CGRect rect = self.bannerView.frame;
        rect.size = subView.bounds.size;
        self.bannerView.frame = rect;
    }
    else if(!self.useBannerSize && self.waterfallItem.id == NETWORK_ADMOB)
    {
        CGRect rect = self.bannerView.frame;
        rect.size.width = subView.bounds.size.width;
        self.bannerView.frame = rect;
    }
    [self setBannerCenterWithBanner:self.bannerView subView:subView];
    [self AdShow];
}

 
- (BOOL)isReady
{
    return (self.bannerView != nil);
}

- (id)getCustomObject
{
    return self.bannerView;
}

#pragma mark - GADBannerViewDelegate

- (void)bannerViewDidReceiveAd:(nonnull GADBannerView *)bannerView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    
    __weak typeof(self) weakSelf = self;
    self.bannerView.paidEventHandler = ^void(GADAdValue *_Nonnull value){
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

- (void)bannerView:(nonnull GADBannerView *)bannerView
    didFailToReceiveAdWithError:(nonnull NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

- (void)bannerViewDidRecordImpression:(nonnull GADBannerView *)bannerView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)bannerViewDidRecordClick:(nonnull GADBannerView *)bannerView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}
@end
