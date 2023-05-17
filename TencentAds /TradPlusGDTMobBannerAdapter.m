#import "TradPlusGDTMobBannerAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "GDTUnifiedBannerView.h"
#import "GDTSDKConfig.h"
#import "TradPlusGDTMobSDKLoader.h"
#import "TPGDTMobAdapterBaseInfo.h"

@interface TradPlusGDTMobBannerAdapter ()<GDTUnifiedBannerViewDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong)GDTUnifiedBannerView *bannerView;
@property (nonatomic,copy)NSString *bidToken;
@property (nonatomic,copy)NSString *placementId;
@property (nonatomic,assign)BOOL useBannerSize;
@end

@implementation TradPlusGDTMobBannerAdapter

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
        MSLogTrace(@"GDTMob init Config Error %@",config);
        return;
    }
    if([TradPlusGDTMobSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusGDTMobSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusGDTMobSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_GDTMobAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [GDTSDKConfig sdkVersion];
    if(version == nil)
    {
       version = @"";
    }
    NSDictionary *dic = @{
       @"version":version,
       @"adaptedVersion":TP_GDTMobAdapter_PlatformSDK_Version
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
    self.bidToken = nil;
    if(item.adsourceplacement != nil)
    {
        self.bidToken = item.adsourceplacement.adm;
    }
    [[TradPlusGDTMobSDKLoader sharedInstance] setAudioSessionSettingWithExtraInfo:self.waterfallItem.extraInfoDictionary];
    [[TradPlusGDTMobSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    [[TradPlusGDTMobSDKLoader sharedInstance] setPersonalizedAd];
    CGFloat width = [self.waterfallItem.ad_size_info[@"X"] floatValue];
    CGFloat height = [self.waterfallItem.ad_size_info[@"Y"] floatValue];
    if(width == 0)
        width = 320;
    if(height == 0)
        height = 50;
    if(self.waterfallItem.bannerSize.width > 0
       && self.waterfallItem.bannerSize.height > 0)
    {
        self.useBannerSize = YES;
        width = self.waterfallItem.bannerSize.width;
        height = self.waterfallItem.bannerSize.height;
    }
    if(self.bidToken != nil)
    {
        self.bannerView = [[GDTUnifiedBannerView alloc] initWithPlacementId:self.placementId token:self.bidToken viewController:self.waterfallItem.bannerRootViewController];
        self.bannerView.frame = CGRectMake(0, 0, width, height);
    }
    else
    {
        self.bannerView = [[GDTUnifiedBannerView alloc] initWithFrame:CGRectMake(0, 0, width, height) placementId:self.placementId viewController:self.waterfallItem.bannerRootViewController];
    }
    self.bannerView.autoSwitchInterval = 0;
    self.bannerView.delegate = self;
    
    [self.bannerView loadAdAndShow];
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
    if(!self.useBannerSize)
    {
        CGRect rect = self.bannerView.frame;
        rect.size = subView.bounds.size;
        self.bannerView.frame = rect;
    }
    [self setBannerCenterWithBanner:self.bannerView subView:subView];
}

#pragma mark - GDTUnifiedBannerViewDelegate
- (void)unifiedBannerViewDidLoad:(GDTUnifiedBannerView *)unifiedBannerView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.bidToken != nil)
    {
        [self.bannerView setBidECPM:self.waterfallItem.adsourceplacement.bid_price];
    }
    [self AdLoadFinsh];
}


- (void)unifiedBannerViewFailedToLoad:(GDTUnifiedBannerView *)unifiedBannerView error:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}


- (void)unifiedBannerViewWillExpose:(GDTUnifiedBannerView *)unifiedBannerView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)unifiedBannerViewClicked:(GDTUnifiedBannerView *)unifiedBannerView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}


- (void)unifiedBannerViewWillClose:(GDTUnifiedBannerView *)unifiedBannerView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}
@end
