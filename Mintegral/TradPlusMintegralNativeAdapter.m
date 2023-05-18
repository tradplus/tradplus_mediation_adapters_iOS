#import "TradPlusMintegralNativeAdapter.h"
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/MSLogging.h>
#import "TradPlusMintegralSDKLoader.h"
#import <MTGSDKNativeAdvanced/MTGNativeAdvancedAd.h>
#import <MTGSDK/MTGSDK.h>
#import "TPMintegralAdapterBaseInfo.h"

@interface TradPlusMintegralNativeAdapter()<MTGNativeAdvancedAdDelegate,MTGBidNativeAdManagerDelegate,MTGNativeAdManagerDelegate,MTGMediaViewDelegate,TPSDKLoaderDelegate>

@property (nonatomic,assign)BOOL isTemplateRender;
@property (nonatomic,assign)BOOL isBidding;
@property (nonatomic,strong)MTGNativeAdvancedAd *advancedAd;
@property (nonatomic,strong)MTGBidNativeAdManager *bidNativeAdManager;
@property (nonatomic,strong)MTGNativeAdManager *nativeAdManager;
@property (nonatomic,strong)MTGCampaign *campaign;
@property (nonatomic,copy)NSString *unitId;
@property (nonatomic,strong)UIView *adView;
@property (nonatomic,assign)BOOL isNativeBanner;
@property (nonatomic,copy)NSString *placementId;
@end

@implementation TradPlusMintegralNativeAdapter

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
    NSString *appKey = config[@"AppKey"];
    if(appId == nil || appKey == nil)
    {
        MSLogTrace(@"Mintegral init Config Error %@",config);
        return;
    }
    if([TradPlusMintegralSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusMintegralSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusMintegralSDKLoader sharedInstance] initWithAppID:appId apiKey:appKey delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_MintegralAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [MTGSDK sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_MintegralAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *appId = item.config[@"appId"];
    NSString *appKey = item.config[@"AppKey"];
    self.placementId = item.config[@"placementId"];
    self.unitId = item.config[@"unitId"];
    if(appId == nil || self.placementId == nil || self.unitId == nil || appKey == nil)
    {
        [self AdConfigError];
        return;
    }
    [[TradPlusMintegralSDKLoader sharedInstance] initWithAppID:appId apiKey:appKey delegate:self];
}

- (void)loadAd
{
    [[TradPlusMintegralSDKLoader sharedInstance] setPersonalizedAd];
    NSString *bidToken = nil;
    if(self.waterfallItem.adsourceplacement != nil)
    {
        bidToken = self.waterfallItem.adsourceplacement.adm;
    }
    if(self.waterfallItem.secType == 2)
    {
        self.isNativeBanner = YES;
    }
    self.waterfallItem.nativeType = TPNativeADTYPE_Feed;
    if(self.waterfallItem.is_template_rendering != 2)
    {
        self.waterfallItem.nativeType = TPNativeADTYPE_Template;
        self.isTemplateRender = YES;
    }
    if(self.isTemplateRender)
    {
        [self loadAdvancedAdWithPlacementId:self.placementId item:self.waterfallItem bidToken:bidToken];
    }
    else
    {
        [self loadNativeAdWithPlacementId:self.placementId item:self.waterfallItem bidToken:bidToken];
    }
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
    if(self.isTemplateRender)
    {
        return (self.advancedAd != nil);
    }
    else
    {
        return (self.campaign != nil);
    }
}

- (id)getCustomObject
{
    if(self.isTemplateRender)
    {
        return self.advancedAd;
    }
    else
    {
        return self.campaign;
    }
}


- (void)loadNativeAdWithPlacementId:(NSString *)placementId item:(TradPlusAdWaterfallItem *)item bidToken:(NSString *)bidToken
{
    if (bidToken && bidToken.length > 0)
    {
        self.isBidding = YES;
        self.bidNativeAdManager = [[MTGBidNativeAdManager alloc] initWithPlacementId:placementId unitID:self.unitId autoCacheImage:NO presentingViewController:nil];
        self.bidNativeAdManager.delegate = self;
        [self.bidNativeAdManager loadWithBidToken:bidToken];
    }
    else
    {
        self.nativeAdManager = [[MTGNativeAdManager alloc] initWithPlacementId:placementId unitID:self.unitId supportedTemplates:@[[MTGTemplate templateWithType:MTGAD_TEMPLATE_BIG_IMAGE adsNum:1]] autoCacheImage:NO adCategory:0 presentingViewController:nil];
        self.nativeAdManager.delegate = self;
        [self.nativeAdManager loadAds];
    }
}

- (void)setupRes:(NSArray *)nativeAds
{
    self.campaign = nativeAds.firstObject;
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    res.title = self.campaign.appName;
    res.body = self.campaign.appDesc;
    res.ctaText = self.campaign.adCall;
    if(self.campaign.iconUrl != nil)
    {
        res.iconImageURL = self.campaign.iconUrl;
        [self.downLoadURLArray addObject:res.iconImageURL];
    }
    MTGAdChoicesView *adChoicesView = [[MTGAdChoicesView alloc] init];
    adChoicesView.campaign = self.campaign;
    res.adChoiceView = adChoicesView;
    if(!self.isNativeBanner)
    {
        MTGMediaView *mediaView = [[MTGMediaView alloc] init];
        BOOL videoMute = YES;
        if(self.waterfallItem.video_mute == 2)
        {
            videoMute = NO;
        }
        mediaView.mute = videoMute;
        [mediaView setMediaSourceWithCampaign:self.campaign unitId:self.unitId];
        mediaView.delegate = self;
        res.mediaView = mediaView;
    }
    self.waterfallItem.adRes = res;
    [self AdLoadFinsh];
}

- (UIView *)endRender:(NSDictionary *)viewInfo clickView:(NSArray *)array
{
    UIView *adView = viewInfo[kTPRendererAdView];
    if(self.isBidding)
    {
        self.bidNativeAdManager.viewController = self.rootViewController;
        [self.bidNativeAdManager registerViewForInteraction:adView withClickableViews:array withCampaign:self.campaign];
    }
    else
    {
        self.nativeAdManager.viewController = self.rootViewController;
        [self.nativeAdManager registerViewForInteraction:adView withClickableViews:array withCampaign:self.campaign];
    }
    return nil;
}

#pragma mark - MTGMediaViewDelegate
- (void)nativeAdImpressionWithType:(MTGAdSourceType)type mediaView:(MTGMediaView *)mediaView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)nativeAdDidClick:(nonnull MTGCampaign *)nativeAd mediaView:(MTGMediaView *)mediaView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

