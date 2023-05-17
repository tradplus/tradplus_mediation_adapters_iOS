#import "TradPlusPangleGlobalSplashAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <PAGAdSDK/PAGAdSDK.h>
#import <PAGAdSDK/PAGLAppOpenAd.h>
#import "TradPlusPangleSDKLoader.h"
#import "TPPangleAdapterBaseInfo.h"

@interface TradPlusPangleGlobalSplashAdapter ()<TPSDKLoaderDelegate,PAGLAppOpenAdDelegate>

@property (nonatomic,copy)NSString *placementId;
@property (nonatomic,copy)NSString *appId;
@property (nonatomic,strong)PAGLAppOpenAd *splashAd;
@property (nonatomic, assign) BOOL isS2SBidding;
@end

@implementation TradPlusPangleGlobalSplashAdapter

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
    else if([event isEqualToString:@"S2SBidding"])
    {
        [self initSDKS2SBidding];
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
        MSLogTrace(@"Pangle init Config Error %@",config);
        return;
    }
    if([TradPlusPangleSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusPangleSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusPangleSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_PangleAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [TradPlusPangleSDKLoader getSDKVersion];
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_PangleAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

#pragma mark - S2SBidding

- (void)initSDKS2SBidding
{
    self.isS2SBidding = YES;
    [self initSDKWithWaterfallItem:self.waterfallItem initSource:2];
}

- (void)getBiddingToken
{
    NSString *token = [PAGSdk getBiddingToken:self.appId];
    if(token == nil)
    {
        token = @"";
    }
    NSString *version = [TradPlusPangleSDKLoader getCurrentVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{@"token":token,@"version":version};
    [self ADLoadExtraCallbackWithEvent:@"S2SBiddingFinish" info:dic];
}

- (void)failS2SBiddingWithErrorStr:(NSString *)errorStr
{
    NSDictionary *dic = @{@"error":errorStr};
    [self ADLoadExtraCallbackWithEvent:@"S2SBiddingFail" info:dic];
}


#pragma mark - 普通

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    [self initSDKWithWaterfallItem:item initSource:3];
}

- (void)initSDKWithWaterfallItem:(TradPlusAdWaterfallItem *)item initSource:(NSInteger)initSource
{
    self.appId = item.config[@"appId"];
    self.placementId = item.config[@"placementId"];
    if(self.placementId == nil || self.appId == nil)
    {
        [self AdConfigError];
        return;
    }
    if([TradPlusPangleSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusPangleSDKLoader sharedInstance].initSource = initSource;
    }
    [[TradPlusPangleSDKLoader sharedInstance] initWithAppID:self.appId delegate:self];
}

#pragma mark - TPSDKLoaderDelegate
- (void)tpInitFinish
{
    if(self.isS2SBidding)
    {
        [self getBiddingToken];
    }
    else
    {
        [self loadAd];
    }
}

- (void)tpInitFailWithError:(NSError *)error
{
    if(self.isS2SBidding)
    {
        NSString *errorStr = @"S2S Init Fail";
        if(error != nil)
        {
            errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.localizedDescription];
        }
        [self failS2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        [self AdLoadFailWithError:error];
    }
}

- (void)loadAd
{
    if(self.waterfallItem.dicCustomValue != nil
       && [self.waterfallItem.dicCustomValue valueForKey:@"pangleGlobal_appIcon"])
    {
        id appIcon = self.waterfallItem.dicCustomValue[@"pangleGlobal_appIcon"];
        if([appIcon isKindOfClass:[UIImage class]])
        {
            [[TradPlusPangleSDKLoader sharedInstance] setIcon:appIcon];
        }
    }
    
    if(self.waterfallItem.extraInfoDictionary != nil
       && [self.waterfallItem.extraInfoDictionary valueForKey:@"localParams"])
    {
        id localParams = self.waterfallItem.extraInfoDictionary[@"localParams"];
        if([localParams isKindOfClass:[NSDictionary class]]
           && [localParams valueForKey:@"pangleGlobal_appIcon"])
        {
            id appIcon = localParams[@"pangleGlobal_appIcon"];
            if([appIcon isKindOfClass:[UIImage class]])
            {
                [[TradPlusPangleSDKLoader sharedInstance] setIcon:appIcon];
            }
        }
    }
    
    PAGAppOpenRequest *request = [PAGAppOpenRequest request];
    NSString *bidToken = nil;
    if(self.waterfallItem.adsourceplacement != nil)
    {
        bidToken = self.waterfallItem.adsourceplacement.adm;
    }
    if(bidToken != nil)
    {
        request.adString = bidToken;
    }
    __weak typeof(self) weakSelf = self;
    [PAGLAppOpenAd loadAdWithSlotID:self.placementId request:request completionHandler:^(PAGLAppOpenAd * _Nullable appOpenAd, NSError * _Nullable error) {
        if(error != nil)
        {
            MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
            [weakSelf AdLoadFailWithError:error];
            return;
        }
        else
        {
            weakSelf.splashAd = appOpenAd;
            weakSelf.splashAd.delegate = weakSelf;
            [weakSelf AdLoadFinsh];
        }
    }];
}

- (BOOL)isReady
{
    return (self.splashAd != nil);
}

- (id)getCustomObject
{
    return self.splashAd;
}

- (void)showAdInWindow:(UIWindow *)window bottomView:(UIView *)bottomView
{
    [self.splashAd presentFromRootViewController:window.rootViewController];
}

#pragma mark - PAGLAppOpenAdDelegate

- (void)adDidShow:(PAGLAppOpenAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)adDidClick:(PAGLAppOpenAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)adDidDismiss:(PAGLAppOpenAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

@end
