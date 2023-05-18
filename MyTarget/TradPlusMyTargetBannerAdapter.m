#import "TradPlusMyTargetBannerAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <MyTargetSDK/MyTargetSDK.h>
#import "TPMyTargetAdapterBaseInfo.h"
#import "TradPlusMyTargetSDKSetting.h"

@interface TradPlusMyTargetBannerAdapter ()<MTRGAdViewDelegate>

@property (nonatomic, strong) MTRGAdView *bannerView;
@end

@implementation TradPlusMyTargetBannerAdapter

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
        return;;
    }
    
    [TradPlusMyTargetSDKSetting setPrivacy];
    
    self.bannerView = [MTRGAdView adViewWithSlotId:[slotId intValue] shouldRefreshAd:NO];
    self.bannerView.delegate = self;
    self.bannerView.viewController = self.waterfallItem.bannerRootViewController;
    if(self.waterfallItem.bannerSize.width > 0 && self.waterfallItem.bannerSize.height > 0)
    {
        self.bannerView.adSize = [MTRGAdSize adSizeForCurrentOrientationForWidth:self.waterfallItem.bannerSize.width maxHeight:self.waterfallItem.bannerSize.height];
    }
    else
    {
        self.bannerView.adSize = [self getAdSize];
    }
    CGRect rect = CGRectZero;
    rect.size = self.bannerView.adSize.size;
    self.bannerView.frame = rect;
    NSString *bidToken = nil;
    if(item.adsourceplacement != nil)
    {
        bidToken = item.adsourceplacement.adm;
    }
    if(bidToken == nil)
    {
        [self.bannerView load];
    }
    else
    {
        [self.bannerView loadFromBid:bidToken];
    }
}

- (MTRGAdSize *)getAdSize
{
    switch (self.waterfallItem.ad_size)
    {
        case 1:
            return [MTRGAdSize adSize320x50];
        case 2:
            return [MTRGAdSize adSize300x250];
        case 3:
            return [MTRGAdSize adSize728x90];
        default:
        {
            CGFloat width = [self.waterfallItem.ad_size_info[@"X"] floatValue];
            CGFloat height = [self.waterfallItem.ad_size_info[@"Y"] floatValue];
            if(width == 0)
                width = 320;
            if(height == 0)
                height = 50;
            return [MTRGAdSize adSizeForCurrentOrientationForWidth:width maxHeight:height];
        }
    }
}

- (void)bannerDidAddSubView:(UIView *)subView
{
    [self setBannerCenterWithBanner:self.bannerView subView:subView];
}

- (BOOL)isReady
{
    return (self.bannerView != nil);
}

- (id)getCustomObject
{
    return self.bannerView;
}

#pragma mark - MTRGAdViewDelegate

- (void)onLoadWithAdView:(MTRGAdView *)adView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)onNoAdWithReason:(NSString *)reason adView:(MTRGAdView *)adView
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,reason);
    NSError *error = [NSError errorWithDomain:@"MyTarget No Ad" code:400 userInfo:@{NSLocalizedDescriptionKey:reason}];
    [self AdLoadFailWithError:error];
}

- (void)onAdClickWithAdView:(MTRGAdView *)adView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)onAdShowWithAdView:(MTRGAdView *)adView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}
@end
