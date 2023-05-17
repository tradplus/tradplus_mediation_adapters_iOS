#import "TradPlusGAMBannerAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSConsentManager.h>
#import <GoogleMobileAds/GoogleMobileAds.h>
#import "TPGoogleAdMobAdapterConfig.h"
#import "TPAdMobAdapterBaseInfo.h"

@interface TradPlusGAMBannerAdapter ()<GADBannerViewDelegate>

@property (nonatomic,strong)GAMBannerView *bannerView;
@end

@implementation TradPlusGAMBannerAdapter

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
    self.bannerView = [[GAMBannerView alloc] initWithAdSize:adSize];
    self.bannerView.adUnitID = placementId;
    self.bannerView.rootViewController = self.waterfallItem.bannerRootViewController;
    self.bannerView.delegate = self;
    
    GAMRequest *request = [GAMRequest request];
    if (![MSConsentManager sharedManager].canCollectPersonalInfo
        || !gTPOpenPersonalizedAd)
    {
        MSLogTrace(@"***********");
        MSLogTrace(@"GAM non-personalized ads");
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

- (void)bannerViewDidReceiveAd:(nonnull GAMBannerView *)bannerView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)bannerView:(nonnull GAMBannerView *)bannerView
    didFailToReceiveAdWithError:(nonnull NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

- (void)bannerViewDidRecordImpression:(nonnull GAMBannerView *)bannerView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)bannerViewDidRecordClick:(nonnull GAMBannerView *)bannerView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}
@end
