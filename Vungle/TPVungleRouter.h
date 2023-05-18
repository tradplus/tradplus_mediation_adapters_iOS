#import <VungleSDK/VungleSDK.h>
#import <UIKit/UIKit.h>

@protocol TPVungleRouterDelegate;
@class TPVungleInstanceMediationSettings;

@interface TPVungleRouter : NSObject <VungleSDKDelegate>

@property (nonatomic, weak) id<TPVungleRouterDelegate> delegate;

+ (TPVungleRouter *)sharedRouter;

- (BOOL)isAdAvailableForPlacementId:(NSString *)placementId bidToken:(NSString *)bidToken;

- (void)requestRewardedVideoAdWithPlacementId:(NSString *)placementId delegate:(id<TPVungleRouterDelegate>)delegate bidToken:(NSString *)bidToken;

- (void)presentRewardedVideoAdFromViewController:(UIViewController *)viewController customerId:(NSString *)customerId settings:(TPVungleInstanceMediationSettings *)settings forPlacementId:(NSString *)placementId bidToken:(NSString *)bidToken;

- (void)requestInterstitialAdWithPlacementId:(NSString *)placementId delegate:(id<TPVungleRouterDelegate>)delegate bidToken:(NSString *)bidToken;

- (void)presentInterstitialAdFromViewController:(UIViewController *)viewController options:(NSDictionary *)options forPlacementId:(NSString *)placementId bidToken:(NSString *)bidToken;


- (void)requestBannerAdWithPlacementId:(NSString *)placementId
                                  size:(VungleAdSize)size
                              delegate:(id<TPVungleRouterDelegate>)delegate
                                  bidToken:(NSString *)bidToken;

- (void)requestMRECAdWithPlacementId:(NSString *)placementId delegate:(id<TPVungleRouterDelegate>)delegate bidToken:(NSString *)bidToken;

- (BOOL)addAdViewToView:(UIView *)publisherView placementID:(NSString *)placementID bidToken:(NSString *)bidToken error:(NSError **)error;

- (void)addPlacementId:(NSString *)placementId delegate:(id<TPVungleRouterDelegate>)delegate;

- (void)clearDelegateForPlacementId:(NSString *)placementId;

- (void)finishedDisplayingAd:(NSString *)placementId;

- (BOOL)hasPlacementIdAd:(NSString *)placementId;
@end

@protocol TPVungleRouterDelegate <NSObject>

- (void)vungleAdDidLoad;
- (void)vungleAdWillAppear;
- (void)vungleAdDidShow;
- (void)vungleAdWillDisappear;
- (void)vungleAdWasTapped;
- (void)vungleAdDidFailToPlay:(NSError *)error;
- (void)vungleAdDidFailToLoad:(NSError *)error;
@optional

- (void)vungleAdShouldRewardUser;

@end
