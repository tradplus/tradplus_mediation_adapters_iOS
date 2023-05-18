#import "TradPlusBigoNativeAdapter.h"
#import "TradPlusBigoSDKLoader.h"
#import <BigoADS/BigoNativeAdLoader.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSLogging.h>
#import "TPBigoAdapterBaseInfo.h"
#import <BigoADS/BigoAdSdk.h>

@interface TradPlusBigoNativeAdapter()<BigoNativeAdLoaderDelegate, BGVideoLifeCallbackDelegate,BigoAdInteractionDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) BigoNativeAd *nativeAd;
@property (nonatomic, strong) BigoAdLoader *adLoader;
@property (nonatomic, strong) BigoAdMediaView *mediaView;
@property (nonatomic, strong) BigoAdOptionsView *optionView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, copy) NSString *slotId;
@property (nonatomic, assign) BOOL videoMute;
@property (nonatomic, assign) BOOL isNativeBanner;
@property (nonatomic, assign) BOOL isS2SBidding;
@end

@implementation TradPlusBigoNativeAdapter

- (void)dealloc
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self destroy];
}

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
    else if([event isEqualToString:@"S2SBidding"])
    {
        [self initSDKS2SBidding];
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
    if(appId == nil  ||  appId.length <= 5)
    {
        MSLogTrace(@"Bigo init Config Error %@",config);
        return;
    }
    if([TradPlusBigoSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusBigoSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusBigoSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_BigoAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [[BigoAdSdk sharedInstance] getSDKVersionName];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_BigoAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

#pragma mark - S2SBidding
- (void)initSDKS2SBidding
{
    self.isS2SBidding = YES;
    [self initSDKWithWaterfallItem:self.waterfallItem initSource:2];
}

- (void)getBiddingToken
{
    NSString *token = [[BigoAdSdk sharedInstance] getBidderToken];
    if(token == nil)
    {
        token = @"";
    }
    NSString *version = [[BigoAdSdk sharedInstance] getSDKVersionName];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{@"token":token,@"version":version};
    [self ADLoadExtraCallbackWithEvent:@"S2SBiddingFinish" info:dic];
}

- (void)failS2SBiddingWithErrorStr:(NSString *)errorStr
{
    NSDictionary *dic = @{@"error":errorStr};
    [self ADLoadExtraCallbackWithEvent:@"S2SBiddingFail" info:dic];
}

- (void)initSDKWithWaterfallItem:(TradPlusAdWaterfallItem *)item initSource:(NSInteger)initSource
{
    NSString *appId = item.config[@"appId"];
    self.slotId = item.config[@"placementId"];
    if(appId == nil || self.slotId == nil || appId.length <= 5)
    {
        MSLogTrace(@"Bigo init Config Error %@",item.config);
        [self AdConfigError];
        return;
    }
    if([TradPlusBigoSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusBigoSDKLoader sharedInstance].initSource = initSource;
    }
    [[TradPlusBigoSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    [self initSDKWithWaterfallItem:item initSource:3];
}

- (void)loadAd
{
    if(self.waterfallItem.secType == 2)
    {
        self.isNativeBanner = YES;
    }
    self.videoMute = YES;
    if(self.waterfallItem.video_mute == 2)
    {
        self.videoMute = NO;
    }
    BigoNativeAdRequest *request = [[BigoNativeAdRequest alloc] initWithSlotId:self.slotId];
    self.adLoader = [[BigoNativeAdLoader alloc] initWithNativeAdLoaderDelegate:self];
    NSString *bidToken = nil;
    if(self.waterfallItem.adsourceplacement != nil)
    {
        bidToken = self.waterfallItem.adsourceplacement.adm;
    }
    if(bidToken != nil)
    {
        [request setServerBidPayload:bidToken];
    }
    [self.adLoader loadAd:request];
}

#pragma mark - TPSDKLoaderDelegate

- (void)tpInitFinish
{
    if(self.isS2SBidding)
    {
        [self getBiddingToken];
    }
    else
    {
        [self loadAd];
    }
}

- (void)tpInitFailWithError:(NSError *)error
{
    if(self.isS2SBidding)
    {
        NSString *errorStr = @"S2S Init Fail";
        if(error != nil)
        {
            errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.localizedDescription];
        }
        [self failS2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        [self AdLoadFailWithError:error];
    }
}
 
- (BOOL)isReady
{
    return !self.nativeAd.isExpired;
}

- (id)getCustomObject
{
    return self.nativeAd;
}

- (UIView *)endRender:(NSDictionary *)viewInfo clickView:(NSArray *)array
{
    UIView *adView = viewInfo[kTPRendererAdView];
    UIImageView *iconView = viewInfo[kTPRendererIconView];
    
    UIView *optionView = viewInfo[kTPRendererAdChoiceImageView];
    optionView.userInteractionEnabled = YES;
    
    UILabel *titleLab = viewInfo[kTPRendererTitleLable];
    titleLab.bigoNativeAdViewTag = BigoNativeAdViewTagTitle;
    
    UILabel *textLab = viewInfo[kTPRendererTextLable];
    textLab.bigoNativeAdViewTag = BigoNativeAdViewTagDescription;
    
    UILabel *ctaLab = viewInfo[kTPRendererCtaLabel];
    ctaLab.bigoNativeAdViewTag = BigoNativeAdViewTagCallToAction;
    
    [self.nativeAd registerViewForInteraction:adView mediaView:self.isNativeBanner ? nil : self.mediaView adIconView:iconView adOptionsView:self.optionView clickableViews:array];
    if(!self.isNativeBanner)
    {
        self.mediaView.videoController.delegate = self;
    }
    return nil;
}

- (void)destroy{
    [self.nativeAd destroy];
    self.nativeAd = nil;
}

#pragma mark - BigoNativeAdLoaderDelegate
- (void)onNativeAdLoaded:(BigoNativeAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    
    [ad setAdInteractionDelegate:self];
    self.nativeAd = ad;

    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    res.title = ad.title;
    res.body = ad.adDescription;
    res.ctaText = ad.callToAction;
    res.extraInfo[@"adWarning"] = ad.adWarning;
    
    res.iconImage = [[UIImage alloc] init];
    
    if(!self.isNativeBanner)
    {
        self.mediaView = [[BigoAdMediaView alloc] init];
        [self.mediaView.videoController mute:self.videoMute];
        res.mediaView = self.mediaView;
    }
    
    self.optionView = [[BigoAdOptionsView alloc] init];
    res.adChoiceView = self.optionView;

    self.waterfallItem.adRes = res;
    self.waterfallItem.extraInfoDictionary[@"splash_click_delay_close"] = @(1);
    self.waterfallItem.extraInfoDictionary[@"splash_remove_on_didappear"] = @(1);
    [self AdLoadFinsh];
}

- (void)onNativeAdLoadError:(BigoAdError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    NSInteger errorCode = 403;
    NSString *errorMsg = @"Load Fail";
    if(error != nil)
    {
        errorCode = error.errorCode;
        errorMsg = error.errorMsg;
    }
    NSError *loadError = [NSError errorWithDomain:@"Bigo.native" code:errorCode userInfo:@{NSLocalizedDescriptionKey:errorMsg}];
    [self AdLoadFailWithError:loadError];
}

#pragma mark - BGVideoLifeCallbackDelegate
- (void)onVideoStart:(BigoVideoController *)videoController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)onVideoEnd:(BigoVideoController *)videoController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}
- (void)onVideo:(BigoVideoController *)videoController mute:(BOOL)mute
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

#pragma mark - BigoAdInteractionDelegate
- (void)onAd:(BigoAd *)ad error:(BigoAdError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    NSInteger errorCode = 403;
    NSString *errorMsg = @"Show Fail";
    if(error != nil)
    {
        errorCode = error.errorCode;
        errorMsg = error.errorMsg;
    }
    NSError *showError = [NSError errorWithDomain:@"Bigo.native" code:errorCode userInfo:@{NSLocalizedDescriptionKey:errorMsg}];
    [self AdShowFailWithError:showError];
}

- (void)onAdImpression:(BigoAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)onAdClicked:(BigoAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

@end