#pragma mark - MTGNativeAdManagerDelegate
- (void)nativeAdsLoaded:(nullable NSArray *)nativeAds nativeManager:(nonnull MTGNativeAdManager *)nativeManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self setupRes:nativeAds];
}

- (void)nativeAdsFailedToLoadWithError:(nonnull NSError *)error nativeManager:(nonnull MTGNativeAdManager *)nativeManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFailWithError:error];
}

- (void)nativeAdImpressionWithType:(MTGAdSourceType)type nativeManager:(nonnull MTGNativeAdManager *)nativeManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)nativeAdDidClick:(nonnull MTGCampaign *)nativeAd nativeManager:(nonnull MTGNativeAdManager *)nativeManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

#pragma mark - MTGBidNativeAdManagerDelegate

- (void)nativeAdImpressionWithType:(MTGAdSourceType)type bidNativeManager:(nonnull MTGBidNativeAdManager *)bidNativeManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)nativeAdsLoaded:(nullable NSArray *)nativeAds bidNativeManager:(nonnull MTGBidNativeAdManager *)bidNativeManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self setupRes:nativeAds];
}

- (void)nativeAdsFailedToLoadWithError:(nonnull NSError *)error bidNativeManager:(nonnull MTGBidNativeAdManager *)bidNativeManager
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}


- (void)nativeAdDidClick:(nonnull MTGCampaign *)nativeAd bidNativeManager:(nonnull MTGBidNativeAdManager *)bidNativeManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}


#pragma mark - TemplateRender
- (void)loadAdvancedAdWithPlacementId:(NSString *)placementId item:(TradPlusAdWaterfallItem *)item bidToken:(NSString *)bidToken
{
    CGSize size = item.templateRenderSize;
    self.advancedAd = [[MTGNativeAdvancedAd alloc] initWithPlacementID:placementId unitID:self.unitId adSize:size rootViewController:nil];
    BOOL videoMute = YES;
    if(item.video_mute == 2)
    {
        videoMute = NO;
    }
    self.advancedAd.mute = videoMute;
    MTGNativeAdvancedAdVideoPlayType autoPlay = MTGVideoPlayTypeAuto;
    
    if(item.auto_play_video == 2)
    {
        autoPlay = MTGVideoPlayTypeOnlyWiFi;
    }
    else if(item.auto_play_video == 3)
    {
        autoPlay = MTGVideoPlayTypeJustTapped;
    }
    self.advancedAd.autoPlay = autoPlay;
    self.advancedAd.delegate = self;
    if(bidToken != nil  && bidToken.length > 0)
    {
        [self.advancedAd loadAdWithBidToken:bidToken];
    }
    else
    {
        [self.advancedAd loadAd];
    }
}

- (void)templateRender:(UIView *)subView
{
    if(self.waterfallItem.templateContentMode == TPTemplateContentModeScaleToFill)
    {
        self.adView.frame = subView.bounds;
    }
    else
    {
        CGRect rect = CGRectZero;
        if(self.waterfallItem.templateRenderSize.width == 0 || self.waterfallItem.templateRenderSize.height == 0)
        {
            rect = subView.bounds;
        }
        else
        {
            rect.size = self.waterfallItem.templateRenderSize;
        }
        self.adView.frame = rect;
        CGPoint center = CGPointZero;
        center.x = CGRectGetWidth(subView.bounds)/2;
        center.y = CGRectGetHeight(subView.bounds)/2;
        self.adView.center = center;
    }
}

#pragma mark - MTGNativeAdvancedAdDelegate
- (void)nativeAdvancedAdLoadSuccess:(MTGNativeAdvancedAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    self.adView = [self.advancedAd fetchAdView];
    res.adView = self.adView;
    self.waterfallItem.adRes = res;
    [self AdLoadFinsh];
}

- (void)nativeAdvancedAdLoadFailed:(MTGNativeAdvancedAd *)nativeAd error:(NSError * __nullable)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

- (void)nativeAdvancedAdWillLogImpression:(MTGNativeAdvancedAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}


- (void)nativeAdvancedAdDidClicked:(MTGNativeAdvancedAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}
 

- (void)nativeAdvancedAdWillLeaveApplication:(MTGNativeAdvancedAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
 

- (void)nativeAdvancedAdWillOpenFullScreen:(MTGNativeAdvancedAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
 

- (void)nativeAdvancedAdCloseFullScreen:(MTGNativeAdvancedAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeAdvancedAdClosed:(MTGNativeAdvancedAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}
@end
