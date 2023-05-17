#import "TradPlusPangleBannerAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <PAGAdSDK/PAGSdk.h>
#import <PAGAdSDK/PAGBannerAd.h>
#import "TradPlusPangleSDKLoader.h"
#import "TPPangleAdapterBaseInfo.h"

@interface TradPlusPangleBannerAdapter ()<TPSDKLoaderDelegate,PAGBannerAdDelegate>

@property (nonatomic, strong) PAGBannerAd *bannerAd;
@property (nonatomic, strong) UIView *bannerView;
@property (nonatomic,copy)NSString *placementId;
@property (nonatomic, assign) BOOL isS2SBidding;
@property (nonatomic,copy)NSString *appId;
@end

@implementation TradPlusPangleBannerAdapter

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
    else if([event isEqualToString:@"S2SBidding"])
    {
        [self initSDKS2SBidding];
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
        MSLogTrace(@"Pangle init Config Error %@",config);
        return;
    }
    if([TradPlusPangleSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusPangleSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusPangleSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_PangleAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [TradPlusPangleSDKLoader getSDKVersion];
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_PangleAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

#pragma mark - S2SBidding

- (void)initSDKS2SBidding
{
    self.isS2SBidding = YES;
    [self initSDKWithWaterfallItem:self.waterfallItem initSource:2];
}

- (void)getBiddingToken
{
    NSString *token = [PAGSdk getBiddingToken:self.appId];
    if(token == nil)
    {
        token = @"";
    }
    NSString *version = [TradPlusPangleSDKLoader getCurrentVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{@"token":token,@"version":version};
    [self ADLoadExtraCallbackWithEvent:@"S2SBiddingFinish" info:dic];
}

- (void)failS2SBiddingWithErrorStr:(NSString *)errorStr
{
    NSDictionary *dic = @{@"error":errorStr};
    [self ADLoadExtraCallbackWithEvent:@"S2SBiddingFail" info:dic];
}


#pragma mark - 普通

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    [self initSDKWithWaterfallItem:item initSource:3];
}

- (void)initSDKWithWaterfallItem:(TradPlusAdWaterfallItem *)item initSource:(NSInteger)initSource
{
    self.appId = item.config[@"appId"];
    self.placementId = item.config[@"placementId"];
    if(self.placementId == nil || self.appId == nil)
    {
        [self AdConfigError];
        return;
    }
    if([TradPlusPangleSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusPangleSDKLoader sharedInstance].initSource = initSource;
    }
    [[TradPlusPangleSDKLoader sharedInstance] initWithAppID:self.appId delegate:self];
}

#pragma mark - TPSDKLoaderDelegate
- (void)tpInitFinish
{
    if(self.isS2SBidding)
    {
        [self getBiddingToken];
    }
    else
    {
        [self loadAd];
    }
}

- (void)tpInitFailWithError:(NSError *)error
{
    if(self.isS2SBidding)
    {
        NSString *errorStr = @"S2S Init Fail";
        if(error != nil)
        {
            errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.localizedDescription];
        }
        [self failS2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        [self AdLoadFailWithError:error];
    }
}

- (void)loadAd
{
    PAGBannerAdSize bannerSize = [self getAdBannerSize];
    CGSize size;
    if(self.waterfallItem.bannerSize.width > 0
       && self.waterfallItem.bannerSize.height)
    {
        size = self.waterfallItem.bannerSize;
    }
    else
    {
        size = [self getAdSize];
    }
    PAGBannerRequest *request = [PAGBannerRequest requestWithBannerSize:bannerSize];
    NSString *bidToken = nil;
    if(self.waterfallItem.adsourceplacement != nil)
    {
        bidToken = self.waterfallItem.adsourceplacement.adm;
    }
    if(bidToken != nil)
    {
        request.adString = bidToken;
    }
    __weak typeof(self) weakSelf = self;
    [PAGBannerAd loadAdWithSlotID:self.placementId
                          request:request
                completionHandler:^(PAGBannerAd * _Nullable bannerAd, NSError * _Nullable error) {
        
        if (error) {
            MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
            [weakSelf AdLoadFailWithError:error];
            return;
        }
        
        weakSelf.bannerAd = bannerAd;
        weakSelf.bannerAd.delegate = weakSelf;
        weakSelf.bannerView = weakSelf.bannerAd.bannerView;
        CGRect rect = CGRectZero;
        rect.size = size;
        weakSelf.bannerView.frame = rect;
        [weakSelf AdLoadFinsh];
    }];
}

- (PAGBannerAdSize)getAdBannerSize
{
    switch (self.waterfallItem.ad_size)
    {
        case 2:
            return kPAGBannerSize300x250;
        default:
            return kPAGBannerSize320x50;
    }
}

- (CGSize)getAdSize
{
    CGFloat width = [self.waterfallItem.ad_size_info[@"X"] floatValue];
    CGFloat height = [self.waterfallItem.ad_size_info[@"Y"] floatValue];
    switch (self.waterfallItem.ad_size)
    {
        case 2:
        {
            if(width == 0)
                width = 600;
            if(height == 0)
                height = 500;
            break;
        }
        default:
        {
            if(width == 0)
                width = 640;
            if(height == 0)
                height = 100;
            break;
        }
    }
    width = width/2;
    height = height/2;
    return CGSizeMake(width, height);;
}

- (BOOL)isReady
{
    return (self.bannerView != nil);
}

- (id)getCustomObject
{
    return self.bannerView;
}

- (void)bannerDidAddSubView:(UIView *)subView
{
    [self setBannerCenterWithBanner:self.bannerView subView:subView];
    [self AdShow];
}

#pragma mark - PAGBannerAdDelegate

- (void)adDidShow:(PAGBannerAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)adDidClick:(PAGBannerAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)adDidDismiss:(PAGBannerAd *)ad
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}
@end
