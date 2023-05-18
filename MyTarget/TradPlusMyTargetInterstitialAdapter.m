#import "TradPlusMyTargetInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <MyTargetSDK/MyTargetSDK.h>
#import "TPMyTargetAdapterBaseInfo.h"
#import "TradPlusMyTargetSDKSetting.h"

@interface TradPlusMyTargetInterstitialAdapter ()<MTRGInterstitialAdDelegate>

@property (nonatomic, strong) MTRGInterstitialAd *interstitialAd;
@end

@implementation TradPlusMyTargetInterstitialAdapter

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
    NSDictionary *dic = @{@"version":TP_MyTargetAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [MTRGVersion currentVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_MyTargetAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *slotId = item.config[@"slot_id"];
    if(slotId == nil)
    {
        [self AdConfigError];
        return;;
    }
    
    [TradPlusMyTargetSDKSetting setPrivacy];
    
    self.interstitialAd = [MTRGInterstitialAd interstitialAdWithSlotId:[slotId intValue]];
    self.interstitialAd.delegate = self;
    
    NSString *bidToken = nil;
    if(item.adsourceplacement != nil)
    {
        bidToken = item.adsourceplacement.adm;
    }
    if(bidToken == nil)
    {
        [self.interstitialAd load];
    }
    else
    {
        [self.interstitialAd loadFromBid:bidToken];
    }
}


- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.interstitialAd showWithController:rootViewController];
}

- (BOOL)isReady
{
    return self.isAdReady;
}

- (id)getCustomObject
{
    return self.interstitialAd;
}

#pragma mark - MTRGInterstitialAdDelegate
- (void)onLoadWithInterstitialAd:(MTRGInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdLoadFinsh];
}

- (void)onNoAdWithReason:(NSString *)reason interstitialAd:(MTRGInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSError *error = [NSError errorWithDomain:@"MyTarget No Ad" code:400 userInfo:@{NSLocalizedDescriptionKey:reason}];
    [self AdLoadFailWithError:error];
}

- (void)onClickWithInterstitialAd:(MTRGInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)onCloseWithInterstitialAd:(MTRGInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClose];
}

- (void)onDisplayWithInterstitialAd:(MTRGInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)onVideoCompleteWithInterstitialAd:(MTRGInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}

- (void)onLeaveApplicationWithInterstitialAd:(MTRGInterstitialAd *)interstitialAd
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}
@end
