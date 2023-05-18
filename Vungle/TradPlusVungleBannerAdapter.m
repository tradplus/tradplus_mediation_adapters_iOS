#import "TradPlusVungleBannerAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TPVungleRouter.h"
#import "TradPlusVungleSDKLoader.h"
#import "TPVungleAdapterBaseInfo.h"

@interface TradPlusVungleBannerAdapter ()<TPVungleRouterDelegate,TPSDKLoaderDelegate>

@property (nonatomic,copy)NSString *placementId;
@property (nonatomic,strong)UIView *bannerView;
@property (nonatomic,assign)VungleAdSize adsize;
@property (nonatomic,assign)BOOL isTemplateRender;
@property (nonatomic,strong)UIView *mrecView;
@property (nonatomic,copy)NSString *bidToken;
@property (nonatomic, assign)BOOL willLoad;
@end

@implementation TradPlusVungleBannerAdapter

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
        MSLogTrace(@"Vungle init Config Error %@",config);
        return;
    }
    if([TradPlusVungleSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusVungleSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusVungleSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_VungleAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = VungleSDKVersion;
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_VungleAdapter_PlatformSDK_Version
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
    if(self.waterfallItem.is_template_rendering == 1)
    {
        self.isTemplateRender = YES;
    }
    if(self.waterfallItem.adsourceplacement != nil)
    {
        self.bidToken = self.waterfallItem.adsourceplacement.adm;
    }
    [[TradPlusVungleSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    if(self.isTemplateRender)
    {
        [[TPVungleRouter sharedRouter] requestMRECAdWithPlacementId:self.placementId delegate:self bidToken:self.bidToken];
    }
    else
    {
        self.adsize = VungleAdSizeBanner;
        if(self.waterfallItem.ad_size == 2)
        {
            self.adsize = VungleAdSizeBannerShort;
        }
        else if(self.waterfallItem.ad_size == 3)
        {
            self.adsize = VungleAdSizeBannerLeaderboard;
        }
        [[TPVungleRouter sharedRouter] requestBannerAdWithPlacementId:self.placementId size:self.adsize delegate:self bidToken:self.bidToken];
    }
}

#pragma mark - TPSDKLoaderDelegate
- (void)tpInitFinish
{
    if([[TPVungleRouter sharedRouter] hasPlacementIdAd:self.placementId] && self.bidToken != nil)
    {
        self.willLoad = YES;
        [[TPVungleRouter sharedRouter] addPlacementId:self.placementId delegate:self];
        [[TPVungleRouter sharedRouter] finishedDisplayingAd:self.placementId];
    }
    else
    {
        [self loadAd];
    }
}

- (void)tpInitFailWithError:(NSError *)error
{
    [self AdLoadFailWithError:error];
}

- (BOOL)isReady
{
    if(self.isTemplateRender)
    {
        return (self.mrecView != nil);
    }
    else
    {
        return (self.bannerView != nil);
    }
}

- (id)getCustomObject
{
    if(self.isTemplateRender)
    {
        return self.mrecView;
    }
    else
    {
        return self.bannerView;
    }
}

- (void)bannerDidAddSubView:(UIView *)subView
{
    if(self.isTemplateRender)
    {
        CGRect rect = self.mrecView.frame;
        if(self.waterfallItem.bannerSize.width > 0
           && self.waterfallItem.bannerSize.height > 0)
        {
            rect.size = self.waterfallItem.bannerSize;
        }
        else
        {
            rect.size.width = subView.bounds.size.width;
            rect.size.height = subView.bounds.size.height;
        }
        self.mrecView.frame = rect;
        [self setBannerCenterWithBanner:self.mrecView subView:subView];
    }
    else
    {
        CGRect rect = self.bannerView.frame;
        if(self.waterfallItem.bannerSize.width > 0)
        {
            rect.size.width = self.waterfallItem.bannerSize.width;
        }
        else
        {
            rect.size.width = subView.bounds.size.width;
        }
        self.bannerView.frame = rect;
        [self setBannerCenterWithBanner:self.bannerView subView:subView];
        [self AdShow];
    }
}

#pragma mark - TPVungleRouterDelegate

- (void)vungleAdDidLoad
{
    
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.isTemplateRender)
    {
        if(self.mrecView == nil)
        {
            self.mrecView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 250)];
            NSError *error = nil;
            if(![[TPVungleRouter sharedRouter] addAdViewToView:self.mrecView placementID:self.placementId bidToken:self.bidToken error:&error])
            {
                MSLogTrace(@"vungle show %@", error);
                [self AdShowFailWithError:error];
            }
            else
            {
                [self AdLoadFinsh];
            }
        }
    }
    else
    {
        if(self.bannerView == nil)
        {
            CGRect rect = CGRectZero;
            rect.size = CGSizeMake(320, 50);
            if(self.waterfallItem.ad_size == 2)
            {
                rect.size = CGSizeMake(300, 50);
            }
            else if(self.waterfallItem.ad_size == 3)
            {
                rect.size = CGSizeMake(728, 90);
            }
            self.bannerView = [[UIView alloc] initWithFrame:rect];
            NSError *error = nil;
            if(![[TPVungleRouter sharedRouter] addAdViewToView:self.bannerView placementID:self.placementId bidToken:self.bidToken error:&error])
            {
                MSLogTrace(@"vungle show %@", error);
                [self AdShowFailWithError:error];
            }
            else
            {
                [self AdLoadFinsh];
            }
        }
    }
}

- (void)vungleAdDidFailToLoad:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    if(self.isAdReady)
    {
        return;
    }
    [[TPVungleRouter sharedRouter] clearDelegateForPlacementId:self.placementId];
    [self AdLoadFailWithError:error];
}

- (void)vungleAdDidShow
{
    MSLogTrace(@" %s", __PRETTY_FUNCTION__);
    if(self.isTemplateRender)
    {
        [self AdShow];
    }
}

- (void)vungleAdWasTapped
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)vungleAdWillAppear
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)vungleAdDidFailToPlay:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)vungleAdWillDisappear
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.willLoad)
    {
        self.willLoad = NO;
        [self loadAd];
    }
}
@end
