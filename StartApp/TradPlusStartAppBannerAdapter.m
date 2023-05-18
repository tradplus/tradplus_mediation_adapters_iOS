#import "TradPlusStartAppBannerAdapter.h"
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MSLogging.h>
#import <StartApp/StartApp.h>
#import "TradPlusStartAppSDKLoader.h"
#import "TPStartAppAdapterBaseInfo.h"

@interface TradPlusStartAppBannerAdapter ()<STABannerDelegateProtocol,TPSDKLoaderDelegate>

@property (nonatomic, strong) STABannerView *bannerView;
@property (nonatomic, copy) NSString *placementId;
@end

@implementation TradPlusStartAppBannerAdapter

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
    [[TradPlusStartAppSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    CGFloat width = [self.waterfallItem.ad_size_info[@"X"] floatValue];
    CGFloat height = [self.waterfallItem.ad_size_info[@"Y"] floatValue];
    if(width == 0)
        width = 320;
    if(height == 0)
        height = 50;
    STABannerSize bannerSize;
    bannerSize.size = CGSizeMake(width, height);
    bannerSize.isAuto = NO;
    self.bannerView =  [[STABannerView alloc] initWithSize:bannerSize origin:CGPointMake(0, 0) withDelegate:self];
    [self.bannerView setSTABannerAdTag:self.placementId];
    STAAdPreferences *preferences = [[STAAdPreferences alloc] init];
    preferences.adTag = self.placementId;
    [self.bannerView setAdPreferneces:preferences];
    [self.bannerView loadAd];
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
    return (self.bannerView != nil);
}

- (id)getCustomObject
{
    return self.bannerView;
}

- (void)bannerDidAddSubView:(UIView *)subView
{
    [self setBannerCenterWithBanner:self.bannerView subView:subView];
}

#pragma mark - STABannerDelegateProtocol
- (void)bannerAdIsReadyToDisplay:(STABannerView *)banner
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self.bannerView removeFromSuperview];
    [self AdLoadFinsh];
}

- (void)didDisplayBannerAd:(STABannerView *)banner
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void) failedLoadBannerAd:(STABannerView *)banner withError:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

- (void) didClickBannerAd:(STABannerView *)banner
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void) didCloseBannerInAppStore:(STABannerView *)banner
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)didSendImpressionForBannerAd:(STABannerView *)banner
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

@end
