#import "TradPlusVerveBannerAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <HyBid/HyBid.h>
#import "TradPlusVerveSDKLoader.h"
#import "TPVerveAdapterBaseInfo.h"

@interface TradPlusVerveBannerAdapter ()<HyBidAdViewDelegate, TPSDKLoaderDelegate>

@property (nonatomic,strong) HyBidAdView *adView;
@property (nonatomic,copy)NSString *placementId;
@property (nonatomic,assign)BOOL isC2SBidding;
@end

@implementation TradPlusVerveBannerAdapter

#pragma mark - Extra
- (BOOL)extraActWithEvent:(NSString *)event info:(NSDictionary *)info
{
    if([event isEqualToString:@"StartInit"])
    {
        [self initSDKWithInfo:info];
    }
    else if([event isEqualToString:@"AdapterVersion"])
    {
        [self adapterVersionCallback];
    }
    else if([event isEqualToString:@"PlatformSDKVersion"])
    {
        [self platformSDKVersionCallback];
    }
    else if([event isEqualToString:@"BannerHidden"])
    {
        [self bannerHiddenWithInfo:info];
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
        MSLogTrace(@"Verve init Config Error %@",config);
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

- (void)bannerHiddenWithInfo:(NSDictionary *)info
{
    if([info valueForKey:@"hidden"])
    {
        BOOL hidden = [info[@"hidden"] boolValue];
        if(hidden)
        {
            [self.adView stopAutoRefresh];
        }
        else
        {
            [self.adView setAutoRefreshTimeInSeconds:self.adView.autoRefreshTimeInSeconds];
        }
    }
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
    if(appId == nil || self.placementId == nil || appId.length <= 5)
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

- (void)loadAd
{
    HyBidAdSize *adSize = HyBidAdSize.SIZE_320x50;
    if(self.waterfallItem.ad_size == 2)
    {
        adSize = HyBidAdSize.SIZE_300x250;
    }
    if(self.waterfallItem.ad_size == 3)
    {
        adSize = HyBidAdSize.SIZE_728x90;
    }
    self.adView = [[HyBidAdView alloc] initWithSize:adSize];
    self.adView.isMediation = YES;
    [self.adView loadWithZoneID:self.placementId andWithDelegate:self];
}

- (void)bannerDidAddSubView:(UIView *)subView
{
    [self setBannerCenterWithBanner:self.adView subView:subView];
}

- (BOOL)isReady
{
    return (self.adView != nil);
}

- (id)getCustomObject
{
    return self.adView;
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
        NSError *loadError = [NSError errorWithDomain:@"verve.banner" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S Banner not ready"}];
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

#pragma mark - HyBidAdViewDelegate

- (void)adViewDidLoad:(HyBidAdView *)adView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.isC2SBidding)
    {
        [self finishC2SBiddingWithAd:adView.ad];
    }
    else
    {
        [self AdLoadFinsh];
    }
}

- (void)adView:(HyBidAdView *)adView didFailWithError:(NSError *)error
{
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

- (void)adViewDidTrackClick:(HyBidAdView *)adView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)adViewDidTrackImpression:(HyBidAdView *)adView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}


@end
