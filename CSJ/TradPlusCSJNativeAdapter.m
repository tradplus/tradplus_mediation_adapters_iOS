#import "TradPlusCSJNativeAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MsCommon.h>
#import "TradPlusCSJSDKLoader.h"
#import <BUAdSDK/BUAdSDK.h>
#import <BUAdSDK/BUNativeAd.h>
#import <BUAdSDK/BUNativeAdRelatedView.h>
#import <BUAdSDK/BUNativeExpressAdManager.h>
#import "TPCSJAdapterBaseInfo.h"

@interface TradPlusCSJNativeAdapter()<BUNativeAdDelegate,BUNativeExpressAdViewDelegate,TPSDKLoaderDelegate,BUVideoAdViewDelegate>

@property (nonatomic, strong)BUNativeExpressAdManager *nativeExpressAdManager;
@property (nonatomic, strong)BUNativeExpressAdView *expressView;
@property (nonatomic, strong)BUNativeAdRelatedView *relatedView;
@property (nonatomic,strong)BUNativeAd *nativeAd;
@property (nonatomic,assign)BOOL isNativeBanner;
@property (nonatomic,copy)NSString *placementId;
@property (nonatomic,strong)NSArray *drawList;
@property (nonatomic,copy)NSString *appId;
@property (nonatomic,assign) NSInteger ecpm;
@property (nonatomic,assign) BOOL isC2SBidding;
@property (nonatomic,assign) BOOL didWin;
@property (nonatomic,assign) BOOL isDislike;

@end

