#import "TradPlusBaiduBannerAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <BaiduMobAdSDK/BaiduMobAdView.h>
#import "TradPlusBaiduSDKSetting.h"
#import "TPBaiduAdapterBaseInfo.h"

@interface TradPlusBaiduBannerAdapter()<BaiduMobAdViewDelegate>

@property (nonatomic, strong) BaiduMobAdView *bannerView;
@property (nonatomic, copy) NSString *appId;
@end

@implementation TradPlusBaiduBannerAdapter

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
    NSDictionary *dic = @{@"version":TP_BaiduAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = SDK_VERSION_IN_MSSP;
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_BaiduAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    self.appId = item.config[@"appId"];
    NSString *placementId = item.config[@"placementId"];
    if(placementId == nil || self.appId == nil)
    {
        [self AdConfigError];
        return;
    }
    [[TradPlusBaiduSDKSetting sharedInstance] setPersonalizedAd];
    self.bannerView = [[BaiduMobAdView alloc] init];
    self.bannerView.AdType = BaiduMobAdViewTypeBanner;
    self.bannerView.delegate = self;
    self.bannerView.AdUnitTag = placementId;
    CGRect rect = CGRectZero;
    if(item.bannerSize.width > 0)
    {
        rect.size.width = item.bannerSize.width;
    }
    else
    {
        rect.size.width = 320;
    }
    switch (self.waterfallItem.ad_size)
    {
        case 2:
        {
            rect.size.height = rect.size.width*2.0/3.0;
            break;
        }
        case 3:
        {
            rect.size.height = rect.size.width*3.0/7.0;
            break;
        }
        case 4:
        {
            rect.size.height = rect.size.width/2.0;
            break;
        }
        default:
        {
            rect.size.height = rect.size.width*3.0/20.0;
            break;
        }
    }
    self.bannerView.frame = rect;
    [self.bannerView start];
}

- (void)bannerDidAddSubView:(UIView *)subView
{
    [self setBannerCenterWithBanner:self.bannerView subView:subView];
    [self AdShow];
}

- (id)getCustomObject
{
    return self.bannerView;
}

- (BOOL)isReady
{
    return (self.bannerView != nil);
}

#pragma mark - BaiduMobAdViewDelegate

- (NSString *)publisherId
{
    return self.appId;
}

- (void)willDisplayAd:(BaiduMobAdView *)adview
{
    MSLogTrace(@"%s",__FUNCTION__);
    [self AdLoadFinsh];
}

- (void)failedDisplayAd:(BaiduMobFailReason)reason
{
    MSLogTrace(@"%s",__FUNCTION__);
    NSError *error = [NSError errorWithDomain:@"Baidu" code:reason userInfo:@{NSLocalizedDescriptionKey: @"load faile"}];
    [self AdLoadFailWithError:error];
}

- (void)didAdImpressed
{
    MSLogTrace(@"%s",__FUNCTION__);
}

- (void)didAdClicked
{
    MSLogTrace(@"%s",__FUNCTION__);
    [self AdClick];
}

- (void)didDismissLandingPage
{
    MSLogTrace(@"%s",__FUNCTION__);
}

- (void)didAdClose
{
    MSLogTrace(@"%s",__FUNCTION__);
    [self AdClose];
}
@end
