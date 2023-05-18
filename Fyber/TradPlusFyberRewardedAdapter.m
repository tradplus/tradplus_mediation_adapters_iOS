#import "TradPlusFyberRewardedAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TradPlusFyberSDKLoader.h"
#import <IASDKCore/IASDKCore.h>
#import "TPFyberAdapterBaseInfo.h"

@interface TradPlusFyberRewardedAdapter ()<IAUnitDelegate, IAMRAIDContentDelegate, IAVideoContentDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) IAAdSpot *adSpot;
@property (nonatomic, strong) IAFullscreenUnitController *interstitialUnitController;
@property (nonatomic, strong) IAMRAIDContentController *MRAIDContentController;
@property (nonatomic, strong) IAVideoContentController *videoContentController;
@property (nonatomic, strong) NSString *spotID;
@property (nonatomic, assign) NSInteger loadTimeout;
@property (nonatomic, weak) UIViewController *interstitialRootViewController;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;

@end

@implementation TradPlusFyberRewardedAdapter

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
    if([item.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [item.extraInfoDictionary[@"always_reward"] integerValue] == 1;
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
    
    self.videoContentController = [IAVideoContentController build:^(id<IAVideoContentControllerBuilder>  _Nonnull builder) {
        builder.videoContentDelegate = self;
    }];
    
    self.MRAIDContentController = [IAMRAIDContentController build:^(id<IAMRAIDContentControllerBuilder>  _Nonnull builder) {
        builder.MRAIDContentDelegate = self;
    }];
    
    self.interstitialUnitController = [IAFullscreenUnitController build:^(id<IAFullscreenUnitControllerBuilder>  _Nonnull builder) {
        builder.unitDelegate = self;
        
        [builder addSupportedContentController:self.videoContentController];
        [builder addSupportedContentController:self.MRAIDContentController];
    }];
    
    self.adSpot = [IAAdSpot build:^(id<IAAdSpotBuilder>  _Nonnull builder) {
        builder.adRequest = request;
        [builder addSupportedUnitController:self.interstitialUnitController];
    }];
    
    [self.adSpot fetchAdWithCompletion:^(IAAdSpot * _Nullable adSpot, IAAdModel * _Nullable adModel, NSError * _Nullable error) {
        if (error) {
            [weakSelf handleLoadOrShowError:error.localizedDescription isLoad:YES];
        } else {
            if (adSpot.activeUnitController == weakSelf.interstitialUnitController) {
                [weakSelf AdLoadFinsh];
            } else {
                [weakSelf handleLoadOrShowError:nil isLoad:YES];
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

- (id)getCustomObject
{
    return self.interstitialUnitController;
}

- (BOOL)isReady
{
    return self.interstitialUnitController.isReady;
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    self.interstitialRootViewController = rootViewController;
    [self.interstitialUnitController showAdAnimated:YES completion:nil];
}

- (void)handleLoadOrShowError:(NSString * _Nullable)reason isLoad:(BOOL)isLoad
{
    if (!reason.length) {
        reason = @"internal error";
    }
    
    NSDictionary *userInfo = @{NSLocalizedFailureReasonErrorKey : reason};
    NSError *error = [NSError errorWithDomain:@"Fyber" code:403 userInfo:userInfo];
    
    if (isLoad) {
        [self AdLoadFailWithError:error];
    } else {
        [self AdShowFailWithError:error];
    }
}

#pragma mark - IAViewUnitControllerDelegate

- (UIViewController * _Nonnull)IAParentViewControllerForUnitController:(IAUnitController * _Nullable)unitController
{
    return self.interstitialRootViewController;
}

- (void)IAAdDidReceiveClick:(IAUnitController * _Nullable)unitController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)IAAdWillLogImpression:(IAUnitController * _Nullable)unitController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)IAAdDidReward:(IAUnitController * _Nullable)unitController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.shouldReward = YES;
}

- (void)IAUnitControllerWillPresentFullscreen:(IAUnitController * _Nullable)unitController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)IAUnitControllerDidPresentFullscreen:(IAUnitController * _Nullable)unitController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)IAUnitControllerWillDismissFullscreen:(IAUnitController * _Nullable)unitController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)IAUnitControllerDidDismissFullscreen:(IAUnitController * _Nullable)unitController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
    if (self.shouldReward || self.alwaysReward)
        [self AdRewardedWithInfo:nil];
    [self AdClose];
}

- (void)IAUnitControllerWillOpenExternalApp:(IAUnitController * _Nullable)unitController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)IAAdDidExpire:(IAUnitController * _Nullable)unitController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

#pragma mark - IAVideoContentDelegate

- (void)IAVideoCompleted:(IAVideoContentController * _Nullable)contentController
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)IAVideoContentController:(IAVideoContentController * _Nullable)contentController videoInterruptedWithError:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShowFailWithError:error];
}

- (void)IAVideoContentController:(IAVideoContentController * _Nullable)contentController videoDurationUpdated:(NSTimeInterval)videoDuration
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
