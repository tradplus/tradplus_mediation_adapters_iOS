#import "TradPlusFyberBannerAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <IASDKCore/IASDKCore.h>
#import "TradPlusFyberSDKLoader.h"
#import "TPFyberAdapterBaseInfo.h"

@interface TradPlusFyberBannerAdapter ()<IAUnitDelegate, IAMRAIDContentDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) IAAdSpot *adSpot;
@property (nonatomic, strong) IAViewUnitController *bannerUnitController;
@property (nonatomic, strong) IAMRAIDContentController *MRAIDContentController;
@property (nonatomic, strong) NSString *spotID;
@property (nonatomic, assign) NSInteger loadTimeout;

@property (nonatomic) BOOL isIABanner;
@end

@implementation TradPlusFyberBannerAdapter

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
        MSLogTrace(@"Fyber init Config Error %@",config);
        return;
    }
    if([TradPlusFyberSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusFyberSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusFyberSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_FyberAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [[IASDKCore sharedInstance] version];
    if(version == nil)
    {
       version = @"";
    }
    NSDictionary *dic = @{
       @"version":version,
       @"adaptedVersion":TP_FyberAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *appId = item.config[@"appId"];
    self.spotID = item.config[@"placementId"];
    if(appId == nil || self.spotID == nil)
    {
        [self AdConfigError];
        return;
    }
    self.loadTimeout = item.loadTimeout;
    [[TradPlusFyberSDKLoader sharedInstance] initWithAppID:appId delegate:self];
    
}

- (void)loadAd
{
    __weak __typeof__(self) weakSelf = self;
    IAAdRequest *request = [IAAdRequest build:^(id<IAAdRequestBuilder>  _Nonnull builder) {
        builder.spotID = weakSelf.spotID;
        if (weakSelf.loadTimeout > 1)
            builder.timeout = weakSelf.loadTimeout - 1;
    }];
    
    self.MRAIDContentController = [IAMRAIDContentController build:^(id<IAMRAIDContentControllerBuilder>  _Nonnull builder) {
        builder.MRAIDContentDelegate = self;
        builder.contentAwareBackground = YES;
    }];
    
    self.bannerUnitController = [IAViewUnitController build:^(id<IAViewUnitControllerBuilder>  _Nonnull builder) {
        builder.unitDelegate = self;
        [builder addSupportedContentController:self.MRAIDContentController];
    }];
    
    self.adSpot = [IAAdSpot build:^(id<IAAdSpotBuilder>  _Nonnull builder) {
        builder.adRequest = request;
        [builder addSupportedUnitController:self.bannerUnitController];
    }];
        
    
    [self.adSpot fetchAdWithCompletion:^(IAAdSpot * _Nullable adSpot, IAAdModel * _Nullable adModel, NSError * _Nullable error) {
        if (error) {
            [weakSelf handleError:error.localizedDescription];
        } else {
            if (adSpot.activeUnitController == weakSelf.bannerUnitController)
            {
                [weakSelf AdLoadFinsh];
            }
            else
            {
                [weakSelf handleError:@"active unit controller is not the current banner ad object."];
            }
        }
    }];
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

#pragma mark - Service

- (void)handleError:(NSString * _Nullable)reason
{
    if (!reason.length)
    {
        reason = @"internal error";
    }
    
    NSDictionary *userInfo = @{NSLocalizedFailureReasonErrorKey : reason};
    NSError *error = [NSError errorWithDomain:@"Fyber" code:403 userInfo:userInfo];
    
    [self AdLoadFailWithError:error];
}

- (void)bannerDidAddSubView:(UIView *)subView
{
    [self setBannerCenterWithBanner:self.bannerUnitController.adView subView:subView];
}

- (BOOL)isReady
{
    return (self.bannerUnitController != nil);
}

- (id)getCustomObject
{
    return self.bannerUnitController.adView;
}

#pragma mark - IAUnitDelegate, IAMRAIDContentDelegate

- (UIViewController * _Nonnull)IAParentViewControllerForUnitController:(IAUnitController * _Nullable)unitController
{
    return self.waterfallItem.bannerRootViewController;
}

- (void)IAAdDidReceiveClick:(IAUnitController * _Nullable)unitController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)IAAdWillLogImpression:(IAUnitController * _Nullable)unitController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)IAUnitControllerWillPresentFullscreen:(IAUnitController * _Nullable)unitController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)IAUnitControllerDidPresentFullscreen:(IAUnitController * _Nullable)unitController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)IAUnitControllerWillDismissFullscreen:(IAUnitController * _Nullable)unitController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)IAUnitControllerDidDismissFullscreen:(IAUnitController * _Nullable)unitController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)IAUnitControllerWillOpenExternalApp:(IAUnitController * _Nullable)unitController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

#pragma mark - IAMRAIDContentDelegate

- (void)IAMRAIDContentController:(IAMRAIDContentController * _Nullable)contentController MRAIDAdWillResizeToFrame:(CGRect)frame
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)IAMRAIDContentController:(IAMRAIDContentController * _Nullable)contentController MRAIDAdDidResizeToFrame:(CGRect)frame
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)IAMRAIDContentController:(IAMRAIDContentController * _Nullable)contentController MRAIDAdWillExpandToFrame:(CGRect)frame
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)IAMRAIDContentController:(IAMRAIDContentController * _Nullable)contentController MRAIDAdDidExpandToFrame:(CGRect)frame
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)IAMRAIDContentControllerMRAIDAdWillCollapse:(IAMRAIDContentController * _Nullable)contentController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)IAMRAIDContentControllerMRAIDAdDidCollapse:(IAMRAIDContentController * _Nullable)contentController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

#pragma mark - Memory management

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
@end