@implementation TradPlusCSJNativeAdapter

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
    else if([event isEqualToString:@"C2SLoss"])
    {
        [self sendC2SLoss:config];
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
        MSLogTrace(@"CSJ init Config Error %@",config);
        return;
    }
    if([TradPlusCSJSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusCSJSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusCSJSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_CSJAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [TradPlusCSJSDKLoader getSDKVersion];
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_CSJAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

#pragma mark - 普通

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    [self initSDKWithWaterfallItem:item initSource:3];
}

- (void)initSDKWithWaterfallItem:(TradPlusAdWaterfallItem *)item initSource:(NSInteger)initSource
{
    self.appId = item.config[@"appId"];
    self.placementId = item.config[@"placementId"];
    if(self.placementId == nil || self.appId == nil)
    {
        [self AdConfigError];
        return;
    }
    if([TradPlusCSJSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusCSJSDKLoader sharedInstance].initSource = initSource;
    }
    [[TradPlusCSJSDKLoader sharedInstance] setAllowModifyAudioSessionSettingWithExtraInfo:self.waterfallItem.extraInfoDictionary];
    [[TradPlusCSJSDKLoader sharedInstance] initWithAppID:self.appId delegate:self];
}

#pragma mark - TPSDKLoaderDelegate
- (void)tpInitFinish
{
    [self loadAd];
}

- (void)tpInitFailWithError:(NSError *)error
{
    if(self.isC2SBidding)
    {
        NSString *errorStr = @"C2S Init Fail";
        if(error != nil)
        {
            errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.localizedDescription];
        }
        [self failC2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        [self AdLoadFailWithError:error];
    }
}

- (void)loadAd
{
    [[TradPlusCSJSDKLoader sharedInstance] setPersonalizedAd];
    self.waterfallItem.nativeType = TPNativeADTYPE_Feed;
    if(self.waterfallItem.is_template_rendering == 1)
    {
        self.waterfallItem.nativeType = TPNativeADTYPE_Template;
    }
    else if(self.waterfallItem.is_template_rendering == 3)
    {
        self.waterfallItem.nativeType = TPNativeADTYPE_Paster;
    }
    if(self.waterfallItem.secType == 2)
    {
        self.isNativeBanner = YES;
    }
    else if(self.waterfallItem.secType == 3)
    {
        self.waterfallItem.nativeType = TPNativeADTYPE_Draw;
    }
    if(self.waterfallItem.nativeType == TPNativeADTYPE_Template || self.waterfallItem.nativeType == TPNativeADTYPE_Draw)
    {
        [self loadTemplateNativeAdWithPlacementId:self.placementId];
    }
    else
    {
        [self loadNativeAdWithPlacementId:self.placementId];
    }
}

- (BOOL)isReady
{
    if(self.waterfallItem.nativeType == TPNativeADTYPE_Template)
    {
        return (self.expressView != nil);
    }
    else if(self.waterfallItem.nativeType == TPNativeADTYPE_Draw)
    {
        return (self.drawList != nil);
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
        return self.expressView;
    }
    else if(self.waterfallItem.nativeType == TPNativeADTYPE_Draw)
    {
        return self.drawList;
    }
    else
    {
        return self.nativeAd;
    }
}

- (UIView *)endRender:(NSDictionary *)viewInfo clickView:(NSArray *)array
{
    UIView *adView = viewInfo[kTPRendererAdView];
    self.nativeAd.rootViewController = self.rootViewController;
    [self.nativeAd registerContainer:adView withClickableViews:array];
    return nil;
}

#pragma mark - C2SBidding

- (void)initSDKC2SBidding
{
    self.isC2SBidding = YES;
    [self initSDKWithWaterfallItem:self.waterfallItem initSource:2];
}

- (void)loadAdC2SBidding
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if([self isReady])
    {
        [self sendC2SWin];
        [self AdLoadFinsh];
    }
    else
    {
        NSError *loadError = [NSError errorWithDomain:@"CSJ.native" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S Native not ready"}];
        [self AdLoadFailWithError:loadError];
    }
}

- (void)finishC2SBidding
{
    NSString *version = [TradPlusCSJSDKLoader getSDKVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSString *ecpm = [NSString stringWithFormat:@"%@",@(self.ecpm)];
    NSDictionary *dic = @{@"ecpm":ecpm,@"version":version};
    [self ADLoadExtraCallbackWithEvent:@"C2SBiddingFinish" info:dic];
}

- (void)failC2SBiddingWithErrorStr:(NSString *)errorStr
{
    NSDictionary *dic = @{@"error":errorStr};
    [self ADLoadExtraCallbackWithEvent:@"C2SBiddingFail" info:dic];
}

- (void)sendC2SWin
{
    if(!self.isC2SBidding)
    {
        return;
    }
    self.didWin = YES;
    if(self.waterfallItem.nativeType == TPNativeADTYPE_Template)
    {
        [self.expressView win:@(self.ecpm)];
    }
    else
    {
        [self.nativeAd win:@(self.ecpm)];
    }
}

- (void)sendC2SLoss:(NSDictionary *)config
{
    NSString *topPirce = config[@"topPirce"];
    if(self.didWin)return;
    if(self.waterfallItem.nativeType == TPNativeADTYPE_Template)
    {
        [self.expressView loss:@([topPirce intValue]) lossReason:@"102" winBidder:nil];
    }
    else
    {
        [self.nativeAd loss:@([topPirce intValue]) lossReason:@"102" winBidder:nil];
    }
}

#pragma mark - NativeAd
- (void)loadNativeAdWithPlacementId:(NSString *)placementId
{
    BUAdSlot *slot = [[BUAdSlot alloc] init];
    if(self.waterfallItem.nativeType == TPNativeADTYPE_Paster)
    {
        slot.AdType = BUAdSlotAdTypePaster;
    }
    else
    {
        slot.AdType = BUAdSlotAdTypeFeed;
    }
    slot.position = BUAdSlotPositionTop;
    slot.imgSize = [BUSize sizeBy:BUProposalSize_Feed690_388];
    self.nativeAd = [[BUNativeAd alloc] initWithSlot:slot];
    self.nativeAd.delegate = self;
    self.nativeAd.adslot.ID = placementId;
    [self.nativeAd loadAdData];
}

#pragma mark - BUNativeAdDelegate
- (void)nativeAdDidLoad:(BUNativeAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    BUMaterialMeta *data = self.nativeAd.data;
    res.title = data.AdTitle;
    res.body = data.AdDescription;
    res.ctaText = data.buttonText;
    res.rating = @(data.score);
    res.commentNum = data.commentNum;
    res.source = data.source;
    res.videoUrl = data.videoUrl;
    res.videoDuration = data.videoDuration;
    if(data.icon.imageURL != nil)
    {
        res.iconImageURL = data.icon.imageURL;
        [self.downLoadURLArray addObject:res.iconImageURL];
    }
    self.relatedView = [[BUNativeAdRelatedView alloc] init];
    [self.relatedView refreshData:self.nativeAd];
    res.adChoiceView = self.relatedView.logoImageView;
    if(!self.isNativeBanner)
    {
        if (self.nativeAd.data.imageMode == BUFeedVideoAdModeImage ||
            self.nativeAd.data.imageMode == BUFeedVideoAdModePortrait ||
            self.nativeAd.data.imageMode == BUFeedADModeSquareVideo)
        {
            res.mediaView = self.relatedView.videoAdView;
            if(self.waterfallItem.is_template_rendering == 3)
            {
                self.relatedView.videoAdView.delegate = self;
                res.isCustomVideoPaster = YES;
            }
        }
        else
        {
            if(data.imageAry != nil && data.imageAry.count > 0)
            {
                BUImage *image = data.imageAry.firstObject;
                res.mediaImageURL = image.imageURL;
                [self.downLoadURLArray addObject:res.mediaImageURL];
                if(data.imageAry.count > 1)
                {
                    NSMutableArray *urlArray = [[NSMutableArray alloc] init];
                    for(BUImage *image in data.imageAry)
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
    self.waterfallItem.adRes = res;
    if(self.isC2SBidding)
    {
        if(![nativeAd.data.mediaExt valueForKey:@"price"])
        {
            NSString *errorStr = @"C2S Bidding Fail.[竞价失败，请确认是否已开启穿山甲竞价功能]";
            MSLogInfo(@"%@", errorStr);
            [self failC2SBiddingWithErrorStr:errorStr];
            return;
        }
        self.ecpm = [[nativeAd.data.mediaExt valueForKey:@"price"] integerValue];
        [self finishC2SBidding];
    }
    else
    {
        [self AdLoadFinsh];
    }
}

- (void)nativeAd:(BUNativeAd *)nativeAd didFailWithError:(NSError *_Nullable)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__ , error);
    [self AdLoadFailWithError:error];
}

- (void)nativeAdDidBecomeVisible:(BUNativeAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)nativeAdDidClick:(BUNativeAd *)nativeAd withView:(UIView *_Nullable)view
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

#pragma mark - TemplateRender

- (void)loadTemplateNativeAdWithPlacementId:(NSString *)placementId
{
    BUAdSlot *slot = [[BUAdSlot alloc] init];
    slot.ID = placementId;
    BUSize *imgSize = [BUSize sizeBy:BUProposalSize_Feed228_150];
    if(self.waterfallItem.nativeType == TPNativeADTYPE_Draw)
    {
        slot.AdType = BUAdSlotAdTypeDrawVideo;
        imgSize = [BUSize sizeBy:BUProposalSize_DrawFullScreen];
    }
    else
    {
        slot.AdType = BUAdSlotAdTypeFeed;
    }
    slot.supportRenderControl = YES;
    slot.imgSize = imgSize;
    slot.position = BUAdSlotPositionFeed;
    CGSize size = self.waterfallItem.templateRenderSize;
    self.nativeExpressAdManager = [[BUNativeExpressAdManager alloc] initWithSlot:slot adSize:size];
    self.nativeExpressAdManager.delegate = self;
    if(self.waterfallItem.nativeType == TPNativeADTYPE_Draw)
    {
        [self.nativeExpressAdManager loadAdDataWithCount:3];
    }
    else
    {
        [self.nativeExpressAdManager loadAdDataWithCount:1];
    }
}

- (void)templateRender:(UIView *)subView
{
    if(self.waterfallItem.templateContentMode == TPTemplateContentModeScaleToFill)
    {
        self.expressView.frame = subView.bounds;
    }
    else//TPTemplateContentModeCenter
    {
        CGPoint center = CGPointZero;
        center.x = CGRectGetWidth(subView.bounds)/2;
        center.y = CGRectGetHeight(subView.bounds)/2;
        self.expressView.center = center;
    }
    [self.expressView render];
}

#pragma mark - BUNativeExpressAdViewDelegate
- (void)nativeExpressAdSuccessToLoad:(BUNativeExpressAdManager *)nativeExpressAdManager views:(NSArray<__kindof BUNativeExpressAdView *> *)views
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    if(self.waterfallItem.nativeType == TPNativeADTYPE_Draw)
    {
        self.drawList = views;
        res.drawList = self.drawList;
    }
    else
    {
        if(views != nil && views.count > 0)
        {
            self.expressView = views.firstObject;
            res.adView = self.expressView;
        }
    }
    self.waterfallItem.adRes = res;
    self.isAdReady = YES;
    if(self.isC2SBidding)
    {
        if(![self.expressView.mediaExt valueForKey:@"price"]){
            NSString *errorStr = @"C2S Bidding Fail.[竞价失败，请确认是否已开启穿山甲竞价功能]";
            MSLogInfo(@"%@", errorStr);
            [self failC2SBiddingWithErrorStr:errorStr];
            return;
        }
        self.ecpm = [[self.expressView.mediaExt valueForKey:@"price"] integerValue];
        [self finishC2SBidding];
    }
    else
    {
        [self AdLoadFinsh];
    }
}


- (void)nativeExpressAdFailToLoad:(BUNativeExpressAdManager *)nativeExpressAdManager error:(NSError *_Nullable)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__ ,error);
    if(self.isC2SBidding)
    {
        NSString *errorStr = @"C2S Bidding Fail";
        if(error != nil)
        {
            errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.description];
        }
        [self failC2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        NSString *errorStr = @"Load Fail";
        if(error != nil)
        {
            errorStr = error.description;
        }
        NSError *loadError = [NSError errorWithDomain:@"CSJ.native" code:error.code userInfo:@{NSLocalizedDescriptionKey : errorStr}];
        [self AdLoadFailWithError:loadError];
    }
}

- (void)nativeExpressAdViewWillShow:(BUNativeExpressAdView *)nativeExpressAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.waterfallItem.nativeType == TPNativeADTYPE_Draw)
    {
        [self AdShowNoLimit];
    }
    else
    {
        [self AdShow];
    }
}

