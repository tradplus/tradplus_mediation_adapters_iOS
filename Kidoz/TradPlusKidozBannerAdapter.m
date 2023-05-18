#import "TradPlusKidozBannerAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TradPlusKidozSDKLoader.h"
#import "TPKidozAdapterBaseInfo.h"

@interface TradPlusKidozBannerAdapter ()<KDZInitDelegate,KDZBannerDelegate,TPSDKLoaderDelegate>

@property (nonatomic,strong)UIView *bannerView;
@end

@implementation TradPlusKidozBannerAdapter

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
    [self setupBanner];
}

- (void)tpInitFailWithError:(NSError *)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

- (void)setupBanner
{
    self.bannerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
    [[KidozSDK instance] initializeBannerWithDelegate:self withView:self.bannerView];
}

- (void)bannerDidAddSubView:(UIView *)subView
{
    [self setBannerCenterWithBanner:self.bannerView subView:subView];
    [[KidozSDK instance] showBanner];
}

- (BOOL)isReady
{
    return [[KidozSDK instance] isBannerReady];
}

- (id)getCustomObject
{
    return self.bannerView;
}

#pragma mark - KDZBannerDelegate
-(void)bannerDidInitialize
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [[KidozSDK instance] loadBanner];
}

-(void)bannerDidClose
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

-(void)bannerIsReady
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

-(void)bannerLoadFailed
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSError *loadError = [NSError errorWithDomain:@"Kidoz" code:404 userInfo:@{NSLocalizedDescriptionKey:@"load failed"}];
    [self AdLoadFailWithError:loadError];
}

- (void)bannerShowFailed
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSError *showError = [NSError errorWithDomain:@"Kidoz" code:404 userInfo:@{NSLocalizedDescriptionKey:@"show failed"}];
    [self AdShowFailWithError:showError];
}

-(void)bannerDidOpen
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

-(void)bannerReturnedWithNoOffers
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

-(void)bannerDidReciveError:(NSString*)errorMessage
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,errorMessage);
}

-(void)bannerLeftApplication
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

#pragma mark - KDZInitDelegate
-(void)onInitSuccess
{
    [self setupBanner];
}

-(void)onInitError:(NSString *)error
{
    NSError *initError = [NSError errorWithDomain:@"Kidoz" code:403 userInfo:@{NSLocalizedDescriptionKey:error}];
    [self AdLoadFailWithError:initError];
}
@end
