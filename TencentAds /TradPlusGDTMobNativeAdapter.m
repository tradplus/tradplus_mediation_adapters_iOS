#import "TradPlusGDTMobNativeAdapter.h"
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/MSLogging.h>
#import "GDTSDKConfig.h"
#import "GDTNativeExpressProAdView.h"
#import "GDTUnifiedNativeAd.h"
#import "GDTUnifiedNativeAdView.h"
#import "GDTNativeExpressAd.h"
#import "GDTNativeExpressAdView.h"
#import "TradPlusGDTMobSDKLoader.h"
#import "TPGDTMobAdapterBaseInfo.h"

@interface TradPlusGDTMobNativeAdapter()<GDTNativeExpressProAdViewDelegate,GDTUnifiedNativeAdDelegate,GDTUnifiedNativeAdViewDelegate,GDTNativeExpressAdDelegete,TPSDKLoaderDelegate,GDTMediaViewDelegate>

@property (nonatomic,strong)GDTNativeExpressAd *nativeExpressAd;
@property (nonatomic,strong)GDTNativeExpressAdView *expressAdView;
@property (nonatomic,strong)GDTUnifiedNativeAd *nativeAd;
@property (nonatomic,strong)GDTUnifiedNativeAdDataObject *nativeAdDataObject;
@property (nonatomic,strong)GDTUnifiedNativeAdView *nativeAdView;

@property (nonatomic,assign)BOOL videoMute;
@property (nonatomic,assign)NSInteger auto_play_video;
@property (nonatomic,assign)NSInteger video_max_time;
@property (nonatomic,strong)UIImageView *mediaView;
@property (nonatomic,assign)BOOL isNativeBanner;
@property (nonatomic,copy)NSString *bidToken;
@property (nonatomic,copy)NSString *placementId;

@property (nonatomic,strong)NSArray *unifiedNativeAdDataObjects;
@end

@implementation TradPlusGDTMobNativeAdapter

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
    [[TradPlusGDTMobSDKLoader sharedInstance] setAudioSessionSettingWithExtraInfo:self.waterfallItem.extraInfoDictionary];
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
        return;;
    }
    if(item.secType == 2)
    {
        self.isNativeBanner = YES;
    }
    self.videoMute = YES;
    if(item.video_mute == 2)
    {
        self.videoMute = NO;
    }
    self.auto_play_video = item.auto_play_video;
    self.video_max_time = item.video_max_time;
    self.waterfallItem.nativeType = TPNativeADTYPE_Feed;
    if(item.is_template_rendering != 2 && item.is_template_rendering != 5)
    {
        self.waterfallItem.nativeType = TPNativeADTYPE_Template;
    }
    else if(item.is_template_rendering == 4 || item.is_template_rendering == 5)
    {
        self.waterfallItem.nativeType = TPNativeADTYPE_Paster;
    }
    if(self.waterfallItem.secType == 3)
    {
        self.waterfallItem.nativeType = TPNativeADTYPE_Draw;
    }
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
    if (self.waterfallItem.nativeType == TPNativeADTYPE_Template)
    {
        [self loadTemplateNativeAdWithPlacementId:self.placementId item:self.waterfallItem];
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
        return (self.expressAdView != nil);
    }
    else if(self.waterfallItem.nativeType == TPNativeADTYPE_Draw)
    {
        return (self.unifiedNativeAdDataObjects != nil);
    }
    else
    {
        return (self.nativeAdDataObject != nil);
    }
}

- (id)getCustomObject
{
    if(self.waterfallItem.nativeType == TPNativeADTYPE_Template)
    {
        return self.expressAdView;
    }
    else if(self.waterfallItem.nativeType == TPNativeADTYPE_Draw)
    {
        return self.unifiedNativeAdDataObjects;
    }
    else
    {
        return self.nativeAdDataObject;
    }
}

- (void)loadNativeAdWithPlacementId:(NSString *)placementId
{
    if(self.bidToken != nil)
    {
        self.nativeAd = [[GDTUnifiedNativeAd alloc] initWithPlacementId:placementId token:self.bidToken];
    }
    else
    {
        self.nativeAd = [[GDTUnifiedNativeAd alloc] initWithPlacementId:placementId];
    }
    self.nativeAd.delegate = self;
    if (self.waterfallItem.nativeType == TPNativeADTYPE_Draw)
    {
        [self.nativeAd loadAdWithAdCount:3];
    }
    else
    {
        [self.nativeAd loadAd];
    }
}

