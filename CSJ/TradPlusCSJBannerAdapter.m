#import "TradPlusCSJBannerAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <BUAdSDK/BUAdSDK.h>
#import "TradPlusCSJSDKLoader.h"
#import "TPCSJAdapterBaseInfo.h"

@interface TradPlusCSJBannerAdapter ()<BUNativeExpressBannerViewDelegate,TPSDKLoaderDelegate>

@property (nonatomic, strong) BUNativeExpressBannerView *bannerView;
@property (nonatomic,copy)NSString *placementId;
@property (nonatomic,copy)NSString *appId;
@property (nonatomic,assign) BOOL isC2SBidding;
@property (nonatomic,assign) BOOL didWin;
@property (nonatomic,assign) NSInteger ecpm;
@end

@implementation TradPlusCSJBannerAdapter

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
    else if([event isEqualToString:@"C2SLoss"])
    {
        [self sendC2SLoss:config];
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
        MSLogTrace(@"CSJ init Config Error %@",config);
        return;
    }
    if([TradPlusCSJSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusCSJSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusCSJSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_CSJAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [TradPlusCSJSDKLoader getSDKVersion];
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_CSJAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
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
    if([TradPlusCSJSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusCSJSDKLoader sharedInstance].initSource = initSource;
    }
    [[TradPlusCSJSDKLoader sharedInstance] setAllowModifyAudioSessionSettingWithExtraInfo:self.waterfallItem.extraInfoDictionary];
    [[TradPlusCSJSDKLoader sharedInstance] initWithAppID:self.appId delegate:self];
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

- (void)loadAd
{
    [[TradPlusCSJSDKLoader sharedInstance] setPersonalizedAd];
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
    self.bannerView = [[BUNativeExpressBannerView alloc] initWithSlotID:self.placementId rootViewController:self.waterfallItem.bannerRootViewController adSize:size];
    self.bannerView.delegate = self;
    CGRect rect = CGRectZero;
    rect.size = size;
    self.bannerView.frame = rect;
    [self.bannerView loadAdData];
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
                height = 400;
            break;
        }
        case 3:
        {
            if(width == 0)
                width = 600;
            if(height == 0)
                height = 500;
            break;
        }
        case 4:
        {
            if(width == 0)
                width = 600;
            if(height == 0)
                height = 260;
            break;
        }
        case 5:
        {
            if(width == 0)
                width = 600;
            if(height == 0)
                height = 90;
            break;
        }
        case 6:
        {
            if(width == 0)
                width = 600;
            if(height == 0)
                height = 150;
            break;
        }
        case 7:
        {
            if(width == 0)
                width = 640;
            if(height == 0)
                height = 100;
            break;
        }
        case 8:
        {
            if(width == 0)
                width = 690;
            if(height == 0)
                height = 388;
            break;
        }
        default:
        {
            if(width == 0)
                width = 600;
            if(height == 0)
                height = 300;
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
        [self sendC2SWin];
        [self AdLoadFinsh];
    }
    else
    {
        NSError *loadError = [NSError errorWithDomain:@"CSJ.banner" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S Banner not ready"}];
        [self AdLoadFailWithError:loadError];
    }
}

- (void)finishC2SBidding
{
    NSString *version = [TradPlusCSJSDKLoader getSDKVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSString *ecpm = [NSString stringWithFormat:@"%@",@(self.ecpm)];
    NSDictionary *dic = @{@"ecpm":ecpm,@"version":version};
    [self ADLoadExtraCallbackWithEvent:@"C2SBiddingFinish" info:dic];
}

- (void)failC2SBiddingWithErrorStr:(NSString *)errorStr
{
    NSDictionary *dic = @{@"error":errorStr};
    [self ADLoadExtraCallbackWithEvent:@"C2SBiddingFail" info:dic];
}

- (void)sendC2SWin
{
    if(!self.isC2SBidding)
    {
        return;
    }
    self.didWin = YES;
    [self.bannerView win:@(self.ecpm)];
}

- (void)sendC2SLoss:(NSDictionary *)config
{
    if(self.didWin)
    {
        return;
    }
    NSString *topPirce = config[@"topPirce"];
    [self.bannerView loss:@([topPirce integerValue]) lossReason:@"102" winBidder:nil];
}

#pragma mark- BUNativeExpressBannerViewDelegate
- (void)nativeExpressBannerAdViewDidLoad:(BUNativeExpressBannerView *)bannerAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    self.isAdReady = YES;
    if(self.isC2SBidding)
    {
        if(![bannerAdView.mediaExt valueForKey:@"price"])
        {
            NSString *errorStr = @"C2S Bidding Fail.[竞价失败，请确认是否已开启穿山甲竞价功能]";
            MSLogInfo(@"%@", errorStr);
            [self failC2SBiddingWithErrorStr:errorStr];
            return;
        }
        self.ecpm = [[bannerAdView.mediaExt valueForKey:@"price"] integerValue];
        [self finishC2SBidding];
    }
    else
    {
        [self AdLoadFinsh];
    }
}

- (void)nativeExpressBannerAdView:(BUNativeExpressBannerView *)bannerAdView didLoadFailWithError:(NSError *_Nullable)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
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


- (void)nativeExpressBannerAdViewRenderSuccess:(BUNativeExpressBannerView *)bannerAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeExpressBannerAdViewRenderFail:(BUNativeExpressBannerView *)bannerAdView error:(NSError * __nullable)error
{
    MSLogTrace(@"%s %@", __PRETTY_FUNCTION__,error);
    [self AdShowFailWithError:error];
}


- (void)nativeExpressBannerAdViewWillBecomVisible:(BUNativeExpressBannerView *)bannerAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)nativeExpressBannerAdViewDidClick:(BUNativeExpressBannerView *)bannerAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)nativeExpressBannerAdViewDidRemoved:(BUNativeExpressBannerView *)bannerAdView
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}
@end
