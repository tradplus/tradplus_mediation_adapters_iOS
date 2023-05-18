

#import "TradPlusVerveNativeAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <HyBid/HyBid.h>
#import "TradPlusVerveSDKLoader.h"
#import "TPVerveAdapterBaseInfo.h"

@interface TradPlusVerveNativeAdapter ()<HyBidNativeAdLoaderDelegate, HyBidNativeAdFetchDelegate, HyBidNativeAdDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong) HyBidNativeAdLoader *nativeAdLoader;
@property (nonatomic,strong) HyBidNativeAd *nativeAd;
@property (nonatomic,copy) NSString *placementId;
@property (nonatomic,assign) BOOL isC2SBidding;
@end

@implementation TradPlusVerveNativeAdapter

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
    else if([event isEqualToString:@"SetTestMode"])
    {
        [[TradPlusVerveSDKLoader sharedInstance] setTestMode];
    }
    else
    {
        return NO;
    }
    return YES;
}

- (void)initSDKWithInfo:(NSDictionary *)config
{
    NSString *appId = config[@"appToken"];
    if(appId == nil  ||  appId.length <= 5)
    {
        MSLogTrace(@"AppLovin init Config Error %@",config);
        return;
    }
    if([TradPlusVerveSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusVerveSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusVerveSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_VerveAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [HyBid sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_VerveAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}


#pragma mark - load
- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    [self initSDKWithWaterfallItem:item initSource:3];
}

- (void)initSDKWithWaterfallItem:(TradPlusAdWaterfallItem *)item initSource:(NSInteger)initSource
{
    NSString *appId = item.config[@"appToken"];
    self.placementId = item.config[@"placementId"];
    if(appId == nil  || self.placementId == nil || appId.length <= 5)
    {
        MSLogTrace(@"Verve init Config Error %@",item.config);
        [self AdConfigError];
        return;
    }
    if([TradPlusVerveSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusVerveSDKLoader sharedInstance].initSource = initSource;
    }
    [[TradPlusVerveSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAdWithPlacementId:(NSString *)placementId
{
    self.waterfallItem.nativeType = TPNativeADTYPE_Feed;
    self.nativeAdLoader = [[HyBidNativeAdLoader alloc] init];
    self.nativeAdLoader.isMediation = YES;
    [self.nativeAdLoader loadNativeAdWithDelegate:self withZoneID:placementId];
}

- (id)getCustomObject
{
    return self.nativeAd;
}

- (BOOL)isReady
{
    return (self.nativeAd != nil);
}

- (UIView *)endRender:(NSDictionary *)viewInfo clickView:(NSArray *)array
{
    UIView *adView = viewInfo[kTPRendererAdView];
    UIView *clickView = nil;
    if([array containsObject:adView])
    {
        clickView = adView;
    }
    else if(array.count > 0)
    {
        clickView = array.lastObject;
    }
    if(clickView != nil)
    {
        [self.nativeAd startTrackingView:clickView withDelegate:self];
    }
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
        [self AdLoadFinsh];
    }
    else
    {
        NSError *loadError = [NSError errorWithDomain:@"verve.native" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S Native not ready"}];
        [self AdLoadFailWithError:loadError];
    }
}

- (void)finishC2SBiddingWithAd:(HyBidAd *)ad
{
    NSString *version = [HyBid sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSString *ecpmStr = [NSString stringWithFormat:@"%@",ad.eCPM];
    NSDictionary *dic = @{@"ecpm":ecpmStr,@"version":version};
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
    [self loadAdWithPlacementId:self.placementId];
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

#pragma mark - HyBidNativeAdLoaderDelegate

- (void)nativeLoaderDidLoadWithNativeAd:(HyBidNativeAd *)nativeAd {
    [nativeAd fetchNativeAdAssetsWithDelegate:self];
}

- (void)nativeLoaderDidFailWithError:(NSError *)error {
    MSLogTrace(@"%s error: %@", __PRETTY_FUNCTION__,error);
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
        [self AdLoadFailWithError:error];
    }
}

#pragma mark - HyBidNativeAdFetchDelegate

- (void)nativeAdDidFinishFetching:(HyBidNativeAd *)nativeAd {
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    self.nativeAd = nativeAd;
    res.title = self.nativeAd.title;
    res.body = self.nativeAd.body;
    res.ctaText = self.nativeAd.callToActionTitle;
    if(self.nativeAd.icon != nil)
    {
        res.iconImage = self.nativeAd.icon;
    }
    else if(self.nativeAd.iconUrl != nil)
    {
        res.iconImageURL = self.nativeAd.iconUrl;
        [self.downLoadURLArray addObject:res.iconImageURL];
    }
    res.mediaImage = self.nativeAd.bannerImage;
    res.rating = self.nativeAd.rating;
    res.adChoiceView = self.nativeAd.contentInfo;
    self.waterfallItem.adRes = res;
    if(self.isC2SBidding)
    {
        [self finishC2SBiddingWithAd:nativeAd.ad];
    }
    else
    {
        [self AdLoadFinsh];
    }
}

- (void)nativeAd:(HyBidNativeAd *)nativeAd didFailFetchingWithError:(NSError *)error {
    MSLogTrace(@"%s error: %@", __PRETTY_FUNCTION__,error);
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
        [self AdLoadFailWithError:error];
    }
}

#pragma mark HyBidNativeAdDelegate

- (void)nativeAd:(HyBidNativeAd *)nativeAd impressionConfirmedWithView:(UIView *)view
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)nativeAdDidClick:(HyBidNativeAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

@end
