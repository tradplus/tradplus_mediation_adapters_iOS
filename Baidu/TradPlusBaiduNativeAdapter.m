#import "TradPlusBaiduNativeAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <BaiduMobAdSDK/BaiduMobAdNative.h>
#import <BaiduMobAdSDK/BaiduMobAdNativeAdObject.h>
#import <BaiduMobAdSDK/BaiduMobAdNativeVideoView.h>
#import <BaiduMobAdSDK/BaiduMobAdNativeWebView.h>
#import <BaiduMobAdSDK/BaiduMobAdSmartFeedView.h>
#import <BaiduMobAdSDK/BaiduMobAdSetting.h>
#import "TradPlusBaiduSDKSetting.h"
#import "TPBaiduAdapterBaseInfo.h"

@interface TradPlusBaiduNativeAdapter()<BaiduMobAdNativeAdDelegate,BaiduMobAdNativeInterationDelegate>

@property (nonatomic, strong) BaiduMobAdNative *native;
@property (nonatomic, strong) BaiduMobAdNativeAdObject *nativeAdObject;
@property (nonatomic, strong) BaiduMobAdNativeVideoView *videoView;
@property (nonatomic, strong) BaiduMobAdNativeWebView *webView;
@property (nonatomic, strong) BaiduMobAdSmartFeedView *smartFeedView;
@property (nonatomic, strong) UIView *adView;
@property (nonatomic, assign) BOOL isTemplateRender;
@property (nonatomic, assign) BOOL isNativeBanner;
@property (nonatomic, assign) BOOL videoMute;
@property (nonatomic, assign) BOOL isC2SBidding;
@end

@implementation TradPlusBaiduNativeAdapter

#pragma mark - Extra
- (BOOL)extraActWithEvent:(NSString *)event info:(NSDictionary *)config
{
    if([event isEqualToString:@"AdapterVersion"])
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

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_BaiduAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = SDK_VERSION_IN_MSSP;
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_BaiduAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    [BaiduMobAdSetting sharedInstance].supportHttps = NO;
    NSString *appId = item.config[@"appId"];
    NSString *placementId = item.config[@"placementId"];
    if(placementId == nil || appId == nil)
    {
        [self AdConfigError];
        return;
    }
    [[TradPlusBaiduSDKSetting sharedInstance] setPersonalizedAd];
    self.waterfallItem.nativeType = TPNativeADTYPE_Feed;
    if(item.is_template_rendering == 1)
    {
        self.waterfallItem.nativeType = TPNativeADTYPE_Template;
        self.isTemplateRender = YES;
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
    self.native = [[BaiduMobAdNative alloc] init];
    self.native.adDelegate = self;
    self.native.publisherId = appId;
    self.native.adUnitTag = placementId;
    [self.native requestNativeAds];
}

- (id)getCustomObject
{
    return self.nativeAdObject;
}

- (BOOL)isReady
{
    return ![self.nativeAdObject isExpired];
}

- (void)templateRender:(UIView *)subView
{
    if(self.waterfallItem.templateContentMode == TPTemplateContentModeScaleToFill)
    {
        self.smartFeedView.frame = subView.bounds;
    }
    else
    {
        CGPoint center = CGPointZero;
        center.x = CGRectGetWidth(subView.bounds)/2;
        center.y = CGRectGetHeight(subView.bounds)/2;
        self.smartFeedView.center = center;
    }
    [self.smartFeedView reSize];
    [self.smartFeedView render];
}

- (void)didAddSubView
{
    if(self.isTemplateRender)
    {
        [self.nativeAdObject trackImpression:self.smartFeedView];
    }
    else
    {
        if(self.nativeAdObject.materialType == HTML)
        {
            [self.nativeAdObject trackImpression:self.webView];
        }
        else
        {
            [self.nativeAdObject trackImpression:self.adView];
        }
    }
}

- (UIView *)endRender:(NSDictionary *)viewInfo clickView:(NSArray *)array
{
    self.adView = viewInfo[kTPRendererAdView];
    if(self.nativeAdObject.materialType == VIDEO)
    {
        [self.videoView render];
    }
    for(UIView *view in array)
    {
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAct:)];
        [view addGestureRecognizer:tap];
    }
    return nil;
}

