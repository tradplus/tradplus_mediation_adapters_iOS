
#import "TradPlusHeliumInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <ChartboostMediationSDK/ChartboostMediationSDK.h>
#import "TradPlusHeliumSDKLoader.h"
#import "TPHeliumAdapterBaseInfo.h"

@interface TradPlusHeliumInterstitialAdapter ()<CHBHeliumInterstitialAdDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong) id<HeliumInterstitialAd> interstitial;
@property (nonatomic,copy) NSString *placementId;
@property (nonatomic,assign) BOOL isC2SBidding;
@end

@implementation TradPlusHeliumInterstitialAdapter

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
    NSString *appSignature = config[@"app_signature"];
    if(appId == nil  ||  appId.length <= 5)
    {
        MSLogTrace(@"Helium init Config Error %@",config);
        return;
    }
    if([TradPlusHeliumSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusHeliumSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusHeliumSDKLoader sharedInstance] initWithAppID:appId appSignature:appSignature delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_HeliumAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = Helium.sdkVersion;
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_HeliumAdapter_PlatformSDK_Version
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
    NSString *appId = item.config[@"appId"];
    NSString *appSignature = item.config[@"app_signature"];
    self.placementId = item.config[@"placementId"];
    if(appId == nil || self.placementId == nil || appId.length <= 5)
    {
        MSLogTrace(@"Helium init Config Error %@",item.config);
        [self AdConfigError];
        return;
    }
    if([TradPlusHeliumSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusHeliumSDKLoader sharedInstance].initSource = initSource;
    }
    [[TradPlusHeliumSDKLoader sharedInstance] initWithAppID:appId appSignature:appSignature delegate:self];
}

- (void)loadAd
{
    self.interstitial = [[Helium sharedHelium] interstitialAdProviderWithDelegate:self andPlacementName:self.placementId];
    [self.interstitial loadAd];
}

- (id)getCustomObject
{
    return self.interstitial;
}

- (BOOL)isReady
{
    return self.interstitial.readyToShow;
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.interstitial showAdWithViewController:rootViewController];
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
        NSError *loadError = [NSError errorWithDomain:@"helium.interstitial" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S Interstitial not ready"}];
        [self AdLoadFailWithError:loadError];
    }
}

- (void)finishC2SBiddingWithAd:(NSDictionary *)bidInfo
{
    NSString *version = Helium.sdkVersion;
    if(version == nil)
    {
        version = @"";
    }
    id ecpm = [bidInfo objectForKey:@"price"];
    NSString *ecpmStr = [NSString stringWithFormat:@"%@",ecpm];
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

#pragma mark - CHBHeliumInterstitialAdDelegate
- (void)heliumInterstitialAdWithPlacementName:(NSString * _Nonnull)placementName
                            requestIdentifier:(NSString * _Nonnull)requestIdentifier
                               winningBidInfo:(NSDictionary<NSString *,id> * _Nullable)winningBidInfo
                             didLoadWithError:(ChartboostMediationError * _Nullable)error
{
    
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(error == nil)
    {
        if(self.isC2SBidding)
        {
            [self finishC2SBiddingWithAd:winningBidInfo];
        }
        else
        {
            [self AdLoadFinsh];
        }
    }
    else
    {
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
}

- (void)heliumInterstitialAdWithPlacementName:(NSString *)placementName
                             didShowWithError:(nullable ChartboostMediationError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if (error)
    {
        [self AdShowFailWithError:error];
    } else {
        [self AdShow];
    }
}

- (void)heliumInterstitialAdWithPlacementName:(NSString *)placementName
                            didCloseWithError:(nullable ChartboostMediationError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error.description);
    [self AdClose];
}

- (void)heliumInterstitialAdWithPlacementName:(NSString *)placementName
                            didClickWithError:(nullable ChartboostMediationError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error.description);
    [self AdClick];
}
- (void)heliumInterstitialAdDidRecordImpressionWithPlacementName:(NSString *)placementName
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

@end
