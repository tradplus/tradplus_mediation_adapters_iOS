#import "TradPlusInMobiNativeAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TradPlusInMobiSDKLoader.h"
#import <InMobiSDK/IMNative.h>
#import <InMobiSDK/InMobiSDK.h>
#import "TPInMobiAdapterBaseInfo.h"

@interface TradPlusInMobiNativeAdapter()<IMNativeDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) IMNative *native;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, assign) BOOL isNativeBanner;
@property (nonatomic, assign) BOOL isC2SBidding;
@end

@implementation TradPlusInMobiNativeAdapter

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
    NSString *account_id = config[@"account_id"];
    if(account_id == nil || [account_id isKindOfClass:[NSNull class]])
    {
        MSLogTrace(@"InMobi init Config Error %@",config);
        return;
    }
    if([TradPlusInMobiSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusInMobiSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusInMobiSDKLoader sharedInstance] initWithAccountID:account_id delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_InMobiAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [IMSdk getVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_InMobiAdapter_PlatformSDK_Version
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
    NSString *account_id = item.config[@"account_id"];
    self.placementId = item.config[@"placementId"];
    if(account_id == nil || [account_id isKindOfClass:[NSNull class]] || self.placementId == nil)
    {
        MSLogTrace(@"InMobi init Config Error %@",item.config);
        [self AdConfigError];
        return;
    }
    if(item.secType == 2)
    {
        self.isNativeBanner = YES;
    }
    self.waterfallItem.nativeType = TPNativeADTYPE_Feed;
    if([TradPlusInMobiSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusInMobiSDKLoader sharedInstance].initSource = initSource;
    }
    [[TradPlusInMobiSDKLoader sharedInstance] initWithAccountID:account_id delegate:self];
}

- (void)loadAd
{
    self.native = [[IMNative alloc] initWithPlacementId:[self.placementId longLongValue]];
    self.native.delegate = self;
    self.native.extras = [[TradPlusInMobiSDKLoader sharedInstance] getExtras];
    [self.native load];
}

- (BOOL)isReady
{
    return self.native.isReady;
}

- (id)getCustomObject
{
    return self.native;
}

- (UIView *)endRender:(NSDictionary *)viewInfo clickView:(NSArray *)array
{
    if(!self.isNativeBanner)
    {
        UIView *adView = viewInfo[kTPRendererMediaView];
        if(adView == nil)
        {
            adView = viewInfo[kTPRendererMainImageView];
        }
        if(adView != nil)
        {
            UIView *mediaView = [self.native primaryViewOfWidth:adView.bounds.size.width];
            self.waterfallItem.adRes.mediaView = mediaView;
            [adView addSubview:mediaView];
        }
    }
    for(UIView *view in array)
    {
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self.native action:@selector(reportAdClickAndOpenLandingPage)];
        view.userInteractionEnabled = YES;
        [view addGestureRecognizer:tapGestureRecognizer];
    }
    return nil;
}

#pragma mark - C2SBidding

- (void)initSDKC2SBidding
{
    self.isC2SBidding = YES;
    [self initSDKWithWaterfallItem:self.waterfallItem initSource:2];
}

- (void)startC2SBidding
{
    self.native = [[IMNative alloc] initWithPlacementId:[self.placementId longLongValue]];
    self.native.delegate = self;
    self.native.extras = [[TradPlusInMobiSDKLoader sharedInstance] getExtras];
    [self.native load];
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
        NSError *loadError = [NSError errorWithDomain:@"inmobi.native" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S Native not ready"}];
        [self AdLoadFailWithError:loadError];
    }
}

- (void)finishC2SBidding
{
    NSString *version = [IMSdk getVersion];
    if(version == nil)
    {
        version = @"";
    }
    double bidValue = 0;
    if(self.native.getAdMetaInfo[@"bidValue"])
    {
        bidValue = [self.native.getAdMetaInfo[@"bidValue"] doubleValue];
    }
    NSString *ecpmStr = [NSString stringWithFormat:@"%f",bidValue];
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
    if(self.isC2SBidding)
    {
        [self startC2SBidding];
    }
    else
    {
        [self loadAd];
    }
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

#pragma mark - IMNativeDelegate
-(void)nativeDidFinishLoading:(IMNative*)native
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    res.title = self.native.adTitle;
    res.body = self.native.adDescription;
    res.ctaText = self.native.adCtaText;
    res.iconImage = self.native.adIcon;
    res.rating = @([self.native.adRating integerValue]);
    self.waterfallItem.adRes = res;
    MSLogTrace(@"InMobi.rating--%@",res.rating);
    if(self.isC2SBidding)
    {
        [self finishC2SBidding];
    }
    else
    {
        [self AdLoadFinsh];
    }
}

-(void)native:(IMNative*)native didFailToLoadWithError:(IMRequestStatus*)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    if(self.isC2SBidding)
    {
        NSString *errorStr = @"C2S Bidding Fail";
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

-(void)nativeAdImpressed:(IMNative*)native
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

-(void)native:(IMNative*)native didInteractWithParams:(NSDictionary*)params
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

@end
