#import "TradPlusKlevinNativeAdapter.h"
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/MSLogging.h>
#import <KlevinAdSDK/KlevinAdSDK.h>
#import <KlevinAdSDK/KLNUnifiedNativeAd.h>
#import <KlevinAdSDK/KLNTemplateAd.h>
#import "TradPlusKlevinSDKLoader.h"
#import "TPKlevinAdapterBaseInfo.h"

@interface TradPlusKlevinNativeAdapter()<KLNUnifiedNativeAdDelegate,KLNTemplateAdDelegate,TPSDKLoaderDelegate>

@property (nonatomic,assign)BOOL isTemplateRender;
@property (nonatomic,strong)KLNUnifiedNativeAd *nativeAd;
@property (nonatomic,strong) KLNTemplateAd *templateAd;

@property (nonatomic,assign)BOOL videoMute;
@property (nonatomic,assign)NSInteger auto_play_video;
@property (nonatomic,assign)NSInteger video_max_time;
@property (nonatomic,strong)UIImageView *mediaView;
@property (nonatomic,assign)BOOL isNativeBanner;
@property (nonatomic,strong)NSString *placementId;
@property (nonatomic,assign)BOOL isC2SBidding;
@end

@implementation TradPlusKlevinNativeAdapter

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
    else if([event isEqualToString:@"C2SBidding"])
    {
        [self initSDKC2SBidding];
    }
    else if([event isEqualToString:@"LoadAdC2SBidding"])
    {
        [self loadAdC2SBidding];
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
        MSLogTrace(@"Klevin init Config Error %@",config);
        return;
    }
    if([TradPlusKlevinSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusKlevinSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusKlevinSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_KlevinAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [KlevinAdSDK sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_KlevinAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *appId = item.config[@"appId"];
    NSString *placementId = item.config[@"placementId"];
    if(appId == nil || placementId == nil)
    {
        [self AdConfigError];
        return;
    }
    self.waterfallItem.nativeType = TPNativeADTYPE_Feed;
    if (self.waterfallItem.is_template_rendering == 1)
        self.waterfallItem.nativeType = TPNativeADTYPE_Template;
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
    self.placementId = placementId;
    [[TradPlusKlevinSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    [[TradPlusKlevinSDKLoader sharedInstance] setPersonalizedAd];
    if (self.waterfallItem.is_template_rendering == 1)
        [self loadAdTemplate];
    else
        [self loadAdSelfRender];
}

- (void)loadAdTemplate
{
    KLNTemplateAdRequest *request = [[KLNTemplateAdRequest alloc] initWithPosId:self.placementId];
    request.adCount = 1;
    request.adSize = self.waterfallItem.templateRenderSize;
    __weak typeof(self)weakSelf = self;
    [KLNTemplateAd loadWithRequest:request completionHandler:^(NSArray<KLNTemplateAd *> * _Nullable adList, NSError * _Nullable error) {
        if(error == nil)
        {
            if (adList && adList.count > 0)
            {
                TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
                weakSelf.templateAd = adList.firstObject;
                weakSelf.templateAd.delegate = weakSelf;
                res.adView = weakSelf.templateAd.adView;
                weakSelf.waterfallItem.adRes = res;
                if(self.isC2SBidding)
                {
                    [self finishC2SBiddingWithEcpm:weakSelf.templateAd.eCPM];
                }
                else
                {
                    [weakSelf AdLoadFinsh];
                }
            }
            else
            {
                MSLogTrace(@"%s %@", __PRETTY_FUNCTION__, error);
                if(self.isC2SBidding)
                {
                    NSString *errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.description];
                    [self failC2SBiddingWithErrorStr:errorStr];
                }
                else
                {
                    NSError *error = [NSError errorWithDomain:@"Klevin" code:400 userInfo:@{NSLocalizedDescriptionKey: @"no fill"}];
                    [self AdLoadFailWithError:error];
                }
            }
        }
        else
        {
            MSLogTrace(@"%@->%@", error, weakSelf.placementId);
            if(self.isC2SBidding)
            {
                NSString *errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.description];
                [self failC2SBiddingWithErrorStr:errorStr];
            }
            else
            {
                [weakSelf AdLoadFailWithError:error];
            }
        }
    }];
}

- (void)loadAdSelfRender
{
    KLNUnifiedNativeAdRequest *request = [[KLNUnifiedNativeAdRequest alloc] initWithPosId:self.placementId];
    request.adCount = 1;
    __weak typeof(self)weakSelf = self;
    [KLNUnifiedNativeAd loadWithRequest:request completionHandler:^(NSArray<KLNUnifiedNativeAd *> * _Nullable adList, NSError * _Nullable error) {
        if(error == nil)
        {
            if (adList && adList.count > 0)
            {
                KLNUnifiedNativeAd *nativeAd = adList.firstObject;
                nativeAd.delegate = weakSelf;
            }
            else
            {
                NSError *error = [NSError errorWithDomain:@"Klevin" code:400 userInfo:@{NSLocalizedDescriptionKey: @"no fill"}];
                if(self.isC2SBidding)
                {
                    NSString *errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.description];
                    [self failC2SBiddingWithErrorStr:errorStr];
                }
                else
                {
                    [weakSelf AdLoadFailWithError:error];
                }
            }
        }
        else
        {
            MSLogTrace(@"%@->%@", error, weakSelf.placementId);
            if(self.isC2SBidding)
            {
                NSString *errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.description];
                [self failC2SBiddingWithErrorStr:errorStr];
            }
            else
            {
                [weakSelf AdLoadFailWithError:error];
            }
        }
    }];
}

