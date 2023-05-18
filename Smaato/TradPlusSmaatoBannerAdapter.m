#import "TradPlusSmaatoBannerAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <SmaatoSDKBanner/SMABannerView.h>
#import "TradPlusSmaatoSDKLoader.h"
#import "TPSmaatoAdapterBaseInfo.h"

@interface TradPlusSmaatoBannerAdapter ()<SMABannerViewDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) SMABannerView *bannerView;
@property (nonatomic, copy) NSString *placementId;

@end

@implementation TradPlusSmaatoBannerAdapter

#pragma mark - Extra
- (BOOL)extraActWithEvent:(NSString *)event info:(NSDictionary *)config
{
    if([event isEqualToString:@"StartInit"])
    {
        [self initSDKWithInfo:config];
    }
    else if([event isEqualToString:@"AdapterVersion"])
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

- (void)initSDKWithInfo:(NSDictionary *)config
{
    NSString *appId = config[@"appId"];
    if(appId == nil)
    {
        MSLogTrace(@"Smaato init Config Error %@",config);
        return;
    }
    if([TradPlusSmaatoSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusSmaatoSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusSmaatoSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_SmaatoAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [SmaatoSDK sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_SmaatoAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}


- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *appId = item.config[@"appId"];
    self.placementId = item.config[@"placementId"];
    if(appId == nil || self.placementId == nil)
    {
        [self AdConfigError];
        return;
    }
    [[TradPlusSmaatoSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    CGRect rect = CGRectZero;
    SMABannerAdSize bannerAdSize = kSMABannerAdSizeXXLarge_320x50;
    if(self.waterfallItem.bannerSize.width > 0
       && self.waterfallItem.bannerSize.height > 0)
    {
        bannerAdSize = kSMABannerAdSizeAny;
        rect.size = self.waterfallItem.bannerSize;
    }
    else
    {
        CGFloat width = [self.waterfallItem.ad_size_info[@"X"] floatValue];
        CGFloat height = [self.waterfallItem.ad_size_info[@"Y"] floatValue];
        if(self.waterfallItem.ad_size == 2)
        {
            bannerAdSize = kSMABannerAdSizeLeaderboard_728x90;
            if(width == 0)
                width = 728;
            if(height == 0)
                height = 90;
        }
        else if(self.waterfallItem.ad_size == 3)
        {
            bannerAdSize = kSMABannerAdSizeMediumRectangle_300x250;
            if(width == 0)
                width = 300;
            if(height == 0)
                height = 250;
        }
        else
        {
            if(width == 0)
                width = 320;
            if(height == 0)
                height = 50;
        }
        rect.size = CGSizeMake(width, height);
    }
    self.bannerView = [[SMABannerView alloc] initWithFrame:rect];
    self.bannerView.delegate = self;
    self.bannerView.autoreloadInterval = kSMABannerAutoreloadIntervalDisabled;
    [self.bannerView loadWithAdSpaceId:self.placementId adSize:bannerAdSize];
}

#pragma mark - TPSDKLoaderDelegate
- (void)tpInitFinish
{
    [self loadAd];
}

- (void)tpInitFailWithError:(NSError *)error
{
    [self AdLoadFailWithError:error];
}

- (BOOL)isReady
{
    return (self.bannerView != nil);
}

- (id)getCustomObject
{
    return self.bannerView;
}

- (void)bannerDidAddSubView:(UIView *)subView
{
    [self setBannerCenterWithBanner:self.bannerView subView:subView];
    [self AdShow];
}

#pragma mark - SMABannerViewDelegate
- (nonnull UIViewController *)presentingViewControllerForBannerView:(SMABannerView *_Nonnull)bannerView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    return self.waterfallItem.bannerRootViewController;
}

- (void)bannerViewDidTTLExpire:(SMABannerView *_Nonnull)bannerView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)bannerViewDidLoad:(SMABannerView *_Nonnull)bannerView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}


- (void)bannerViewDidClick:(SMABannerView *_Nonnull)bannerView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)bannerView:(SMABannerView *_Nonnull)bannerView didFailWithError:(NSError *_Nonnull)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

- (void)bannerViewDidImpress:(SMABannerView *_Nonnull)bannerView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
@end
