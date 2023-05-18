#import "TradPlusKuaiShouNativeAdapter.h"
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/MSLogging.h>
#import "TradPlusKuaiShouSDKLoader.h"
#import <KSAdSDK/KSAdSDK.h>
#import "TPKuaiShouAdapterBaseInfo.h"

@interface TradPlusKuaiShouNativeAdapter()<KSFeedAdsManagerDelegate,KSFeedAdDelegate,KSNativeAdDelegate,TPSDKLoaderDelegate,KSDrawAdsManagerDelegate,KSDrawAdDelegate>

@property (nonatomic,strong)KSFeedAdsManager *adsManager;
@property (nonatomic,strong)KSFeedAd *feedAd;

@property (nonatomic,strong)KSNativeAdRelatedView *relatedView;
@property (nonatomic,strong)KSDrawAdsManager *drawAdsManager;
@property (nonatomic,strong)KSNativeAd *nativeAd;
@property (nonatomic,assign)BOOL isNativeBanner;
@property (nonatomic,assign)NSString *placementId;

@property (nonatomic,assign)NSArray *drawAdDataArray;
@property (nonatomic,assign)NSDictionary *dicBidToken;
@end

@implementation TradPlusKuaiShouNativeAdapter

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
        MSLogTrace(@"KuaiShou init Config Error %@",config);
        return;
    }
    if([TradPlusKuaiShouSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusKuaiShouSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusKuaiShouSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_KuaiShouAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [KSAdSDKManager SDKVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_KuaiShouAdapter_PlatformSDK_Version
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
    self.waterfallItem.nativeType = TPNativeADTYPE_Feed;
    if(item.is_template_rendering != 2)
    {
        self.waterfallItem.nativeType = TPNativeADTYPE_Template;
    }
    if(item.secType == 2)
    {
        self.isNativeBanner = YES;
    }
    else if(item.secType == 3)
    {
        self.waterfallItem.nativeType = TPNativeADTYPE_Draw;
    }
    [[TradPlusKuaiShouSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    [[TradPlusKuaiShouSDKLoader sharedInstance] setPersonalizedAd];

    if(self.waterfallItem.adsourceplacement != nil)
    {
        NSString *bidToken = self.waterfallItem.adsourceplacement.adm;
        NSData *admData = [bidToken dataUsingEncoding:NSUTF8StringEncoding];
        self.dicBidToken = [NSJSONSerialization JSONObjectWithData:admData options:0 error:nil];
    }
    
    if(self.waterfallItem.nativeType == TPNativeADTYPE_Template)
    {
        [self loadTemplateNativeAdWithPlacementId:self.placementId];
    }
    else if(self.waterfallItem.nativeType == TPNativeADTYPE_Draw)
    {
        [self loadDrawNativeAdWithPlacementId:self.placementId];
    }
    else
    {
        [self loadNativeAdWithPlacementId:self.placementId];
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
    if(self.waterfallItem.nativeType == TPNativeADTYPE_Template)
    {
        return (self.feedAd != nil);
    }
    else if(self.waterfallItem.nativeType == TPNativeADTYPE_Draw)
    {
        return (self.drawAdDataArray != nil);
    }
    else
    {
        return (self.nativeAd != nil);
    }
}

- (id)getCustomObject
{
    if(self.waterfallItem.nativeType == TPNativeADTYPE_Template)
    {
        return self.feedAd;
    }
    else if(self.waterfallItem.nativeType == TPNativeADTYPE_Draw)
    {
        return self.drawAdDataArray;
    }
    else
    {
        return self.nativeAd;
    }
}

- (void)loadNativeAdWithPlacementId:(NSString *)placementId
{
    self.nativeAd = [[KSNativeAd alloc] initWithPosId:placementId];
    self.nativeAd.delegate = self;
    if (self.dicBidToken)
        [self.nativeAd loadAdDataWithResponseV2:self.dicBidToken];
    else
        [self.nativeAd loadAdData];
}

- (UIView *)endRender:(NSDictionary *)viewInfo clickView:(NSArray *)array
{
    [self.relatedView refreshData:self.nativeAd];
    self.nativeAd.rootViewController = self.rootViewController;
    UIView *adView = viewInfo[kTPRendererAdView];
    [self.nativeAd registerContainer:adView withClickableViews:array];
    return nil;
}

#pragma mark - KSNativeAdDelegate
- (void)nativeAdDidLoad:(KSNativeAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    KSMaterialMeta *data = self.nativeAd.data;
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    res.body = data.adDescription;
    res.ctaText = data.actionDescription;
    res.rating = @(data.appScore);
    if(data.appIconImage.image != nil)
    {
        res.iconImage = data.appIconImage.image;
    }
    else if(data.appIconImage.imageURL != nil)
    {
        res.iconImageURL = data.appIconImage.imageURL;
        [self.downLoadURLArray addObject:res.iconImageURL];
    }
    NSString *logoURL = [data adSourceLogoURL:KSAdSourceLogoTypeGray];
    if(logoURL != nil)
    {
        res.adChoiceImageURL = logoURL;
        [self.downLoadURLArray addObject:res.adChoiceImageURL];
    }
    if(!self.isNativeBanner)
    {
        self.relatedView = [[KSNativeAdRelatedView alloc] init];
        if(data.materialType == KSAdMaterialTypeVideo)
        {
            res.mediaView = self.relatedView.videoAdView;
        }
        else
        {
            if(data.imageArray.count > 0)
            {
                KSAdImage *image = data.imageArray.firstObject;
                res.mediaImageURL = image.imageURL;
                [self.downLoadURLArray addObject:res.mediaImageURL];
                if(data.imageArray.count > 1)
                {
                    NSMutableArray *urlArray = [[NSMutableArray alloc] init];
                    for(KSAdImage *image in data.imageArray)
                    {
                        if(image.imageURL != nil)
                        {
                            [urlArray addObject:image.imageURL];
                        }
                    }
                    if(urlArray.count > 0)
                    {
                        res.imageURLList = urlArray;
                    }
                }
            }
        }
    }
    res.source = data.adSource;
    self.waterfallItem.adRes = res;
    [self AdLoadFinsh];
}

- (void)nativeAd:(KSNativeAd *)nativeAd didFailWithError:(NSError *_Nullable)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFailWithError:error];
}

- (void)nativeAdDidBecomeVisible:(KSNativeAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)nativeAdDidClick:(KSNativeAd *)nativeAd withView:(UIView *_Nullable)view
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)nativeAdDidShowOtherController:(KSNativeAd *)nativeAd interactionType:(KSAdInteractionType)interactionType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeAdDidCloseOtherController:(KSNativeAd *)nativeAd interactionType:(KSAdInteractionType)interactionType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeAdDidShow:(KSNativeAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeAdVideoReadyToPlay:(KSNativeAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeAdVideoStartPlay:(KSNativeAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)nativeAdVideoPlayFinished:(KSNativeAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}

- (void)nativeAdVideoPlayError:(KSNativeAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeAdVideoPause:(KSNativeAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeAdVideoResume:(KSNativeAd *)nativeAd
{
    
}

#pragma mark - TemplateRender
- (void)loadTemplateNativeAdWithPlacementId:(NSString *)placementId
{
    self.adsManager = [[KSFeedAdsManager alloc] initWithPosId:placementId size:self.waterfallItem.templateRenderSize];
    self.adsManager.delegate = self;
    if (self.dicBidToken)
        [self.adsManager loadAdDataWithResponseV2:self.dicBidToken];
    else
        [self.adsManager loadAdDataWithCount:1];
}

- (void)templateRender:(UIView *)subView
{
    if(self.waterfallItem.templateContentMode == TPTemplateContentModeScaleToFill)
    {
        self.feedAd.feedView.frame = subView.bounds;
    }
    else
    {
        CGPoint center = CGPointZero;
        center.x = CGRectGetWidth(subView.bounds)/2;
        center.y = CGRectGetHeight(subView.bounds)/2;
        self.feedAd.feedView.center = center;
    }
}

#pragma mark - KSFeedAdsManagerDelegate
- (void)feedAdsManagerSuccessToLoad:(KSFeedAdsManager *)adsManager nativeAds:(NSArray<KSFeedAd *> *_Nullable)feedAdDataArray
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    if(feedAdDataArray != nil && feedAdDataArray.count > 0)
    {
        self.feedAd = feedAdDataArray.firstObject;
        self.feedAd.delegate = self;
        res.adView = self.feedAd.feedView;
    }
    self.waterfallItem.adRes = res;
    self.waterfallItem.extraInfoDictionary[@"splash_click_delay_close"] = @(1);
    [self AdLoadFinsh];
}

- (void)feedAdsManager:(KSFeedAdsManager *)adsManager didFailWithError:(NSError *_Nullable)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFailWithError:error];
}

#pragma mark - KSFeedAdDelegate
- (void)feedAdViewWillShow:(KSFeedAd *)feedAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}
- (void)feedAdDidClick:(KSFeedAd *)feedAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}
- (void)feedAdDislike:(KSFeedAd *)feedAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSMutableDictionary *dic = [[NSMutableDictionary alloc]init];
    dic[@"dislikeInfo"] = @"用户关闭";
    [self ADShowExtraCallbackWithEvent:@"tradplus_native_dislike" info:dic];
}
- (void)feedAdDidShowOtherController:(KSFeedAd *)nativeAd interactionType:(KSAdInteractionType)interactionType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
- (void)feedAdDidCloseOtherController:(KSFeedAd *)nativeAd interactionType:(KSAdInteractionType)interactionType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self didCloseOtherController];
}