- (void)tapAct:(UITapGestureRecognizer*)tap
{
    [self.nativeAdObject handleClick:tap.view];
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
        NSError *loadError = [NSError errorWithDomain:@"baidu.native" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S Native not ready"}];
        [self AdLoadFailWithError:loadError];
    }
}

- (void)finishC2SBiddingWithEcpm:(NSString *)ecpmStr
{
    NSString *version = SDK_VERSION_IN_MSSP;
    if(version == nil)
    {
        version = @"";
    }
    if(ecpmStr == nil)
    {
        ecpmStr = @"0";
    }
    NSDictionary *dic = @{@"ecpm":ecpmStr,@"version":version};
    [self ADLoadExtraCallbackWithEvent:@"C2SBiddingFinish" info:dic];
}

- (void)failC2SBiddingWithErrorStr:(NSString *)errorStr
{
    NSDictionary *dic = @{@"error":errorStr};
    [self ADLoadExtraCallbackWithEvent:@"C2SBiddingFail" info:dic];
}

- (void)loadFailWithErrorStr:(NSString *)str
{
    if(self.isC2SBidding)
    {
        NSString *errorStr = [NSString stringWithFormat:@"C2S Bidding Fail , %@",str];
        [self failC2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        NSError *error = [NSError errorWithDomain:@"Baidu" code:4001 userInfo:@{NSLocalizedDescriptionKey: str}];
        [self AdLoadFailWithError:error];
    }
}

#pragma mark - BaiduMobAdNativeAdDelegate

- (void)nativeAdObjectsSuccessLoad:(NSArray *)nativeAds nativeAd:(BaiduMobAdNative *)nativeAd
{
    if(nativeAds.count > 0)
    {
        self.nativeAdObject = nativeAds[0];
        self.nativeAdObject.interationDelegate = self;
        TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
        if(self.isTemplateRender)
        {
            CGRect rect = CGRectZero;
            CGSize size = self.waterfallItem.templateRenderSize;
            rect.size = size;
            self.smartFeedView = [[BaiduMobAdSmartFeedView alloc] initWithObject:self.nativeAdObject frame:rect];
            if(self.smartFeedView != nil)
            {
                [self.smartFeedView setVideoMute:self.videoMute];
                res.adView = self.smartFeedView;
            }
            else
            {
                [self loadFailWithErrorStr:@"创建智能优选视图失败，请确认广告位ID是否支持智能优选"];
                return;
            }
        }
        else if(self.nativeAdObject.materialType == HTML)
        {
            CGRect rect = CGRectZero;
            CGSize size = self.waterfallItem.templateRenderSize;
            rect.size = size;
            self.webView = [[BaiduMobAdNativeWebView alloc]initWithFrame:rect andObject:self.nativeAdObject];
            res.adView = self.webView;
        }
        else
        {
            res.title = self.nativeAdObject.title;
            res.body = self.nativeAdObject.text;
            if(self.nativeAdObject.actButtonString != nil)
            {
                res.ctaText = self.nativeAdObject.actButtonString;
            }
            else
            {
                if (self.nativeAdObject.actType == BaiduMobNativeAdActionTypeDL)
                {
                    res.ctaText = @"立即下载";
                }
                else
                {
                    res.ctaText = @"查看详情";
                }
            }
            res.brandName = self.nativeAdObject.brandName;
            if(self.nativeAdObject.iconImageURLString != nil)
            {
                res.iconImageURL = self.nativeAdObject.iconImageURLString;
                [self.downLoadURLArray addObject:res.iconImageURL];
            }
            if(self.nativeAdObject.baiduLogoURLString != nil)
            {
                res.adChoiceImageURL = self.nativeAdObject.baiduLogoURLString;
                [self.downLoadURLArray addObject:res.adChoiceImageURL];
            }
            if(!self.isNativeBanner)
            {
                if(self.nativeAdObject.materialType == VIDEO)
                {
                    self.videoView = [[BaiduMobAdNativeVideoView alloc] initWithFrame:CGRectZero andObject:self.nativeAdObject];
                    [self.videoView setVideoMute:self.videoMute];
                    res.mediaView = self.videoView;
                }
                else
                {
                    if(self.nativeAdObject.mainImageURLString != nil)
                    {
                        res.mediaImageURL = self.nativeAdObject.mainImageURLString;
                        [self.downLoadURLArray addObject:res.mediaImageURL];
                    }
                    else if(self.nativeAdObject.morepics != nil && self.nativeAdObject.morepics.count > 0)
                    {
                        res.imageURLList = self.nativeAdObject.morepics;
                        NSString *urlStr = self.nativeAdObject.morepics.firstObject;
                        res.mediaImageURL = urlStr;
                        [self.downLoadURLArray addObject:res.mediaImageURL];
                    }
                }
            }
        }
        self.waterfallItem.adRes = res;
        if(self.isC2SBidding)
        {
            [self finishC2SBiddingWithEcpm:self.nativeAdObject.ECPMLevel];
        }
        else
        {
            [self AdLoadFinsh];
        }
    }
    else
    {
        [self loadFailWithErrorStr:@"load failed"];
        return;
    }
    
}

- (void)nativeAdsFailLoadCode:(NSString *)errCode
                      message:(NSString *)message
                     nativeAd:(BaiduMobAdNative *)nativeAd
{
    MSLogTrace(@"%s",__FUNCTION__);
    NSString *errorStr = @"load failed";
    if(message != nil)
    {
        errorStr = [NSString stringWithFormat:@"%@ %@",message,errCode];
    }
    [self loadFailWithErrorStr:errorStr];
}

- (void)nativeAdExposure:(UIView *)nativeAdView nativeAdDataObject:(BaiduMobAdNativeAdObject *)object
{
    MSLogTrace(@"%s",__FUNCTION__);
    [self AdShow];
}

- (void)nativeAdExposureFail:(UIView *)nativeAdView
          nativeAdDataObject:(BaiduMobAdNativeAdObject *)object
                  failReason:(int)reason
{
    MSLogTrace(@"%s",__FUNCTION__);
    NSError *error = [NSError errorWithDomain:@"Baidu" code:reason userInfo:@{NSLocalizedDescriptionKey: @"show faile"}];
    [self AdShowFailWithError:error];
}

- (void)nativeAdClicked:(UIView *)nativeAdView nativeAdDataObject:(BaiduMobAdNativeAdObject *)object
{
    MSLogTrace(@"%s",__FUNCTION__);
    [self AdClick];
}

- (void)didDismissLandingPage:(UIView *)nativeAdView
{
    MSLogTrace(@"%s",__FUNCTION__);
}

- (void)unionAdClicked:(UIView *)nativeAdView nativeAdDataObject:(BaiduMobAdNativeAdObject *)object
{
    MSLogTrace(@"%s",__FUNCTION__);
}

- (void)nativeAdDislikeClick:(UIView *)adView reason:(BaiduMobAdDislikeReasonType)reason
{
    MSLogTrace(@"%s",__FUNCTION__);
    if(reason != BaiduMobAdDislikeReasonCancel)
    {
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
        switch (reason) {
            case BaiduMobAdDislikeReasonUnlike:
            {
                dic[@"dislikeInfo"] = @"不感兴趣";
                break;
            }
            case BaiduMobAdDislikeReasonLowQuality:
            {
                dic[@"dislikeInfo"] = @"内容质量差";
                break;
            }
            case BaiduMobAdDislikeReasonRepeatRecommend:
            {
                dic[@"dislikeInfo"] = @"推荐重复";
                break;
            }
            case BaiduMobAdDislikeReasonVulgarPornography:
            {
                dic[@"dislikeInfo"] = @"低俗色情";
                break;
            }
            case BaiduMobAdDislikeReasonViolatingLaws:
            {
                dic[@"dislikeInfo"] = @"违法违规";
                break;
            }
            case BaiduMobAdDislikeReasonFake:
            {
                dic[@"dislikeInfo"] = @"虚假欺诈";
                break;
            }
            case BaiduMobAdDislikeReasonInducedClick:
            {
                dic[@"dislikeInfo"] = @"诱导点击";
                break;
            }
            case BaiduMobAdDislikeReasonSuspectedPlagiarism:
            {
                dic[@"dislikeInfo"] = @"疑似抄袭";
                break;
            }
            default:
                dic[@"dislikeInfo"] = @"其他";
                break;
        }
        dic[@"dislikeObject"] = @(reason);
        [self ADShowExtraCallbackWithEvent:@"tradplus_native_dislike" info:dic];
    }
}

@end
