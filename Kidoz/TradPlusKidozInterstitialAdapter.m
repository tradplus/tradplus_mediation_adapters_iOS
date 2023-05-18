#import "TradPlusKidozInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TradPlusKidozSDKLoader.h"
#import "TPKidozAdapterBaseInfo.h"

@interface TradPlusKidozInterstitialAdapter ()<KDZInterstitialDelegate,TPSDKLoaderDelegate>

@property (nonatomic,assign)BOOL didLoaded;
@end

@implementation TradPlusKidozInterstitialAdapter

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
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

- (void)setupAd
{
    if(![[KidozSDK instance] isInterstitialInitialized])
    {
        [[KidozSDK instance] initializeInterstitialWithDelegate:self];
        return;
    }
    else
    {
        [[KidozSDK instance] setInterstitialDelegate:self];
    }
    [self loadAd];
}

- (void)loadAd
{
    [[KidozSDK instance] loadInterstitial];
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [[KidozSDK instance] showInterstitial];
}

- (BOOL)isReady
{
    return [[KidozSDK instance] isInterstitialReady];
}

- (id)getCustomObject
{
    return nil;
}



#pragma mark - KDZInterstitialDelegate
-(void)interstitialDidInitialize
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self loadAd];
}

-(void)interstitialDidClose
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

-(void)interstitialDidOpen
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

-(void)interstitialIsReady
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

-(void)interstitialLoadFailed
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSError *loadError = [NSError errorWithDomain:@"Kidoz" code:404 userInfo:@{NSLocalizedDescriptionKey:@"load failed"}];
    [self AdLoadFailWithError:loadError];
}

-(void)interstitialLeftApplication
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

-(void)interstitialDidReciveError:(NSString*)errorMessage
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

-(void)interstitialReturnedWithNoOffers
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

-(void)interstitialDidPause
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

-(void)interstitialDidResume
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
@end
