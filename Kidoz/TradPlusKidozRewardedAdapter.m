#import "TradPlusKidozRewardedAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TradPlusKidozSDKLoader.h"
#import "TPKidozAdapterBaseInfo.h"

@interface TradPlusKidozRewardedAdapter ()<KDZRewardedDelegate,TPSDKLoaderDelegate>

@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;
@end

@implementation TradPlusKidozRewardedAdapter

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
    NSString *securityToken = config[@"securityToken"];
    if(appId == nil || securityToken == nil)
    {
        MSLogTrace(@"Kidoz init Config Error %@",config);
        return;
    }
    if([TradPlusKidozSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusKidozSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusKidozSDKLoader sharedInstance] initWithAppID:appId securityToken:securityToken delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_KidozAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [[KidozSDK instance] getSdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_KidozAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *appId = item.config[@"appId"];
    NSString *securityToken = item.config[@"securityToken"];
    if(appId == nil || securityToken == nil)
    {
        [self AdConfigError];
        return;
    }
    if([item.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [item.extraInfoDictionary[@"always_reward"] integerValue] == 1;
    }
    [[TradPlusKidozSDKLoader sharedInstance] initWithAppID:appId securityToken:securityToken delegate:self];
}

#pragma mark - TPSDKLoaderDelegate
- (void)tpInitFinish
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self setupAd];
}

- (void)tpInitFailWithError:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__ , error);
    [self AdLoadFailWithError:error];
}

- (void)setupAd
{
    if(![[KidozSDK instance] isRewardedInitialized])
    {
        [[KidozSDK instance] initializeRewardedWithDelegate:self];
        return;
    }
    else
    {
        [[KidozSDK instance] setRewardedDelegate:self];
    }
    [self loadAd];
}

- (void)loadAd
{
    [[KidozSDK instance] loadRewarded];
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [[KidozSDK instance] showRewarded];
}

- (BOOL)isReady
{
    return [[KidozSDK instance] isRewardedReady];
}

- (id)getCustomObject
{
    return nil;
}

#pragma mark - KDZRewardedDelegate
-(void)rewardedDidInitialize
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self loadAd];
}
-(void)rewardedDidClose
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
    if (self.shouldReward || self.alwaysReward)
        [self AdRewardedWithInfo:nil];
    [self AdClose];
}

-(void)rewardedDidOpen
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

-(void)rewardedLeftApplication
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

-(void)rewardedIsReady
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

-(void)rewardedLoadFailed
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSError *loadError = [NSError errorWithDomain:@"Kidoz" code:404 userInfo:@{NSLocalizedDescriptionKey:@"load failed"}];
    [self AdLoadFailWithError:loadError];
}

-(void)rewardReceived
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.shouldReward = YES;
}

-(void)rewardedReturnedWithNoOffers
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

-(void)rewardedDidPause
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

-(void)rewardedDidResume
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

-(void)rewardedDidReciveError:(NSString*)errorMessage
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(!self.isAdReady)
    {
        NSError *loadError = [NSError errorWithDomain:@"Kidoz" code:404 userInfo:@{NSLocalizedDescriptionKey:@"load failed"}];
        [self AdLoadFailWithError:loadError];
    }
    else
    {
        NSError *showError = [NSError errorWithDomain:@"Kidoz" code:404 userInfo:@{NSLocalizedDescriptionKey:errorMessage}];
        [self AdShowFailWithError:showError];
    }
}

-(void)rewardedStarted
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
@end
