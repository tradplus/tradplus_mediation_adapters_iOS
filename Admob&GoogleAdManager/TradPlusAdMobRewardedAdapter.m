#import "TradPlusAdMobRewardedAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MSConsentManager.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <GoogleMobileAds/GoogleMobileAds.h>
#import "TPGoogleAdMobAdapterConfig.h"
#import "TPAdMobAdapterBaseInfo.h"

@interface TradPlusAdMobRewardedAdapter ()<GADFullScreenContentDelegate>

@property (nonatomic,assign)BOOL isFullScreen;
@property (nonatomic,strong)GADRewardedAd *rewardedAd;
@property (nonatomic,strong)GADRewardedInterstitialAd *rewardedInterstitialAd;
@property (nonatomic,assign) BOOL shouldReward;
@property (nonatomic,assign) BOOL alwaysReward;
@end

@implementation TradPlusAdMobRewardedAdapter

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

//三方SDK版本号
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
    
    GADRequest *request = [GADRequest request];
    if (![MSConsentManager sharedManager].canCollectPersonalInfo
        || !gTPOpenPersonalizedAd)
    {
        MSLogTrace(@"***********");
        MSLogTrace(@"admob non-personalized ads");
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
                [weakSelf loadFinishWithRewardedAd:rewardedAd];
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
                [weakSelf loadFinishWithRewardedInterstitialAd:rewardedInterstitialAd];
            }
            else
            {
                [weakSelf AdLoadFailWithError:error];
            }
        }];
    }
}

- (void)loadFinishWithRewardedInterstitialAd:(GADRewardedInterstitialAd *)rewardedInterstitialAd
{
    self.rewardedInterstitialAd = rewardedInterstitialAd;
    [self setServerSide];
    __weak typeof(self) weakSelf = self;
    self.rewardedInterstitialAd.paidEventHandler = ^void(GADAdValue *_Nonnull value){
        NSString *imp_ecpm = [NSString stringWithFormat:@"%@",value.value];
        NSString *imp_currency = value.currencyCode;
        NSString *imp_precision = [NSString stringWithFormat:@"%ld",(long)value.precision];
        weakSelf.waterfallItem.extraInfoDictionary[@"imp_ecpm"] = imp_ecpm;
        weakSelf.waterfallItem.extraInfoDictionary[@"imp_currency"] = imp_currency;
        weakSelf.waterfallItem.extraInfoDictionary[@"imp_precision"] = imp_precision;
        [weakSelf ADShowExtraCallbackWithEvent:@"tradplus_imp_show1310" info:nil];
    };
    
    [self AdLoadFinsh];
}

- (void)loadFinishWithRewardedAd:(GADRewardedAd *)rewardedAd
{
    self.rewardedAd = rewardedAd;
    [self setServerSide];
    __weak typeof(self) weakSelf = self;
    self.rewardedAd.paidEventHandler = ^void(GADAdValue *_Nonnull value){
        NSString *imp_ecpm = [NSString stringWithFormat:@"%@",value.value];
        NSString *imp_currency = value.currencyCode;
        NSString *imp_precision = [NSString stringWithFormat:@"%@",@(value.precision)];
        weakSelf.waterfallItem.extraInfoDictionary[@"imp_ecpm"] = imp_ecpm;
        weakSelf.waterfallItem.extraInfoDictionary[@"imp_currency"] = imp_currency;
        weakSelf.waterfallItem.extraInfoDictionary[@"imp_precision"] = imp_precision;
        [weakSelf ADShowExtraCallbackWithEvent:@"tradplus_imp_show1310" info:nil];
    };
    [self AdLoadFinsh];
}

//服务器奖励验证信息
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
