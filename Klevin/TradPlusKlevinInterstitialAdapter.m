#import "TradPlusKlevinInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TradPlusKlevinSDKLoader.h"
#import <KlevinAdSDK/KlevinAdSDK.h>
#import <KlevinAdSDK/KLNInterstitialAd.h>
#import "TPKlevinAdapterBaseInfo.h"

@interface TradPlusKlevinInterstitialAdapter ()<KLNFullScreenContentDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong)NSString *placementId;
@property (nonatomic,strong)KLNInterstitialAd *interstitialAd;
@property (nonatomic,assign)BOOL isC2SBidding;
@end

@implementation TradPlusKlevinInterstitialAdapter

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
    NSString *appId = config[@"appId"];
    if(appId == nil)
    {
        MSLogTrace(@"Klevin init Config Error %@",config);
        return;
    }
    if([TradPlusKlevinSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusKlevinSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusKlevinSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_KlevinAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [KlevinAdSDK sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_KlevinAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    self.placementId = item.config[@"placementId"];
    NSString *appId = item.config[@"appId"];
    if(self.placementId == nil || appId == nil)
    {
        [self AdConfigError];
        return;
    }

    [[TradPlusKlevinSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    [[TradPlusKlevinSDKLoader sharedInstance] setPersonalizedAd];
    KLNInterstitialAdRequest *req = [[KLNInterstitialAdRequest alloc] initWithPosId:self.placementId];
    __weak typeof(self) weakSelf = self;
    [KLNInterstitialAd loadWithRequest:req completionHandler:^(KLNInterstitialAd * _Nullable interstitialAd, NSError * _Nullable error) {
        if(error == nil)
        {
            weakSelf.interstitialAd = interstitialAd;
            if(self.isC2SBidding)
            {
                [self finishC2SBiddingWithEcpm:interstitialAd.eCPM];
            }
            else
            {
                [weakSelf AdLoadFinsh];
            }
        }
        else
        {
            if(self.isC2SBidding)
            {
                NSString *errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.description];
                [self failC2SBiddingWithErrorStr:errorStr];
            }
            else
            {
                MSLogTrace(@"%s %@", __PRETTY_FUNCTION__ ,error);
                [weakSelf AdLoadFailWithError:error];
            }
        }
    }];
}

#pragma mark - C2SBidding

- (void)initSDKC2SBidding
{
    self.isC2SBidding = YES;
    [self loadAdWithWaterfallItem:self.waterfallItem];
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
        NSError *loadError = [NSError errorWithDomain:@"Klevin" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S Interstitial not ready"}];
        [self AdLoadFailWithError:loadError];
    }
}

- (void)finishC2SBiddingWithEcpm:(NSInteger)ecpm
{
    NSString *version = TP_KlevinAdapter_PlatformSDK_Version;
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{@"ecpm":[NSString stringWithFormat:@"%ld", (long)ecpm],@"version":version};
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
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__, error);
    if(self.isC2SBidding)
    {
        NSString *errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.description];
        [self failC2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        [self AdLoadFailWithError:error];
    }
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    NSError *error;
    if([self.interstitialAd canPresentFromRootViewController:rootViewController error:&error])
    {
        self.interstitialAd.fullScreenContentDelegate = self;
        [self.interstitialAd presentFromRootViewController:rootViewController];
    }
    else
    {
        MSLogTrace(@"%s %@", __PRETTY_FUNCTION__ ,error);
        [self AdShowFailWithError:error];
    }
}

- (BOOL)isReady
{
    return (self.interstitialAd != nil);
}

- (id)getCustomObject
{
    return self.interstitialAd;
}

#pragma mark - KLNFullScreenContentDelegate
- (void)adDidRecordImpression:(nonnull id<KLNFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)adDidRecordClick:(nonnull id<KLNFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)adDidDismissFullScreenContent:(nonnull id<KLNFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

- (void)ad:(nonnull id<KLNFullScreenPresentingAd>)ad
    didFailToPresentFullScreenContentWithError:(nonnull NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdShowFailWithError:error];
}

- (void)adDidRecordSkip:(nonnull id<KLNFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_splash_skip" info:nil];
}

- (void)adDidPresentFullScreenContent:(nonnull id<KLNFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

@end
