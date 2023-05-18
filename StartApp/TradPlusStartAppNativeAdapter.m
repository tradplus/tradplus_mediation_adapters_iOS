#import "TradPlusStartAppNativeAdapter.h"
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSLogging.h>
#import "TradPlusStartAppSDKLoader.h"
#import <StartApp/StartApp.h>
#import "TPStartAppAdapterBaseInfo.h"

@interface TradPlusStartAppNativeAdapter()<TPSDKLoaderDelegate,STADelegateProtocol>

@property (nonatomic, strong) STAStartAppNativeAd *startAppNativeAd;
@property (nonatomic, strong) STANativeAdDetails *adDetail;
@property (nonatomic, copy) NSString *placementId;

@end

@implementation TradPlusStartAppNativeAdapter

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
    else if([event isEqualToString:@"SetTestMode"])
    {
        [[TradPlusStartAppSDKLoader sharedInstance] setTestMode];
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
        MSLogTrace(@"StartApp init Config Error %@",config);
        return;
    }
    tp_dispatch_main_async_safe(^{
        if([TradPlusStartAppSDKLoader sharedInstance].initSource == -1)
        {
            [TradPlusStartAppSDKLoader sharedInstance].initSource = 1;
        }
        [[TradPlusStartAppSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
    });
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_StartAppAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [[STAStartAppSDK sharedInstance] version];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_StartAppAdapter_PlatformSDK_Version
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
    self.waterfallItem.nativeType = TPNativeADTYPE_Feed;
    [[TradPlusStartAppSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    self.startAppNativeAd = [[STAStartAppNativeAd alloc] init];
    [self.startAppNativeAd setAdTag:self.placementId];
    STANativeAdPreferences *pref = [[STANativeAdPreferences alloc]init];
    pref.adTag = self.placementId;
    
    NSInteger primaryImageSize = 4;
    if(self.waterfallItem.dicCustomValue != nil
       && [self.waterfallItem.dicCustomValue valueForKey:@"startapp_primaryImageSize"])
    {
        NSInteger size = [self.waterfallItem.dicCustomValue[@"startapp_primaryImageSize"] integerValue];
        if(size >= 0 && size <= 4)
        {
            primaryImageSize = size;
        }
    }
    if(self.waterfallItem.extraInfoDictionary != nil
       && [self.waterfallItem.extraInfoDictionary valueForKey:@"localParams"])
    {
        id localParams = self.waterfallItem.extraInfoDictionary[@"localParams"];
        if([localParams isKindOfClass:[NSDictionary class]]
           && [localParams valueForKey:@"startapp_primaryImageSize"])
        {
            NSInteger size = [localParams[@"startapp_primaryImageSize"] integerValue];
            if(size >= 0 && size <= 4)
            {
                primaryImageSize = size;
            }
        }
    }
    pref.primaryImageSize = primaryImageSize;
    
    NSInteger secondaryImageSize = 2;
    if(self.waterfallItem.dicCustomValue != nil
       && [self.waterfallItem.dicCustomValue valueForKey:@"startapp_secondaryImageSize"])
    {
        NSInteger size = [self.waterfallItem.dicCustomValue[@"startapp_secondaryImageSize"] integerValue];
        if(size >= 0 && size <= 4)
        {
            secondaryImageSize = size;
        }
    }
    if(self.waterfallItem.extraInfoDictionary != nil
       && [self.waterfallItem.extraInfoDictionary valueForKey:@"localParams"])
    {
        id localParams = self.waterfallItem.extraInfoDictionary[@"localParams"];
        if([localParams isKindOfClass:[NSDictionary class]]
           && [localParams valueForKey:@"startapp_secondaryImageSize"])
        {
            NSInteger size = [localParams[@"startapp_secondaryImageSize"] integerValue];
            if(size >= 0 && size <= 4)
            {
                secondaryImageSize = size;
            }
        }
    }
    pref.secondaryImageSize = secondaryImageSize;
    
    pref.autoBitmapDownload = YES;
    pref.adsNumber = 1;
    [self.startAppNativeAd loadAdWithDelegate:self withNativeAdPreferences:pref];
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
    return self.startAppNativeAd.isReady;
}

- (id)getCustomObject
{
    return self.startAppNativeAd;
}

- (UIView *)endRender:(NSDictionary *)viewInfo clickView:(NSArray *)array
{
    UIView *adView = viewInfo[kTPRendererAdView];
    [self.adDetail registerViewForImpression:adView andViewsForClick:array];
    return nil;
}

#pragma mark - STADelegateProtocol
- (void)didLoadAd:(STAAbstractAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.startAppNativeAd.adsDetails.count > 0)
    {
        self.adDetail = self.startAppNativeAd.adsDetails.firstObject;
        
        TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
        res.title = self.adDetail.title;
        res.body = self.adDetail.description;
        if(self.adDetail.callToAction != nil)
        {
            res.ctaText = self.adDetail.callToAction;
        }
        else if(self.adDetail.clickToInstall != nil)
        {
            res.ctaText = self.adDetail.clickToInstall;
        }
        if(self.adDetail.isVideo)
        {
            res.mediaView = self.adDetail.mediaView;
        }
        else
        {
            res.mediaImage = self.adDetail.imageBitmap;
        }
        res.iconImage = self.adDetail.secondaryImageBitmap;
        res.category = self.adDetail.category;
        res.rating = self.adDetail.rating;
        res.adChoiceImage = self.adDetail.policyImage;
        self.waterfallItem.adRes = res;
        MSLogTrace(@"StartApp.rating--%@",res.rating);
        [self AdLoadFinsh];
    }
    else
    {
        NSError *error = [NSError errorWithDomain:@"StartApp" code:4001 userInfo:@{NSLocalizedDescriptionKey: @"no adsDetails"}];
        [self AdLoadFailWithError:error];
    }
}

- (void)failedLoadAd:(STAAbstractAd *)ad withError:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__, error);
    [self AdLoadFailWithError:error];
}

- (void)didShowAd:(STAAbstractAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)failedShowAd:(STAAbstractAd *)ad withError:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__, error);
    [self AdShowFailWithError:error];
}

- (void)didCloseAd:(STAAbstractAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
- (void)didClickAd:(STAAbstractAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
- (void)didCloseInAppStore:(STAAbstractAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    
}
- (void)didCompleteVideo:(STAAbstractAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}

- (void)didShowNativeAdDetails:(STANativeAdDetails *)nativeAdDetails
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    if (nativeAdDetails.isVideo)
        [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}
- (void)didClickNativeAdDetails:(STANativeAdDetails *)nativeAdDetails
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}
@end
