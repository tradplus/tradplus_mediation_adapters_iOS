#import "TradPlusSmaatoNativeAdapter.h"
#import "TradPlusSmaatoSDKLoader.h"
#import <SmaatoSDKNative/SmaatoSDKNative.h>
#import <SmaatoSDKNative/SMANativeImage.h>
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TPSmaatoAdapterBaseInfo.h"

@interface TradPlusSmaatoNativeAdapter()<SMANativeAdDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) SMANativeAd *nativeAd;
@property (nonatomic, strong) SMANativeAdRenderer *renderer;
@property (nonatomic, assign) BOOL isNativeBanner;
@property (nonatomic, copy) NSString *placementId;
@end

@implementation TradPlusSmaatoNativeAdapter

- (void)dealloc
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
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
        MSLogTrace(@"Smaato init Config Error %@",config);
        return;
    }
    if([TradPlusSmaatoSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusSmaatoSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusSmaatoSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_SmaatoAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [SmaatoSDK sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_SmaatoAdapter_PlatformSDK_Version
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
    if(item.secType == 2)
    {
        self.isNativeBanner = YES;
    }
    self.waterfallItem.nativeType = TPNativeADTYPE_Feed;
    [[TradPlusSmaatoSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    self.nativeAd = [[SMANativeAd alloc] init];
    self.nativeAd.delegate = self;
    SMANativeAdRequest *adRequest =  [[SMANativeAdRequest alloc] initWithAdSpaceId:self.placementId];
    adRequest.allowMultipleImages = NO;
    adRequest.returnUrlsForImageAssets = NO;
    [self.nativeAd loadWithAdRequest:adRequest];
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
    return (self.renderer != nil);
}

- (id)getCustomObject
{
    return self.renderer;
}

- (void)didAddSubView
{
    [self AdShow];
}

- (UIView *)endRender:(NSDictionary *)viewInfo clickView:(NSArray *)array
{
    UIView *adView = viewInfo[kTPRendererAdView];
    [self.renderer registerViewForImpression:adView];
    [self.renderer registerViewsForClickAction:array];
    return nil;
}

#pragma mark - SMANativeAdDelegate
- (void)nativeAd:(SMANativeAd * _Nonnull)nativeAd didLoadWithAdRenderer:(SMANativeAdRenderer * _Nonnull)renderer
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.renderer = renderer;
    SMANativeAdAssets *nativeAssets = renderer.nativeAssets;
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    res.title = nativeAssets.title;
    res.body = nativeAssets.mainText;
    res.sponsored = nativeAssets.sponsored;
    res.ctaText = nativeAssets.cta;
    if(nativeAssets.icon != nil)
    {
        res.iconImage = nativeAssets.icon.image;
    }
    res.rating = @(nativeAssets.rating);
    if(!self.isNativeBanner)
    {
        if(nativeAssets.images != nil)
        {
            NSMutableArray *array = [[NSMutableArray alloc] init];
            for(SMANativeImage *nativeImage in nativeAssets.images)
            {
                if(nativeImage.image != nil)
                {
                    [array addObject:nativeImage.image];
                }
            }
            if(array.count > 0)
            {
                res.mediaImageList = array;
            }
        }
    }
    self.waterfallItem.adRes = res;
    MSLogTrace(@"Smaato.rating--%@",res.rating);
    [self AdLoadFinsh];
}

- (void)nativeAd:(SMANativeAd * _Nonnull)nativeAd didFailWithError:(NSError * _Nonnull)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

- (void)nativeAdDidImpress:(SMANativeAd *_Nonnull)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeAdDidClick:(SMANativeAd *_Nonnull)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (nonnull UIViewController *)presentingViewControllerForNativeAd:(SMANativeAd * _Nonnull)nativeAd
{
    return self.rootViewController;
}

- (void)nativeAdDidTTLExpire:(SMANativeAd * _Nonnull)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
@end