- (UIView *)endRender:(NSDictionary *)viewInfo clickView:(NSArray *)array
{
    UIView *adView = [viewInfo valueForKey:kTPRendererAdView];
    GDTUnifiedNativeAdView *nativeAdView = [[GDTUnifiedNativeAdView alloc] initWithFrame:adView.bounds];
    NSMutableArray *clickViews = [[NSMutableArray alloc] initWithArray:array];

    if([array containsObject:adView])
    {
        [clickViews removeObject:adView];
        UIView *clickView = [[UIView alloc] initWithFrame:adView.bounds];
        [nativeAdView insertSubview:clickView atIndex:0];
        [clickViews addObject:clickView];
    }
    nativeAdView.delegate = self;
    nativeAdView.viewController = self.rootViewController;
    [nativeAdView insertSubview:adView atIndex:0];
    if(!self.isNativeBanner)
    {
        UIView *view = viewInfo[kTPRendererMainImageView];
        if(view == nil)
        {
            view = viewInfo[kTPRendererMediaView];
        }
        if(view != nil)
        {
            if(self.nativeAdDataObject.isVideoAd)
            {
                nativeAdView.mediaView.frame = view.frame;
                if(self.waterfallItem.nativeType == TPNativeADTYPE_Paster)
                {
                    nativeAdView.mediaView.delegate = self;
                }
                view.hidden = YES;
                [clickViews removeObject:view];
            }
            else
            {
                self.mediaView.frame = view.bounds;
                [self.nativeAdDataObject bindImageViews:@[self.mediaView] placeholder:nil];
            }
        }
    }
    else
    {
        nativeAdView.mediaView.hidden = YES;
    }
    if(viewInfo[kTPRendererAdChoiceImageView])
    {
        UIView *view = viewInfo[kTPRendererAdChoiceImageView];
        CGRect rect = nativeAdView.logoView.bounds;
        rect.origin = view.frame.origin;
        CGFloat x = rect.origin.x + rect.size.width;
        if(x > nativeAdView.bounds.size.width)
        {
            rect.origin.x = CGRectGetMaxX(view.frame) - rect.size.width;
        }
        CGFloat y = rect.origin.y + rect.size.height;
        if(y > nativeAdView.bounds.size.height)
        {
            rect.origin.y = CGRectGetMaxY(view.frame) - rect.size.height;
        }
        nativeAdView.logoView.frame = rect;
    }
    [nativeAdView registerDataObject:self.nativeAdDataObject clickableViews:clickViews];
    self.nativeAdView = nativeAdView;
    return nativeAdView;
}

#pragma mark - GDTMediaViewDelegate
- (void)gdt_mediaViewDidTapped:(GDTMediaView *)mediaView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)gdt_mediaViewDidPlayFinished:(GDTMediaView *)mediaView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdPasterPlayFinish];
}

#pragma mark - GDTUnifiedNativeAdDelegate
- (void)gdt_unifiedNativeAdLoaded:(NSArray<GDTUnifiedNativeAdDataObject *> * _Nullable)unifiedNativeAdDataObjects error:(NSError * _Nullable)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(error != nil || unifiedNativeAdDataObjects == nil || unifiedNativeAdDataObjects.count == 0)
    {
        [self AdLoadFailWithError:error];
        return;
    }
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    if (self.waterfallItem.nativeType == TPNativeADTYPE_Draw)
    {
        self.unifiedNativeAdDataObjects = unifiedNativeAdDataObjects;
        res.drawList = self.unifiedNativeAdDataObjects;
    }
    else
    {
        GDTUnifiedNativeAdDataObject *adDataObject = unifiedNativeAdDataObjects.firstObject;
        res.title = adDataObject.title;
        res.body = adDataObject.desc;
        NSString *ctaText = @"打开";
        if(adDataObject.callToAction != nil)
        {
            ctaText = adDataObject.callToAction;
        }
        else if(adDataObject.isAppAd)
        {
            ctaText = @"下载";
        }
        res.ctaText = ctaText;
        if(adDataObject.iconUrl != nil)
        {
            res.iconImageURL = adDataObject.iconUrl;
            [self.downLoadURLArray addObject:res.iconImageURL];
        }
        if(!self.isNativeBanner)
        {
            self.mediaView = [[UIImageView alloc] init];
            res.mediaView = self.mediaView;
        }
        res.rating = @(adDataObject.appRating);
        res.price = [NSString stringWithFormat:@"%@",adDataObject.appPrice];
        res.videoDuration = adDataObject.duration;
        res.imageURLList = adDataObject.mediaUrlList;
        self.nativeAdDataObject = adDataObject;
        GDTVideoConfig *videoConfig = [[GDTVideoConfig alloc] init];
        videoConfig.videoMuted = self.videoMute;
        videoConfig.userControlEnable = YES;
        videoConfig.coverImageEnable = YES;
        videoConfig.autoPlayPolicy = GDTVideoAutoPlayPolicyNever;
        if(self.auto_play_video == 1)
        {
            videoConfig.autoPlayPolicy = GDTVideoAutoPlayPolicyAlways;
        }
        else if(self.auto_play_video == 2)
        {
            videoConfig.autoPlayPolicy = GDTVideoAutoPlayPolicyWIFI;
        }
        self.nativeAdDataObject.videoConfig = videoConfig;
    }
    self.waterfallItem.adRes = res;
    if(self.bidToken != nil)
    {
        [self.nativeAd setBidECPM:self.waterfallItem.adsourceplacement.bid_price];
    }
    [self AdLoadFinsh];
}