- (void)nativeExpressAdViewDidClick:(BUNativeExpressAdView *)nativeExpressAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.waterfallItem.nativeType == TPNativeADTYPE_Draw)
    {
        //设置 addClickEvent = 2，添加额外的点击埋点 （Draw信息流）
        self.waterfallItem.extraInfoDictionary[@"addClickEvent"] = @(2);
    }
    [self AdClick];
}


- (void)nativeExpressAdViewRenderFail:(BUNativeExpressAdView *)nativeExpressAdView error:(NSError *_Nullable)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdShowFailWithError:error];
    
}

- (void)nativeExpressAdViewDidRemoved:(BUNativeExpressAdView *)nativeExpressAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.isDislike) return;
    [self AdClose];
}

- (void)nativeExpressAdView:(BUNativeExpressAdView *)nativeExpressAdView stateDidChanged:(BUPlayerPlayState)playerState
{
    if (playerState == BUPlayerStatePlaying)
        [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)nativeExpressAdViewPlayerDidPlayFinish:(BUNativeExpressAdView *)nativeExpressAdView error:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}

- (void)nativeExpressAdView:(BUNativeExpressAdView *)nativeExpressAdView dislikeWithReason:(NSArray<BUDislikeWords *> *)filterWords
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.isDislike = YES;
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    if(filterWords != nil && filterWords.count >0)
    {
        BUDislikeWords * dislikeWords = filterWords[0];
        dic[@"dislikeInfo"] = dislikeWords.name;
        dic[@"dislikeObject"] = filterWords;
        [self ADShowExtraCallbackWithEvent:@"tradplus_native_dislike" info:dic];
    }
    else
    {
        dic[@"dislikeInfo"] = @"用户关闭";
        [self ADShowExtraCallbackWithEvent:@"tradplus_native_dislike" info:dic];
    }
}

