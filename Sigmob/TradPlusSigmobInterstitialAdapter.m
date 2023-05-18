#import "TradPlusSigmobInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TradPlusSigmobSDKLoader.h"
#import <WindSDK/WindSDK.h>
#import "TPSigmobAdapterBaseInfo.h"

@interface TradPlusSigmobInterstitialAdapter ()<WindRewardVideoAdDelegate,WindIntersititialAdDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) WindRewardVideoAd *rewardVideoAd;
@property (nonatomic, strong) WindIntersititialAd *intersititialAd;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic) BOOL isRewardedVideo;
@end

@implementation TradPlusSigmobInterstitialAdapter

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
    NSString *appKey = config[@"AppKey"];
    if(appId == nil || appKey == nil)
    {
        MSLogTrace(@"Sigmob init Config Error %@",config);
        return;
    }
    if([TradPlusSigmobSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusSigmobSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusSigmobSDKLoader sharedInstance] initWithAppID:appId appKey:appKey delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_SigmobAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [WindAds sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_SigmobAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *appId = item.config[@"appId"];
    NSString *appKey = item.config[@"AppKey"];
    self.placementId = item.config[@"placementId"];
    if(appId == nil || appKey == nil || self.placementId == nil)
    {
        [self AdConfigError];
        return;
    }
    [[TradPlusSigmobSDKLoader sharedInstance] initWithAppID:appId appKey:appKey delegate:self];
}

- (void)loadAd
{
    [[TradPlusSigmobSDKLoader sharedInstance] setPersonalizedAd];
    NSString *bidToken = nil;
    if(self.waterfallItem.adsourceplacement != nil)
    {
        bidToken = self.waterfallItem.adsourceplacement.adm;
    }
    
    self.isRewardedVideo = (self.waterfallItem.sigmob_type == 2);
    WindAdRequest *request = [WindAdRequest request];
    request.placementId = self.placementId;
    if(self.isRewardedVideo)
    {
        self.rewardVideoAd = [[WindRewardVideoAd alloc] initWithRequest:request];
        self.rewardVideoAd.delegate = self;
        if(bidToken == nil)
        {
            [self.rewardVideoAd loadAdData];
        }
        else
        {
            [self.rewardVideoAd loadAdDataWithBidToken:bidToken];
        }
    }
    else
    {
        self.intersititialAd = [[WindIntersititialAd alloc] initWithRequest:request];
        self.intersititialAd.delegate = self;
        if(bidToken == nil)
        {
            [self.intersititialAd loadAdData];
        }
        else
        {
            [self.intersititialAd loadAdDataWithBidToken:bidToken];
        }
    }
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
    if(self.isRewardedVideo)
    {
        return self.rewardVideoAd;
    }
    else
    {
        return self.intersititialAd;
    }
}

- (BOOL)isReady
{
    if(self.isRewardedVideo)
    {
        return (self.rewardVideoAd != nil
                    && self.rewardVideoAd.ready);
    }
    else
    {
        return (self.intersititialAd != nil
                    && self.intersititialAd.ready);
    }
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    if(self.isRewardedVideo)
    {
        [self.rewardVideoAd showAdFromRootViewController:rootViewController options:nil];
    }
    else
    {
        [self.intersititialAd showAdFromRootViewController:rootViewController options:nil];
    }
}

#pragma mark - WindIntersititialAdDelegate

- (void)intersititialAdDidLoad:(WindIntersititialAd *)intersititialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}


- (void)intersititialAdDidLoad:(WindIntersititialAd *)intersititialAd didFailWithError:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFailWithError:error];
}

- (void)intersititialAdDidVisible:(WindIntersititialAd *)intersititialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}


- (void)intersititialAdDidClick:(WindIntersititialAd *)intersititialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)intersititialAdDidClose:(WindIntersititialAd *)intersititialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

- (void)intersititialAdDidPlayFinish:(WindIntersititialAd *)intersititialAd didFailWithError:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(error != nil)
    {
        [self AdShowFailWithError:error];
    }
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}

- (void)intersititialAdWillVisible:(WindIntersititialAd *)intersititialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)intersititialAdDidClickSkip:(WindIntersititialAd *)intersititialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


- (void)intersititialAdServerResponse:(WindIntersititialAd *)intersititialAd isFillAd:(BOOL)isFillAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

#pragma mark - WindRewardVideoAdDelegate

- (void)rewardVideoAdDidLoad:(WindRewardVideoAd *)rewardVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}


- (void)rewardVideoAdDidLoad:(WindRewardVideoAd *)rewardVideoAd didFailWithError:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFailWithError:error];
}


- (void)rewardVideoAdDidVisible:(WindRewardVideoAd *)rewardVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}


- (void)rewardVideoAdDidClick:(WindRewardVideoAd *)rewardVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)rewardVideoAdDidPlayFinish:(WindRewardVideoAd *)rewardVideoAd didFailWithError:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(error != nil)
    {
        [self AdShowFailWithError:error];
    }
}

- (void)rewardVideoAdDidClose:(WindRewardVideoAd *)rewardVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

- (void)rewardVideoAdDidClickSkip:(WindRewardVideoAd *)rewardVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardVideoAdWillVisible:(WindRewardVideoAd *)rewardVideoAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardVideoAdServerResponse:(WindRewardVideoAd *)rewardVideoAd isFillAd:(BOOL)isFillAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)rewardVideoAd:(WindRewardVideoAd *)rewardVideoAd reward:(WindRewardInfo *)reward {
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}


@end