#pragma mark - GDTUnifiedNativeAdViewDelegate

- (void)gdt_unifiedNativeAdViewWillExpose:(GDTUnifiedNativeAdView *)unifiedNativeAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    if(self.auto_play_video == 3
       && self.nativeAdView.mediaView != nil)
    {
        [self.nativeAdView.mediaView play];
        [self.nativeAdView.mediaView stop];
    }
}

- (void)gdt_unifiedNativeAdViewDidClick:(GDTUnifiedNativeAdView *)unifiedNativeAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

#pragma mark - TemplateRender

- (void)loadTemplateNativeAdWithPlacementId:(NSString *)placementId item:(TradPlusAdWaterfallItem *)item
{
    if(self.bidToken != nil)
    {
        self.nativeExpressAd = [[GDTNativeExpressAd alloc] initWithPlacementId:placementId token:self.bidToken adSize:self.waterfallItem.templateRenderSize];
    }
    else
    {
        self.nativeExpressAd = [[GDTNativeExpressAd alloc] initWithPlacementId:placementId adSize:self.waterfallItem.templateRenderSize];
    }
    self.nativeExpressAd.videoMuted = self.videoMute;
    BOOL autoPlay = NO;
    if(self.auto_play_video == 1)
    {
        autoPlay = YES;
    }
    self.nativeExpressAd.videoAutoPlayOnWWAN = autoPlay;
    self.nativeExpressAd.delegate = self;
    if(self.video_max_time > 0)
    {
        self.nativeExpressAd.maxVideoDuration = self.video_max_time;
    }
    [self.nativeExpressAd loadAd:1];
}

- (void)templateRender:(UIView *)subView
{
    self.expressAdView.controller = self.rootViewController;
    if(self.waterfallItem.templateContentMode == TPTemplateContentModeScaleToFill)
    {
        self.expressAdView.frame = subView.bounds;
    }
    else
    {
        CGPoint center = CGPointZero;
        center.x = CGRectGetWidth(subView.bounds)/2;
        center.y = CGRectGetHeight(subView.bounds)/2;
        self.expressAdView.center = center;
    }
    [self.expressAdView render];
}

- (void)gdt_NativeExpressProAdViewClosed:(GDTNativeExpressProAdView *)nativeExpressProAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

#pragma mark - GDTNativeExpressAdDelegete

- (void)nativeExpressAdSuccessToLoad:(GDTNativeExpressAd *)nativeExpressAd views:(NSArray<__kindof GDTNativeExpressAdView *> *)views
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    if(views != nil && views.count > 0)
    {
        self.expressAdView = views.firstObject;
        res.adView = self.expressAdView;
    }
    self.waterfallItem.adRes = res;
    if(self.bidToken != nil)
    {
        [self.nativeExpressAd setBidECPM:self.waterfallItem.adsourceplacement.bid_price];
    }
    [self AdLoadFinsh];
}


- (void)nativeExpressAdFailToLoad:(GDTNativeExpressAd *)nativeExpressAd error:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__ , error);
    [self AdLoadFailWithError:error];
}


- (void)nativeExpressAdViewRenderFail:(GDTNativeExpressAdView *)nativeExpressAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSError *error = [NSError errorWithDomain:@"GDTMobNativeAdapter" code:14 userInfo:@{NSLocalizedDescriptionKey : @"Render Error"}];
    [self AdShowFailWithError:error];
}


- (void)nativeExpressAdViewExposure:(GDTNativeExpressAdView *)nativeExpressAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}


- (void)nativeExpressAdViewClicked:(GDTNativeExpressAdView *)nativeExpressAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)nativeExpressAdViewClosed:(GDTNativeExpressAdView *)nativeExpressAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}


- (void)nativeExpressAdView:(GDTNativeExpressAdView *)nativeExpressAdView playerStatusChanged:(GDTMediaPlayerStatus)status
{
    if(self.waterfallItem.nativeType == TPNativeADTYPE_Paster
       && status == GDTMediaPlayerStatusStoped)
    {
        [self AdPasterPlayFinish];
    }
    if (status == GDTMediaPlayerStatusStarted)
        [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
    if (status == GDTMediaPlayerStatusStoped)
        [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}
@end
