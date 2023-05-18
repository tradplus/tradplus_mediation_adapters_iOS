#import "TradPlusInMobiBannerAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <InMobiSDK/InMobiSDK.h>
#import "TradPlusInMobiSDKLoader.h"
#import "TPInMobiAdapterBaseInfo.h"

@interface TradPlusInMobiBannerAdapter ()<IMBannerDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) IMBanner *banner;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, assign) BOOL isC2SBidding;
@property (nonatomic, assign) NSInteger impressedState;
@end

@implementation TradPlusInMobiBannerAdapter

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
    NSString *account_id = config[@"account_id"];
    if(account_id == nil || [account_id isKindOfClass:[NSNull class]])
    {
        MSLogTrace(@"InMobi init Config Error %@",config);
        return;
    }
    if([TradPlusInMobiSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusInMobiSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusInMobiSDKLoader sharedInstance] initWithAccountID:account_id delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_InMobiAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [IMSdk getVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_InMobiAdapter_PlatformSDK_Version
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
    NSString *account_id = item.config[@"account_id"];
    self.placementId = item.config[@"placementId"];
    if(account_id == nil || [account_id isKindOfClass:[NSNull class]] || self.placementId == nil)
    {
        MSLogTrace(@"InMobi init Config Error %@",item.config);
        [self AdConfigError];
        return;
    }
    if([TradPlusInMobiSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusInMobiSDKLoader sharedInstance].initSource = initSource;
    }
    [[TradPlusInMobiSDKLoader sharedInstance] initWithAccountID:account_id delegate:self];
}

- (void)setupBanner
{
    CGFloat width;
    CGFloat height;
    switch (self.waterfallItem.ad_size)
    {
        case 2:
        {
            width = 300;
            height = 250;
            break;
        }
        case 1:
        {
            width = 320;
            height = 50;
            break;
        }
        default:
        {
            width = [self.waterfallItem.ad_size_info[@"X"] floatValue];
            height = [self.waterfallItem.ad_size_info[@"Y"] floatValue];
            if(width == 0)
                width = 320;
            if(height == 0)
                height = 50;
            break;
        }
    }
    self.banner = [[IMBanner alloc] initWithFrame:CGRectMake(0, 0, width, height)
                                      placementId:[self.placementId longLongValue]];
    self.banner.delegate = self;
    self.banner.extras = [[TradPlusInMobiSDKLoader sharedInstance] getExtras];
}

- (void)loadAd
{
    [self setupBanner];
    [self.banner load];
}

- (void)bannerDidAddSubView:(UIView *)subView
{
    [self setBannerCenterWithBanner:self.banner subView:subView];
    if(self.impressedState == 0)
    {
        self.impressedState = 2;
    }
    else if(self.impressedState == 1)
    {
        [self AdShow];
    }
}

- (BOOL)isReady
{
    return (self.banner != nil);
}

- (id)getCustomObject
{
    return self.banner;
}

#pragma mark - C2SBidding

- (void)initSDKC2SBidding
{
    self.isC2SBidding = YES;
    [self initSDKWithWaterfallItem:self.waterfallItem initSource:2];
}

- (void)startC2SBidding
{
    [self setupBanner];
    [self.banner.preloadManager preload];
}

- (void)loadAdC2SBidding
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self.banner.preloadManager load];
}

- (void)finishC2SBiddingWithMetaInfo:(IMAdMetaInfo*)info
{
    NSString *version = [IMSdk getVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSString *ecpmStr = [NSString stringWithFormat:@"%f",info.getBid];
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
    if(self.isC2SBidding)
    {
        [self startC2SBidding];
    }
    else
    {
        [self loadAd];
    }
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

#pragma mark - IMBannerDelegate
-(void)bannerAdImpressed:(IMBanner*)banner
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.impressedState == 0)
    {
        self.impressedState = 1;
    }
    else if(self.impressedState == 2)
    {
        [self AdShow];
    }
}

-(void)banner:(IMBanner*)banner didReceiveWithMetaInfo:(IMAdMetaInfo*)info
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self finishC2SBiddingWithMetaInfo:info];
}

-(void)banner:(IMBanner*)banner didFailToReceiveWithError:(IMRequestStatus*)error
{
    MSLogTrace(@"%s error %@", __PRETTY_FUNCTION__,error);
    NSString *errorStr = @"C2S Bidding Fail";
    if(error != nil)
    {
        errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.localizedDescription];
    }
    [self failC2SBiddingWithErrorStr:errorStr];
}


-(void)bannerDidFinishLoading:(IMBanner*)banner;
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

-(void)banner:(IMBanner*)banner didFailToLoadWithError:(IMRequestStatus*)error;
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdLoadFailWithError:error];
}

-(void)bannerWillPresentScreen:(IMBanner*)banner
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

-(void)userWillLeaveApplicationFromBanner:(IMBanner*)banner;
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

@end
