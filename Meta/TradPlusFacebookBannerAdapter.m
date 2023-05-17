#import "TradPlusFacebookBannerAdapter.h"
#import "TPFacebookAdapterConfig.h"
#import <FBAudienceNetwork/FBAudienceNetwork.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import "TPFacebookAdapterBaseInfo.h"

@interface TradPlusFacebookBannerAdapter()<FBAdViewDelegate>

@property (nonatomic,strong)FBAdView *adView;
@property (nonatomic,assign)BOOL useBannerSize;
@end

@implementation TradPlusFacebookBannerAdapter

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
    
    CGFloat width = [self.waterfallItem.ad_size_info[@"X"] floatValue];
    CGFloat height = [self.waterfallItem.ad_size_info[@"Y"] floatValue];
    FBAdSize adSize;
    switch (self.waterfallItem.ad_size)
    {
        case 1:
        {
            adSize = kFBAdSizeHeight50Banner;
            if(width == 0)
                width = 320;
            if(height == 0)
                height = 50;
            break;
        }
        case 2:
        {
            adSize = kFBAdSizeHeight90Banner;
            if(width == 0)
                width = 320;
            if(height == 0)
                height = 90;
            break;
        }
        case 3:
        {
            adSize = kFBAdSizeHeight250Rectangle;
            if(width == 0)
                width = 300;
            if(height == 0)
                height = 250;
            break;
        }
        default:
        {
            if(width == 0)
                width = 320;
            if(height == 0)
                height = 50;
            adSize.size = CGSizeMake(width, height);
            break;
        }
    }
    if(self.waterfallItem.bannerSize.width > 0)
    {
        self.useBannerSize = YES;
        width = self.waterfallItem.bannerSize.width;
    }
    self.adView = [[FBAdView alloc] initWithPlacementID:placementId adSize:adSize rootViewController:self.waterfallItem.bannerRootViewController];
    self.adView.frame = CGRectMake(0, 0, width, height);
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
        [self.adView loadAdWithBidPayload:bidToken];
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


#pragma mark - FBAdViewDelegate
- (void)adViewDidLoad:(FBAdView *)adView;
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)adViewDidClick:(FBAdView *)adView;
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)adViewWillLogImpression:(FBAdView *)adView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)adView:(FBAdView *)adView didFailWithError:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}
@end
