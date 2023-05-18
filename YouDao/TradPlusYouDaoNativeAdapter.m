#import "TradPlusYouDaoNativeAdapter.h"
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSLogging.h>
#import "TPYouDaoAdapterBaseInfo.h"
#import "TradPlusYouDaoSDKSetting.h"
#import "YDSDKHeader.h"

@interface TradPlusYouDaoNativeAdapter()<YDNativeAdDelegate>

@property (nonatomic, strong) YDNativeAd *nativeAd;
@property (nonatomic, assign) BOOL isNativeBanner;

@end

@implementation TradPlusYouDaoNativeAdapter

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
    else
    {
        return NO;
    }
    return YES;
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_YouDaoAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = @"-";
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_YouDaoAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *placementId = item.config[@"placementId"];
    if(placementId == nil || item.style_name == nil || item.style_name.count == 0)
    {
        [self AdConfigError];
        return;
    }
    self.waterfallItem.nativeType = TPNativeADTYPE_Feed;
    if(item.secType == 2)
    {
        self.isNativeBanner = YES;
    }
    [[YDAdManager sharedInstance] prepareForLoadAd];
    NSMutableArray *arrConfig = [NSMutableArray array];
    for (NSString *style in item.style_name)
    {
        YDStaticNativeAdRendererSettings *settings = [[YDStaticNativeAdRendererSettings alloc] init];
        settings.renderingViewClass = [UIView class];
        NSString* styleName = style;
        YDNativeAdRendererConfiguration *config = [YDStaticNativeAdRenderer rendererConfigurationWithRendererSettings:settings andStyleName:styleName];
        [arrConfig addObject:config];
    }
    YDNativeAdRequest *adRequest = [YDNativeAdRequest requestWithAdUnitIdentifier:placementId rendererConfigurations:arrConfig];
    YDNativeAdRequestTargeting *targeting = [YDNativeAdRequestTargeting targeting];
    targeting.uploadLastCreativeIds = YES;
    targeting.supportTargetedAd = [[TradPlusYouDaoSDKSetting sharedInstance] personalizedAd];
    adRequest.targeting = targeting;
    __weak typeof(self) weakSelf = self;
    [adRequest startWithAdSequence:0 withCompletionHandler:^(YDNativeAdRequest *request, YDNativeAd *response, NSError *error) {
        if(error == nil)
        {
            [weakSelf loadFinishWithResponse:response];
        }
        else
        {
            [weakSelf AdLoadFailWithError:error];
        }
    }];
}

- (void)loadFinishWithResponse:(YDNativeAd *)nativeAd
{
    self.nativeAd = nativeAd;
    self.nativeAd.delegate = self;
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    NSDictionary *properties = nativeAd.properties;
    if([properties valueForKey:@"title"])
    {
        res.title = properties[@"title"];
    }
    if([properties valueForKey:@"text"])
    {
        res.body = properties[@"text"];
    }
    if(!self.isNativeBanner)
    {
        if([properties valueForKey:@"mainimage"])
        {
            res.mediaImageURL = properties[@"mainimage"];
            [self.downLoadURLArray addObject:res.mediaImageURL];
        }
    }
    self.waterfallItem.adRes = res;
    [self AdLoadFinsh];
}

- (UIView *)endRender:(NSDictionary *)viewInfo clickView:(NSArray *)array
{
    NSError *error = nil;
    UIView *nativeAdView = [self.nativeAd retrieveAdViewWithError:&error browserViewControllerBuilderDelegate:nil];
    UIView *adView = [viewInfo valueForKey:kTPRendererAdView];
    nativeAdView.frame = adView.bounds;
    [nativeAdView addSubview:adView];
    return nativeAdView;
}

- (BOOL)isReady
{
    return (self.nativeAd != nil);
}

- (id)getCustomObject
{
    return self.nativeAd;
}

#pragma mark - YDNativeAdDelegate
- (void)nativeAdWillLogImpression:(YDNativeAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)nativeAdDidClick:(YDNativeAd *)nativeAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (UIViewController *)viewControllerForPresentingModalView
{
    return self.rootViewController;
}
@end