#pragma mark - BUVideoAdViewDelegate

- (void)videoAdView:(BUVideoAdView *)videoAdView didLoadFailWithError:(NSError *_Nullable)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShowFailWithError:error];
}

- (void)playerDidPlayFinish:(BUVideoAdView *)videoAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdPasterPlayFinish];
}

- (void)videoAdViewDidClick:(BUVideoAdView *)videoAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)playerReadyToPlay:(BUVideoAdView *)videoAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)videoAdView:(BUVideoAdView *)videoAdView stateDidChanged:(BUPlayerPlayState)playerState
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)videoAdViewFinishViewDidClick:(BUVideoAdView *)videoAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)videoAdViewDidCloseOtherController:(BUVideoAdView *)videoAdView interactionType:(BUInteractionType)interactionType
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

#pragma mark - TPCSJPasterProtocol


- (void)startPlayVideo
{
    if(self.relatedView)
    {
        MSLogTrace(@"%s", __PRETTY_FUNCTION__);
        [self.relatedView.videoAdReportor startPlayVideo];
    }
}
- (void)didStartPlayVideoWithVideoDuration:(NSTimeInterval)duration
{
    if(self.relatedView)
    {
        MSLogTrace(@"%s", __PRETTY_FUNCTION__);
        [self.relatedView.videoAdReportor didStartPlayVideoWithVideoDuration:duration];
    }
}
- (void)didAutoStartPlayWithVideoDuration:(NSTimeInterval)duration
{
    if(self.relatedView)
    {
        MSLogTrace(@"%s", __PRETTY_FUNCTION__);
        [self.relatedView.videoAdReportor didAutoStartPlayWithVideoDuration:duration];
    }
}

