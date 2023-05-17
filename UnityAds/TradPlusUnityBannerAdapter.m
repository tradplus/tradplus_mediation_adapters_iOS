#import "TradPlusUnityBannerAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <UnityAds/UnityAds.h>
#import "TradPlusUnitySDKLoader.h"
#import "TPUnityAdapterBaseInfo.h"

@interface TradPlusUnityBannerAdapter ()<UADSBannerViewDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong)UADSBannerView *bannerView;
@property (nonatomic,copy)NSString *placementId;
@end

@implementation TradPlusUnityBannerAdapter

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

//初始化SDK
- (void)initSDKWithInfo:(NSDictionary *)config
{
    NSString *appId = config[@"appId"];
    if(appId == nil)
    {
        MSLogTrace(@"Unity init Config Error %@",config);
        return;
    }
    if([TradPlusUnitySDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusUnitySDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusUnitySDKLoader sharedInstance] initWithGameID:appId delegate:nil];
}

//版本号
- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_UnityAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

//三方SDK版本号
- (void)platformSDKVersionCallback
{
    NSString *version = [UnityAds getVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_UnityAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *appId = item.config[@"appId"];
    self.placementId = item.config[@"placementId"];
    if(self.placementId == nil)
    {
        self.placementId = item.config[@"zoneId"];
    }
    if(appId == nil || self.placementId == nil)
    {
        [self AdConfigError];
        return;
    }
    [[TradPlusUnitySDKLoader sharedInstance] initWithGameID:appId delegate:self];
}

- (void)loadAd
{
    [[TradPlusUnitySDKLoader sharedInstance] setPersonalizedAd];
    CGSize size = [self getAdSize];
    self.bannerView = [[UADSBannerView alloc] initWithPlacementId:self.placementId size:size];
    self.bannerView.delegate = self;
    [self.bannerView load];
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
    CGFloat width = [self.waterfallItem.ad_size_info[@"X"] floatValue];
    CGFloat height = [self.waterfallItem.ad_size_info[@"Y"] floatValue];
    if(self.waterfallItem.ad_size == 2)
    {
        if(width == 0)
            width = 728;
        if(height == 0)
            height = 90;
    }
    else
    {
        if(width == 0)
            width = 320;
        if(height == 0)
            height = 50;
    }
    return CGSizeMake(width, height);
}

- (void)bannerDidAddSubView:(UIView *)subView
{
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

#pragma mark - UADSBannerViewDelegate

- (void)bannerViewDidLoad: (UADSBannerView *)bannerView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)bannerViewDidClick: (UADSBannerView *)bannerView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}
- (void)bannerViewDidLeaveApplication:(UADSBannerView *)bannerView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)bannerViewDidError: (UADSBannerView *)bannerView error: (UADSBannerError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__ , error);
    [self AdLoadFailWithError:error];
}
@end