#pragma mark - Draw信息流
- (void)loadDrawNativeAdWithPlacementId:(NSString *)placementId
{
    self.drawAdsManager = [[KSDrawAdsManager alloc] initWithPosId:placementId];
    self.drawAdsManager.delegate = self;
    if (self.dicBidToken)
        [self.drawAdsManager loadAdDataWithResponseV2:self.dicBidToken];
    else
        [self.drawAdsManager loadAdDataWithCount:3];
}

#pragma mark - KSDrawAdsManagerDelegate

- (NSArray <UIView *>*)getDrawList
{
    NSMutableArray *drawList = [[NSMutableArray alloc] init];
    for(KSDrawAd *drawAd in self.drawAdDataArray)
    {
        drawAd.videoSoundEnabled = NO;
        drawAd.controlPlayState = NO;
        drawAd.delegate = self;
        UIView *drawAdView = [[UIView alloc] init];
        [drawAd registerContainer:drawAdView];
        [drawList addObject:drawAdView];
    }
    return drawList;
}

- (UIView *)drawRender:(UIView *)subView
{
    KSDrawAd *drawAd = self.drawAdDataArray.firstObject;
    drawAd.videoSoundEnabled = NO;
    drawAd.controlPlayState = NO;
    drawAd.delegate = self;
    UIView *drawAdView = [[UIView alloc] initWithFrame:subView.bounds];
    [drawAd registerContainer:drawAdView];
    return drawAdView;
}

