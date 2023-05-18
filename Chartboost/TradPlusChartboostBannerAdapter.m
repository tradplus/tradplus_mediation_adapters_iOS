#import "TradPlusChartboostBannerAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <ChartboostSDK/Chartboost.h>
#import "TradPlusChartboostSDKLoader.h"
#import "TPChartboostAdapterBaseInfo.h"

@interface TradPlusChartboostBannerAdapter ()<CHBBannerDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong)CHBBanner *banner;
@property (nonatomic,copy)NSString *placementId;
@property (nonatomic,assign)BOOL useBannerSize;
@end

@implementation TradPlusChartboostBannerAdapter

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
    NSString *appSignature = config[@"appSign"];
    if(appId == nil || appSignature == nil)
    {
        MSLogTrace(@"Chartboost init Config Error %@",config);
        return;
    }
    if([TradPlusChartboostSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusChartboostSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusChartboostSDKLoader sharedInstance] initWithAppId:appId appSignature:appSignature delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_ChartboostAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [Chartboost getSDKVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_ChartboostAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    self.placementId = item.config[@"placementId"];
    NSString *appId = item.config[@"appId"];
    NSString *appSignature = item.config[@"appSign"];
    if(self.placementId == nil || appId == nil || appSignature == nil)
    {
        [self AdConfigError];
        return;
    }
    [[TradPlusChartboostSDKLoader sharedInstance] initWithAppId:appId appSignature:appSignature delegate:self];
}

- (void)loadAd
{
    CGSize bannerSize = [self getAdSize];
    if(self.waterfallItem.bannerSize.width > 0)
    {
        self.useBannerSize = YES;
        bannerSize.width = self.waterfallItem.bannerSize.width;
    }
    self.banner = [[CHBBanner alloc] initWithSize:bannerSize location:self.placementId delegate:self];
    [self.banner cache];
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

- (CGSize)getAdSize
{
    switch (self.waterfallItem.ad_size)
    {
        case 1:
            return CHBBannerSizeStandard;
        case 2:
            return CHBBannerSizeMedium;
        case 3:
            return CHBBannerSizeLeaderboard;
        default:
        {
            CGFloat width = [self.waterfallItem.ad_size_info[@"X"] floatValue];
            CGFloat height = [self.waterfallItem.ad_size_info[@"Y"] floatValue];
            if(width == 0)
                width = 320;
            if(height == 0)
                height = 50;
            return CGSizeMake(width, height);
        }
    }
}

- (void)bannerDidAddSubView:(UIView *)subView
{
    if(!self.useBannerSize)
    {
        CGRect rect = self.banner.frame;
        rect.size.width = subView.bounds.size.width;
        self.banner.frame = rect;
    }
    [self setBannerCenterWithBanner:self.banner subView:subView];
    [self.banner showFromViewController:self.waterfallItem.bannerRootViewController];
}

- (BOOL)isReady
{
    return (self.banner != nil);
}

- (id)getCustomObject
{
    return self.banner;
}

#pragma mark - CHBBannerDelegate
- (void)didCacheAd:(CHBCacheEvent *)event error:(nullable CHBCacheError *)error
{
    MSLogTrace(@"%s->%@", __PRETTY_FUNCTION__, error);
    if(error == nil)
    {
        [self AdLoadFinsh];
    }
    else
    {
        [self AdLoadFailWithError:error];
    }
}

- (void)didShowAd:(CHBShowEvent *)event error:(nullable CHBShowError *)error
{
    MSLogTrace(@"%s->%@", __PRETTY_FUNCTION__, error);
    if (error == nil)
    {
        [self AdShow];
    }
    else
    {
        [self AdShowFailWithError:error];
    }
}

- (void)didClickAd:(CHBClickEvent *)event error:(nullable CHBClickError *)error
{
    MSLogTrace(@"%s->%@", __PRETTY_FUNCTION__, error);
    [self AdClick];
}

@end