- (void)didFinishVideo
{
    if(self.relatedView)
    {
        MSLogTrace(@"%s", __PRETTY_FUNCTION__);
        [self.relatedView.videoAdReportor didFinishVideo];
    }
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}
- (void)didPauseVideoWithCurrentDuration:(NSTimeInterval)duration
{
    if(self.relatedView)
    {
        MSLogTrace(@"%s", __PRETTY_FUNCTION__);
        [self.relatedView.videoAdReportor didPauseVideoWithCurrentDuration:duration];
    }
}
- (void)didResumeVideoWithCurrentDuration:(NSTimeInterval)duration
{
    if(self.relatedView)
    {
        MSLogTrace(@"%s", __PRETTY_FUNCTION__);
        [self.relatedView.videoAdReportor didResumeVideoWithCurrentDuration:duration];
    }
}
- (void)didBreakVideoWithCurrentDuration:(NSTimeInterval)duration
{
    if(self.relatedView)
    {
        MSLogTrace(@"%s", __PRETTY_FUNCTION__);
        [self.relatedView.videoAdReportor didBreakVideoWithCurrentDuration:duration];
    }
}
- (void)didClickVideoViewWithCurrentDuration:(NSTimeInterval)duration
{
    if(self.relatedView)
    {
        MSLogTrace(@"%s", __PRETTY_FUNCTION__);
        [self.relatedView.videoAdReportor didClickVideoViewWithCurrentDuration:duration];
    }
}
- (void)didPlayFailedWithError:(NSError *)error
{
    if(self.relatedView)
    {
        MSLogTrace(@"%s", __PRETTY_FUNCTION__);
        [self.relatedView.videoAdReportor didPlayFailedWithError:error];
    }
}
- (void)didPlayStartFailedWithError:(NSError *)error
{
    if(self.relatedView)
    {
        MSLogTrace(@"%s", __PRETTY_FUNCTION__);
        [self.relatedView.videoAdReportor didPlayStartFailedWithError:error];
    }
}
- (void)didPlayBufferStart
{
    if(self.relatedView)
    {
        MSLogTrace(@"%s", __PRETTY_FUNCTION__);
        [self.relatedView.videoAdReportor didPlayBufferStart];
    }
}
- (void)didPlayBufferEnd
{
    if(self.relatedView)
    {
        MSLogTrace(@"%s", __PRETTY_FUNCTION__);
        [self.relatedView.videoAdReportor didPlayBufferEnd];
    }
}

- (NSArray <UIView *>*)getDrawList
{
    for(BUNativeExpressAdView *expressView in self.drawList)
    {
        [expressView render];
    }
    return self.drawList;
}

- (UIView *)drawRender:(UIView *)subView
{
    self.expressView = self.drawList.firstObject;
    self.expressView.frame = subView.bounds;
    [self.expressView render];
    return self.expressView;
}
@end