- (void)drawAdsManagerSuccessToLoad:(KSDrawAdsManager *)adsManager drawAds:(NSArray<KSDrawAd *> *_Nullable)drawAdDataArray
{
    self.drawAdDataArray = drawAdDataArray;
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    res.drawList = drawAdDataArray;
    self.waterfallItem.adRes = res;
    [self AdLoadFinsh];
}

- (void)drawAdsManager:(KSDrawAdsManager *)adsManager didFailWithError:(NSError *_Nullable)error
{
    [self AdLoadFailWithError:error];
}

#pragma mark - KSDrawAdDelegate
- (void)drawAdViewWillShow:(KSDrawAd *)drawAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShowNoLimit];
}

- (void)drawAdDidClick:(KSDrawAd *)drawAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    //设置 addClickEvent = 2，添加额外的点击埋点 （Draw信息流）
    self.waterfallItem.extraInfoDictionary[@"addClickEvent"] = @(2);
    [self AdClick];
}

- (void)drawAdDidShowOtherController:(KSDrawAd *)drawAd interactionType:(KSAdInteractionType)interactionType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)drawAdDidCloseOtherController:(KSDrawAd *)drawAd interactionType:(KSAdInteractionType)interactionType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)drawAdVideoDidStart:(KSDrawAd *)drawAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)drawAdVideoDidPause:(KSDrawAd *)drawAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)drawAdVideoDidResume:(KSDrawAd *)drawAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)drawAdVideoDidStop:(KSDrawAd *)drawAd finished:(BOOL)finished
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(finished)
    {
        [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
    }
}

- (void)drawAdVideoDidFailed:(KSDrawAd *)drawAd error:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

@end
