#import "TradPlusGAMRewardedAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MSConsentManager.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <GoogleMobileAds/GoogleMobileAds.h>
#import "TPAdMobAdapterBaseInfo.h"
#import "TPGoogleAdMobAdapterConfig.h"

@interface TradPlusGAMRewardedAdapter ()<GADFullScreenContentDelegate>

@property (nonatomic,assign)BOOL isFullScreen;
@property (nonatomic,strong)GADRewardedAd *rewardedAd;
@property (nonatomic,strong)GADRewardedInterstitialAd *rewardedInterstitialAd;
@property (nonatomic,assign)BOOL shouldReward;
@property (nonatomic,assign)BOOL alwaysReward;
@end

@implementation TradPlusGAMRewardedAdapter

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
    NSDictionary *dic = @{@"version":TP_AdMobAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [NSString stringWithFormat:@"%s",GoogleMobileAdsVersionString];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_AdMobAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *placementId = item.config[@"placementId"];
    if(placementId == nil)
    {
        [self AdConfigError];
        return;
    }
    [TPGoogleAdMobAdapterConfig setPrivacy:@{}];
    
    self.isFullScreen = (item.full_screen_video == 1);
    
    if([item.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [item.extraInfoDictionary[@"always_reward"] integerValue] == 1;
    }
    
    GAMRequest *request = [GAMRequest request];
    if (![MSConsentManager sharedManager].canCollectPersonalInfo
        || !gTPOpenPersonalizedAd)
    {
        MSLogTrace(@"***********");
        MSLogTrace(@"GAM non-personalized ads");
        MSLogTrace(@"***********");
        GADExtras *extras = [[GADExtras alloc] init];
        extras.additionalParameters = @{@"npa": @"1"};
        [request registerAdNetworkExtras:extras];
    }
    request.requestAgent = @"TradPlusAd";
    
    if(self.isFullScreen)
    {
        __weak typeof(self) weakSelf = self;
        [GADRewardedAd loadWithAdUnitID:placementId request:request completionHandler:^(GADRewardedAd * _Nullable rewardedAd, NSError * _Nullable error) {
            if(error == nil)
            {
                weakSelf.rewardedAd = rewardedAd;
                [weakSelf setServerSide];
                [weakSelf AdLoadFinsh];
            }
            else
            {
                [weakSelf AdLoadFailWithError:error];
            }
        }];
    }
    else
    {
        __weak typeof(self) weakSelf = self;
        [GADRewardedInterstitialAd loadWithAdUnitID:placementId request:request completionHandler:^(GADRewardedInterstitialAd * _Nullable rewardedInterstitialAd, NSError * _Nullable error) {
            if(error == nil)
            {
                weakSelf.rewardedInterstitialAd = rewardedInterstitialAd;
                [weakSelf setServerSide];
                [weakSelf AdLoadFinsh];
            }
            else
            {
                [weakSelf AdLoadFailWithError:error];
            }
        }];
    }
}

- (void)setServerSide
{
    if(self.waterfallItem.serverSideUserID != nil && self.waterfallItem.serverSideUserID.length > 0)
    {
        GADServerSideVerificationOptions *options = [[GADServerSideVerificationOptions alloc] init];
        options.userIdentifier = self.waterfallItem.serverSideUserID;
        if(self.waterfallItem.serverSideCustomData != nil)
        {
            options.customRewardString = self.waterfallItem.serverSideCustomData;
        }
        if(self.isFullScreen)
        {
            self.rewardedAd.serverSideVerificationOptions = options;
        }
        else
        {
            self.rewardedInterstitialAd.serverSideVerificationOptions = options;
        }
        //提示
        if(self.waterfallItem.serverSideCustomData == nil)
        {
            MSLogTrace(@"ADMob ServerSideVerification ->userID: %@", self.waterfallItem.serverSideUserID);
        }
        else
        {
            MSLogTrace(@"ADMob ServerSideVerification ->userID: %@, customData:%@", self.waterfallItem.serverSideUserID, self.waterfallItem.serverSideCustomData);
            
        }
    }
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    if(self.isFullScreen)
    {
        NSError *error;
        if([self.rewardedAd canPresentFromRootViewController:rootViewController error:&error])
        {
            self.rewardedAd.fullScreenContentDelegate = self;
            __weak typeof(self) weakSelf = self;
            [self.rewardedAd presentFromRootViewController:rootViewController userDidEarnRewardHandler:^{
                weakSelf.shouldReward = YES;
            }];
        }
        else
        {
            [self AdShowFailWithError:error];
        }
    }
    else
    {
        NSError *error;
        if([self.rewardedInterstitialAd canPresentFromRootViewController:rootViewController error:&error])
        {
            self.rewardedInterstitialAd.fullScreenContentDelegate = self;
            __weak typeof(self) weakSelf = self;
            [self.rewardedInterstitialAd presentFromRootViewController:rootViewController userDidEarnRewardHandler:^{
                weakSelf.shouldReward = YES;
            }];
        }
        else
        {
            [self AdShowFailWithError:error];
        }
    }
}

- (id)getCustomObject
{
    if(self.isFullScreen)
    {
        return self.rewardedAd;
    }
    else
    {
        return self.rewardedInterstitialAd;
    }
}

- (BOOL)isReady
{
    if(self.isFullScreen)
    {
        return (self.rewardedAd != nil);
    }
    else
    {
        return (self.rewardedInterstitialAd != nil);
    }
}

#pragma mark - GADFullScreenContentDelegate
- (void)adDidRecordImpression:(nonnull id<GADFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)adDidRecordClick:(nonnull id<GADFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)ad:(nonnull id<GADFullScreenPresentingAd>)ad
    didFailToPresentFullScreenContentWithError:(nonnull NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShowFailWithError:error];
}

- (void)adWillDismissFullScreenContent:(nonnull id<GADFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    
}

- (void)adDidDismissFullScreenContent:(nonnull id<GADFullScreenPresentingAd>)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
    if (self.shouldReward || self.alwaysReward)
        [self AdRewardedWithInfo:nil];
    [self AdClose];
}
@end