- (void)templateRender:(UIView *)subView
{
    self.templateAd.viewController = self.rootViewController;
    if(self.waterfallItem.templateContentMode == TPTemplateContentModeScaleToFill)
    {
        self.templateAd.adView.frame = subView.bounds;
    }
    else
    {
        CGPoint center = CGPointZero;
        center.x = CGRectGetWidth(subView.bounds)/2;
        center.y = CGRectGetHeight(subView.bounds)/2;
        self.templateAd.adView.center = center;
    }
    [self.templateAd render];
}
#pragma mark - C2SBidding

- (void)initSDKC2SBidding
{
    self.isC2SBidding = YES;
    [self loadAdWithWaterfallItem:self.waterfallItem];
}

- (void)loadAdC2SBidding
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if([self isReady])
    {
        [self AdLoadFinsh];
    }
    else
    {
        NSError *loadError = [NSError errorWithDomain:@"Klevin" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S Native not ready"}];
        MSLogTrace(@"%s %@", __PRETTY_FUNCTION__, loadError);
        if(self.isC2SBidding)
        {
            NSString *errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)loadError.code, loadError.description];
            [self failC2SBiddingWithErrorStr:errorStr];
        }
        else
        {
            [self AdLoadFailWithError:loadError];
        }
    }
}

- (void)finishC2SBiddingWithEcpm:(NSInteger)ecpm
{
    NSString *version = TP_KlevinAdapter_PlatformSDK_Version;
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{@"ecpm":[NSString stringWithFormat:@"%ld", (long)ecpm],@"version":version};
    [self ADLoadExtraCallbackWithEvent:@"C2SBiddingFinish" info:dic];
}

- (void)failC2SBiddingWithErrorStr:(NSString *)errorStr
{
    NSDictionary *dic = @{@"error":errorStr};
    [self ADLoadExtraCallbackWithEvent:@"C2SBiddingFail" info:dic];
}


#pragma mark - TPSDKLoaderDelegate
- (void)tpInitFinish
{
    [self loadAd];
}

- (void)tpInitFailWithError:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__, error);
    if(self.isC2SBidding)
    {
        NSString *errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.description];
        [self failC2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        [self AdLoadFailWithError:error];
    }
}

- (BOOL)isReady
{
    if (self.waterfallItem.is_template_rendering == 1)
        return (self.templateAd != nil);
    else
        return (self.nativeAd != nil);
}

- (id)getCustomObject
{
    if (self.waterfallItem.is_template_rendering == 1)
        return self.templateAd;
    else
        return self.nativeAd;
}

- (UIView *)endRender:(NSDictionary *)viewInfo clickView:(NSArray *)array
{
    self.nativeAd.viewController = self.rootViewController;
    UIView *adView = [viewInfo valueForKey:kTPRendererAdView];
    [self.nativeAd registerWithClickableViews:array adView:adView];
    if(!self.isNativeBanner)
    {
        [self.nativeAd render];
    }
    return nil;
}

#pragma mark - GDTUnifiedNativeAdDelegate
- (void)kln_unifiedNativeAdDidLoad:(KLNUnifiedNativeAd *)ad didCompleteWithError:(NSError *_Nullable)error
{
    if(error != nil || ad == nil)
    {
        MSLogTrace(@"%s %@", __PRETTY_FUNCTION__, error);
        if(self.isC2SBidding)
        {
            NSString *errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.description];
            [self failC2SBiddingWithErrorStr:errorStr];
        }
        else
        {
            [self AdLoadFailWithError:error];
        }
        return;
    }
    self.nativeAd = ad;
    self.nativeAd.muted = YES;
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    res.title = ad.title;
    res.body = ad.desc;
    res.ctaText = ad.actionTitle;
    if (ad.appIconURL != nil)
    {
        res.iconImageURL = ad.appIconURL;
        [self.downLoadURLArray addObject:res.iconImageURL];
    }
    if(ad.adLogoImage != nil)
    {
        res.adChoiceImage = ad.adLogoImage;
    }
    if(!self.isNativeBanner)
    {
        res.mediaView = ad.adView;
    }
    self.waterfallItem.adRes = res;
    if(self.isC2SBidding)
    {
        [self finishC2SBiddingWithEcpm:ad.eCPM];
    }
    else
    {
        [self AdLoadFinsh];
    }
}

#pragma mark - GDTUnifiedNativeAdViewDelegate

- (void)kln_unifiedNativeAdWillExpose:(KLNUnifiedNativeAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)kln_unifiedNativeAdDidClick:(KLNUnifiedNativeAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

#pragma mark - KLNTemplateAdDelegate
- (void)kln_templateAdWillExpose:(KLNTemplateAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)kln_templateAdDidClick:(KLNTemplateAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)kln_templateAdClosed:(KLNTemplateAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

- (void)kln_templateAdRenderSuccess:(KLNTemplateAd *)ad
{
    
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.isC2SBidding)
    {
        [self finishC2SBiddingWithEcpm:ad.eCPM];
    }
    else
    {
        [self AdLoadFinsh];
    }
}

- (void)kln_templateAdRenderFail:(KLNTemplateAd *)ad error:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__, error);
    if(self.isC2SBidding)
    {
        NSString *errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.description];
        [self failC2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        [self AdLoadFailWithError:error];
    }
}

- (void)kln_templateAdDidCloseOtherController:(KLNTemplateAd *)ad interactionType:(KLNInteractionType)interactionType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

@end
