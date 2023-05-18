#import "TradPlusSuperAwesomeRewardedAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TradPlusSuperAwesomeSDKLoader.h"
#import "TPSuperAwesomeAdapterBaseInfo.h"
@import SuperAwesome;

@interface TradPlusSuperAwesomeRewardedAdapter ()<TPSDKLoaderDelegate>
@property (nonatomic, assign) int placementId;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL alwaysReward;
@property (nonatomic, assign) BOOL videoMute;
@end

@implementation TradPlusSuperAwesomeRewardedAdapter

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
    if([TradPlusSuperAwesomeSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusSuperAwesomeSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusSuperAwesomeSDKLoader sharedInstance] initWithDelegate:nil];
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_SuperAwesomeAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = @"-";
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_SuperAwesomeAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    self.placementId = [item.config[@"placementId"] intValue];
    self.videoMute = item.video_mute == 2 ? NO:YES;
    if (self.placementId == 0)
    {
        [self AdConfigError];
        return;
    }
    if([item.extraInfoDictionary valueForKey:@"always_reward"])
    {
        self.alwaysReward = [item.extraInfoDictionary[@"always_reward"] integerValue] == 1;
    }
    [[TradPlusSuperAwesomeSDKLoader sharedInstance] initWithDelegate:self];
}


- (void)loadAd
{
    [SAVideoAd setMuteOnStart:self.videoMute];
    [SAVideoAd enableBumperPage];
    [SAVideoAd enableParentalGate];
    [SAVideoAd disableCloseButton];
    [SAVideoAd disableCloseAtEnd];
    [SAVideoAd disableSmallClickButton];
    [SAVideoAd setCallback:^(NSInteger placementId, SAEvent event) {
        
        MSLogTrace(@"SUPER-AWESOME: Video Ad %ld - Event %ld", (long)placementId, (long)event);
        switch (event) {
            case SAEventAdLoaded:
            case SAEventAdAlreadyLoaded:
                [self AdLoadFinsh];
                break;
            case SAEventAdEmpty:
                [self AdLoadFailWithError:[NSError errorWithDomain:@"super awesome" code:1 userInfo:@{NSLocalizedDescriptionKey:@"no fill"}]];
                break;
            case SAEventAdFailedToLoad:
                [self AdLoadFailWithError:nil];
                break;
            case SAEventAdShown:
                [self AdShow];
                [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
                break;
            case SAEventAdFailedToShow:
                [self AdShowFailWithError:nil];
                break;
            case SAEventAdClicked:
                [self AdClick];
                break;
            case SAEventAdEnded:
                self.shouldReward = YES;
                break;
            case SAEventAdClosed:
                [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
                if (self.shouldReward || self.alwaysReward)
                    [self AdRewardedWithInfo:nil];
                [self AdClose];
                break;

            default:
                break;
        }
    }];
    
    [SAVideoAd load: self.placementId];
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

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [SAVideoAd play:self.placementId fromVC:rootViewController];
}

- (id)getCustomObject
{
    return nil;
}

- (BOOL)isReady
{
    return [SAVideoAd hasAdAvailable:self.placementId];
}

@end
