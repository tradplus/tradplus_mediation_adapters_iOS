#import "TradPlusSigmobNativeAdapter.h"
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSLogging.h>
#import <WindSDK/WindSDK.h>
#import "TradPlusSigmobSDKLoader.h"
#import "TPSigmobAdapterBaseInfo.h"

@interface TradPlusSigmobNativeAdapter()<WindNativeAdsManagerDelegate, WindNativeAdViewDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) WindNativeAdsManager *nativeManager;
@property (nonatomic, strong) WindNativeAd *nativeAd;
@property (nonatomic, strong) UIImageView *mediaView;
@property (nonatomic, assign) BOOL isNativeBanner;
@property (nonatomic, strong) NSString *placementId;
@end

@implementation TradPlusSigmobNativeAdapter

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
        MSLogTrace(@"Sigmob init Config Error %@",config);
        return;
    }
    if([TradPlusSigmobSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusSigmobSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusSigmobSDKLoader sharedInstance] initWithAppID:appId appKey:appKey delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_SigmobAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [WindAds sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_SigmobAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *appId = item.config[@"appId"];
    NSString *appKey = item.config[@"AppKey"];
    self.placementId = item.config[@"placementId"];
    if(appId == nil || appKey == nil || self.placementId == nil)
    {
        [self AdConfigError];
        return;
    }
    self.waterfallItem.nativeType = TPNativeADTYPE_Feed;
    if(item.secType == 2)
    {
        self.isNativeBanner = YES;
    }
    [[TradPlusSigmobSDKLoader sharedInstance] initWithAppID:appId appKey:appKey delegate:self];
    
}

- (void)loadAd
{
    [[TradPlusSigmobSDKLoader sharedInstance] setPersonalizedAd];
    WindAdRequest *request = [WindAdRequest request];
    request.placementId = self.placementId;
    self.nativeManager = [[WindNativeAdsManager alloc] initWithRequest:request];
    self.nativeManager.delegate = self;
    NSString *bidToken = nil;
    if(self.waterfallItem.adsourceplacement != nil)
    {
        bidToken = self.waterfallItem.adsourceplacement.adm;
    }
    if(bidToken == nil)
    {
        [self.nativeManager loadAdDataWithCount:1];
    }
    else
    {
        [self.nativeManager loadAdDataWithBitToken:bidToken adCount:1];
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
    return (self.nativeAd != nil);
}

- (id)getCustomObject
{
    return self.nativeAd;
}

- (UIView *)endRender:(NSDictionary *)viewInfo clickView:(NSArray *)array
{
    UIView *adView = [viewInfo valueForKey:kTPRendererAdView];
    WindNativeAdView *sigmobView = [[WindNativeAdView alloc] init];
    [sigmobView refreshData:self.nativeAd];
    sigmobView.frame = adView.bounds;
    sigmobView.delegate = self;
    sigmobView.viewController = self.rootViewController;
    sigmobView.mediaView.frame = self.mediaView.frame;
    sigmobView.backgroundColor = [UIColor clearColor];
    [adView insertSubview:sigmobView atIndex:0];
    
    UIView *adChoiceView = viewInfo[kTPRendererAdChoiceImageView];
    if (adChoiceView != nil)
    {
        sigmobView.logoView.frame = adChoiceView.frame;
    }
    
    NSMutableArray *clickArray = [[NSMutableArray alloc] initWithArray:array];
    if (!self.isNativeBanner)
    {
        [sigmobView bindImageViews:@[self.mediaView] placeholder:nil];
    }
    if(self.nativeAd.feedADMode == WindFeedADModeVideo
       || self.nativeAd.feedADMode == WindFeedADModeVideoPortrait
       || self.nativeAd.feedADMode == WindFeedADModeVideoLandSpace)
    {
        UIView *mediaView = viewInfo[kTPRendererMainImageView];
        if(mediaView == nil)
        {
            mediaView = viewInfo[kTPRendererMediaView];
        }
        if(mediaView != nil)
        {
            if (!self.isNativeBanner)
            {
                mediaView.hidden = YES;
                sigmobView.mediaView.frame = mediaView.frame;
                if([clickArray containsObject:mediaView])
                {
                    [clickArray removeObject:mediaView];
                }
            }
        }
    }
    if([clickArray containsObject:adView])
    {
        [clickArray removeObject:adView];
        [clickArray addObject:sigmobView];
    }
    [sigmobView setClickableViews:clickArray];
    return nil;
}

#pragma mark - WindNativeAdsManagerDelegate
- (void)nativeAdsManagerSuccessToLoad:(WindNativeAdsManager *)adsManager nativeAds:(NSArray<WindNativeAd *> *)nativeAdDataArray
{
    NSArray <WindNativeAd *> *nativeAdList = [nativeAdDataArray copy];
    if (nativeAdList == nil || nativeAdList.count == 0)
    {
        [self AdLoadFailWithError:nil];
        return;
    }
    WindNativeAd *nativeAd = nativeAdList[0];
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    res.title = nativeAd.title;
    res.body = nativeAd.desc;
    res.ctaText = nativeAd.callToAction?:@"下载";
    if (nativeAd.iconUrl != nil)
    {
        res.iconImageURL = nativeAd.iconUrl;
        [self.downLoadURLArray addObject:res.iconImageURL];
    }
    if (!self.isNativeBanner)
    {
        self.mediaView = [[UIImageView alloc] init];
        res.mediaView = self.mediaView;
    }
    res.rating = @(nativeAd.rating);
    self.nativeAd = nativeAd;
    self.waterfallItem.adRes = res;
    MSLogTrace(@"Sigmob.rating--%@",res.rating);
    [self AdLoadFinsh];
}

- (void)nativeAdsManager:(WindNativeAdsManager *)adsManager didFailWithError:(NSError *)error
{
    MSLogTrace(@"%s->%@", __PRETTY_FUNCTION__, error);
    [self AdLoadFailWithError:error];
}

#pragma mark - WindNativeAdViewDelegate

- (void)nativeAdViewWillExpose:(WindNativeAdView *)nativeAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)nativeAdViewDidClick:(WindNativeAdView *)nativeAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)nativeAdDetailViewClosed:(WindNativeAdView *)nativeAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeAdViewApplicationWillEnterBackground:(WindNativeAdView *)nativeAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeAdDetailViewWillPresentScreen:(WindNativeAdView *)nativeAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeAdView:(WindNativeAdView *)nativeAdView playerStatusChanged:(WindMediaPlayerStatus)status userInfo:(NSDictionary *)userInfo
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if (status == WindMediaPlayerStatusStarted)
        [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
    if (status == WindMediaPlayerStatusStoped)
        [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}

- (void)nativeAdView:(WindNativeAdView *)nativeAdView dislikeWithReason:(NSArray<WindDislikeWords *> *)filterWords
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    if(filterWords != nil && filterWords.count >0)
    {
        WindDislikeWords * dislikeWords = filterWords[0];
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


@end
