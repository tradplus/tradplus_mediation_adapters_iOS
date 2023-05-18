#import "TradPlusOguryRewardedAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TradPlusOgurySDKLoader.h"
#import <OguryAds/OguryAds.h>
#import <OgurySdk/Ogury.h>
#import <OguryChoiceManager/OguryChoiceManager.h>
#import "TPOguryAdapterBaseInfo.h"

@interface TradPlusOguryRewardedAdapter ()<OguryOptinVideoAdDelegate,TPSDKLoaderDelegate>

@property (nonatomic, copy) NSString *appId;
@property (nonatomic, copy) NSString *adUnitId;
@property (nonatomic, strong) OguryOptinVideoAd *optInVideo;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;
@property (nonatomic, strong) NSMutableDictionary *rewardDic;
@end

@implementation TradPlusOguryRewardedAdapter

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
        MSLogTrace(@"Ogury init Config Error %@",config);
        return;
    }
    if([TradPlusOgurySDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusOgurySDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusOgurySDKLoader sharedInstance] initWithAssetKey:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_OguryAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [Ogury getSdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_OguryAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    self.appId = item.config[@"appId"];
    self.adUnitId = item.config[@"placementId"];
    if(self.appId == nil || self.adUnitId == nil)
    {
        [self AdConfigError];
        return;
    }
    if([item.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [item.extraInfoDictionary[@"always_reward"] integerValue] == 1;
    }
    [[TradPlusOgurySDKLoader sharedInstance] initWithAssetKey:self.appId delegate:self];
}

- (void)loadAd
{
    [[TradPlusOgurySDKLoader sharedInstance] setPrivacyWithAssetKey:self.appId];
    
    self.optInVideo = [[OguryOptinVideoAd alloc] initWithAdUnitId:self.adUnitId];
    self.optInVideo.delegate = self;
    
    [self.optInVideo load];
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
    return self.optInVideo;
}

- (BOOL)isReady
{
    return self.optInVideo && self.optInVideo.isLoaded;
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.optInVideo showAdInViewController:rootViewController];
}

#pragma mark - OguryOptinVideoAdDelegate

- (void)didLoadOguryOptinVideoAd:(OguryOptinVideoAd *)optinVideo;
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

-(void)oguryAdsOptinVideoAdNotLoaded
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSError *error = [NSError errorWithDomain:@"Ogury" code:1001 userInfo:@{NSLocalizedDescriptionKey:@"no fill"}];
    [self AdLoadFailWithError:error];
}

- (void)didDisplayOguryOptinVideoAd:(OguryOptinVideoAd *)optinVideo;
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)didCloseOguryOptinVideoAd:(OguryOptinVideoAd *)optinVideo
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
    if (self.shouldReward || self.alwaysReward)
        [self AdRewardedWithInfo:self.rewardDic];
    [self AdClose];
}

- (void)didRewardOguryOptinVideoAdWithItem:(OGARewardItem *)item forAd:(OguryOptinVideoAd *)optinVideo
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    dic[@"rewardName"] = item.rewardName;
    dic[@"rewardNumber"] = item.rewardValue;
    self.rewardDic = [NSMutableDictionary dictionaryWithDictionary:dic];
    self.shouldReward = YES;
}

- (void)didFailOguryOptinVideoAdWithError:(OguryError *)error forAd:(OguryOptinVideoAd *)optinVideo
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShowFailWithError:error];
}

- (void)didClickOguryOptinVideoAd:(OguryOptinVideoAd *)optinVideo
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)didTriggerImpressionOguryOptinVideoAd:(OguryOptinVideoAd *)optinVideo
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

@end
