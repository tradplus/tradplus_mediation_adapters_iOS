#import "TPVungleRouter.h"
#import <TradPlusAds/MSLogging.h>
#import "TPVungleInstanceMediationSettings.h"
#import <VungleSDK/VungleSDKHeaderBidding.h>

@interface TPVungleRouter ()<VungleSDKHBDelegate>

@property (nonatomic, copy) NSString *vungleAppID;
@property (nonatomic, assign) BOOL isAdPlaying;

@property (nonatomic, strong) NSMutableDictionary *delegatesDic;

@end

@implementation TPVungleRouter

- (instancetype)init
{
    if (self = [super init])
    {
        self.delegatesDic = [NSMutableDictionary dictionary];
        self.isAdPlaying = NO;
        [self setDelegates];
    }
    return self;
}

- (void)setDelegates
{
    [[VungleSDK sharedSDK] setDelegate:self];
    [VungleSDK sharedSDK].sdkHBDelegate = self;
}

+ (TPVungleRouter *)sharedRouter
{
    static TPVungleRouter * sharedRouter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedRouter = [[TPVungleRouter alloc] init];
    });
    return sharedRouter;
}

- (BOOL)hasPlacementIdAd:(NSString *)placementId
{
    return ([self.delegatesDic valueForKey:placementId] != nil);
}

- (void)requestAdWithCustomPlacementId:(NSString *)placementId delegate:(id<TPVungleRouterDelegate>)delegate bidToken:(NSString *)bidToken
{
    [self.delegatesDic setObject:delegate forKey:placementId];
    if ([self isAdAvailableForPlacementId:placementId bidToken:bidToken])
    {
        MSLogTrace(@"Vungle: Placement ID is already cached. Trigger DidLoadAd delegate directly: %@", placementId);
        [delegate vungleAdDidLoad];
        return;
    }
    [self setDelegates];
    NSError *error = nil;
    if(bidToken != nil && bidToken.length > 0)
    {
        MSLogTrace(@"Vungle bid: Start to load an ad for Placement ID :%@", placementId);
        if(![[VungleSDK sharedSDK] loadPlacementWithID:placementId adMarkup:bidToken error:&error])
        {
            if(error == nil)
            {
                error = [NSError errorWithDomain:@"Vungle" code:1001 userInfo:@{NSLocalizedDescriptionKey: @"load fail"}];
            }
            [delegate vungleAdDidFailToLoad:error];
            MSLogTrace(@"Vungle: Unable to load an ad for Placement ID :%@, Error %@", placementId, error);
        }
    }
    else
    {
        MSLogTrace(@"Vungle: Start to load an ad for Placement ID :%@", placementId);
        if(![[VungleSDK sharedSDK] loadPlacementWithID:placementId error:&error])
        {
            if(error == nil)
            {
                error = [NSError errorWithDomain:@"Vungle" code:1001 userInfo:@{NSLocalizedDescriptionKey: @"load fail"}];
            }
            [delegate vungleAdDidFailToLoad:error];
            MSLogTrace(@"Vungle: Unable to load an ad for Placement ID :%@, Error %@", placementId, error);
        }
        
    }
}

- (BOOL)isAdAvailableForPlacementId:(NSString *)placementId bidToken:(NSString *)bidToken
{
    if(bidToken == nil)
    {
        return [[VungleSDK sharedSDK] isAdCachedForPlacementID:placementId];
    }
    else
    {
        return [[VungleSDK sharedSDK] isAdCachedForPlacementID:placementId adMarkup:bidToken];
    }
}

#pragma mark - Interstitial

- (void)requestInterstitialAdWithPlacementId:(NSString *)placementId delegate:(id<TPVungleRouterDelegate>)delegate bidToken:(NSString *)bidToken
{
    [self requestAdWithCustomPlacementId:placementId delegate:delegate bidToken:bidToken];
}

- (void)presentInterstitialAdFromViewController:(UIViewController *)viewController options:(NSDictionary *)options forPlacementId:(NSString *)placementId bidToken:(NSString *)bidToken
{
    if (!self.isAdPlaying && [self isAdAvailableForPlacementId:placementId bidToken:bidToken])
    {
        [self setDelegates];
        self.isAdPlaying = YES;
        NSError *error = nil;
        if(bidToken == nil)
        {
            [[VungleSDK sharedSDK] playAd:viewController options:options placementID:placementId error:&error];
        }
        else
        {
            [[VungleSDK sharedSDK] playAd:viewController options:options placementID:placementId adMarkup:bidToken error:&error];
        }
        if (error != nil)
        {
            [[self.delegatesDic objectForKey:placementId] vungleAdDidFailToPlay:error];
            self.isAdPlaying = NO;
        }
    }
    else
    {
        NSError *error = [NSError errorWithDomain:@"Vungle" code:1002 userInfo:@{NSLocalizedDescriptionKey: @"play fail"}];
        [[self.delegatesDic objectForKey:placementId] vungleAdDidFailToPlay:error];
    }
}

#pragma mark - RewardedVideo

- (void)requestRewardedVideoAdWithPlacementId:(NSString *)placementId delegate:(id<TPVungleRouterDelegate>)delegate bidToken:(NSString *)bidToken
{
    [self requestAdWithCustomPlacementId:placementId delegate:delegate bidToken:bidToken];
}

- (void)presentRewardedVideoAdFromViewController:(UIViewController *)viewController customerId:(NSString *)customerId settings:(TPVungleInstanceMediationSettings *)settings forPlacementId:(NSString *)placementId bidToken:(NSString *)bidToken
{
    if (!self.isAdPlaying && [self isAdAvailableForPlacementId:placementId bidToken:bidToken])
    {
        [self setDelegates];
        self.isAdPlaying = YES;
        NSMutableDictionary *options = [NSMutableDictionary dictionary];
        if (customerId != nil && customerId.length > 0) {
            options[VunglePlayAdOptionKeyUser] = customerId;
            MSLogTrace(@"Vungle ServerSideVerification ->userID: %@", customerId);
        } else if (settings && settings.userIdentifier.length > 0) {
            options[VunglePlayAdOptionKeyUser] = settings.userIdentifier;
        }
        if (settings.flexViewAutoDismissSeconds > 0)
            options[VunglePlayAdOptionKeyFlexViewAutoDismissSeconds] = @(settings.flexViewAutoDismissSeconds);
        NSError *error = nil;
        if(bidToken == nil)
        {
            [[VungleSDK sharedSDK] playAd:viewController options:options placementID:placementId error:&error];
        }
        else
        {
            [[VungleSDK sharedSDK] playAd:viewController options:options placementID:placementId adMarkup:bidToken error:&error];
        }
        if (error != nil)
        {
            [[self.delegatesDic objectForKey:placementId] vungleAdDidFailToPlay:error];
            self.isAdPlaying = NO;
        }
    }
    else
    {
        NSError *error = [NSError errorWithDomain:@"Vungle" code:1002 userInfo:@{NSLocalizedDescriptionKey: @"play fail"}];
        [[self.delegatesDic objectForKey:placementId] vungleAdDidFailToPlay:error];
    }
}

#pragma mark - MREC
- (void)requestMRECAdWithPlacementId:(NSString *)placementId delegate:(id<TPVungleRouterDelegate>)delegate bidToken:(NSString *)bidToken
{
    [VungleSDK sharedSDK].muted = true;
    [self requestAdWithCustomPlacementId:placementId delegate:delegate bidToken:bidToken];
}

- (void)requestBannerAdWithPlacementId:(NSString *)placementId
                                  size:(VungleAdSize)size
                              delegate:(id<TPVungleRouterDelegate>)delegate
                                  bidToken:(NSString *)bidToken
{
    [self requestBannerAdWithPlacementID:placementId size:size delegate:delegate bidToken:bidToken];
}

- (BOOL)isAdAvailableForPlacementId:(NSString *)placementId withSize:(VungleAdSize)size bidToken:(NSString *)bidToken
{
    if(bidToken == nil)
    {
        return [[VungleSDK sharedSDK] isAdCachedForPlacementID:placementId withSize:size];
    }
    else
    {
        return [[VungleSDK sharedSDK] isAdCachedForPlacementID:placementId adMarkup:bidToken withSize:size];
    }
}

- (BOOL)loadPlacementWithID:(NSString *)placementID withSize:(VungleAdSize)size error:(NSError **)error bidToken:(NSString *)bidToken
{
    [self setDelegates];
    if(bidToken == nil)
    {
        return [[VungleSDK sharedSDK] loadPlacementWithID:placementID withSize:size error:error];
    }
    else
    {
        return [[VungleSDK sharedSDK] loadPlacementWithID:placementID adMarkup:bidToken withSize:size error:error];
    }
}

- (void)requestBannerAdWithPlacementID:(NSString *)placementID
                                  size:(VungleAdSize)size
                              delegate:(id<TPVungleRouterDelegate>)delegate
                              bidToken:(NSString *)bidToken
{
    [self.delegatesDic setObject:delegate forKey:placementID];
    if ([self isAdAvailableForPlacementId:placementID withSize:size bidToken:bidToken])
    {
        MSLogInfo(@"Vungle: Banner ad already cached for Placement ID :%@", placementID);
        [delegate vungleAdDidLoad];
    }
    else
    {
        NSError *error = nil;
        if ([self loadPlacementWithID:placementID withSize:size error:&error bidToken:bidToken])
        {
            MSLogInfo(@"Vungle: Start to load an ad for Placement ID :%@", placementID);
        }
        else
        {
            MSLogInfo(@"Vungle: loadPlacement error %@",error);
            NSError *error = [NSError errorWithDomain:@"Vungle" code:1001 userInfo:@{NSLocalizedDescriptionKey: @"load fail"}];
            [delegate vungleAdDidFailToLoad:error];
        }
    }
}

- (void)clearDelegateForPlacementId:(NSString *)placementId
{
    MSLogTrace(@"%s->%@", __PRETTY_FUNCTION__, placementId);
    if (placementId != nil) {
        [self.delegatesDic removeObjectForKey:placementId];
    }
}

- (BOOL)addAdViewToView:(UIView *)publisherView placementID:(nullable NSString *)placementID bidToken:(NSString *)bidToken error:(NSError **)error;
{
    [self setDelegates];
    if(bidToken == nil)
    {
        return [[VungleSDK sharedSDK] addAdViewToView:publisherView withOptions:@{} placementID:placementID error:error];
    }
    else
    {
        return [[VungleSDK sharedSDK] addAdViewToView:publisherView withOptions:@{} placementID:placementID adMarkup:bidToken error:error];
    }
}

- (void)addPlacementId:(NSString *)placementId delegate:(id<TPVungleRouterDelegate>)delegate
{
    if(placementId != nil && delegate != nil)
    {
        [self.delegatesDic setObject:delegate forKey:placementId];
    }
}

- (void)finishedDisplayingAd:(NSString *)placementId
{
    [[VungleSDK sharedSDK] finishDisplayingAd:placementId];
}

#pragma mark - VungleSDKDelegate Methods

- (void)vungleSDKDidInitialize
{
    
}

- (void)vungleAdPlayabilityUpdate:(BOOL)isAdPlayable placementID:(NSString *)placementID error:(NSError *)error
{
    id<TPVungleRouterDelegate>delegate = [self.delegatesDic objectForKey:placementID];
    if (isAdPlayable)
    {
        if(delegate && [delegate respondsToSelector:@selector(vungleAdDidLoad)])
        {
            [delegate vungleAdDidLoad];
        }
    }
    else {
        NSError *playabilityError;
        if (error)
        {
            MSLogTrace(@"Vungle: Ad playability update returned error for Placement ID: %@, Error: %@", placementID, error.localizedDescription);
            playabilityError = error;
        }
        if (!self.isAdPlaying)
        {
            if(delegate && [delegate respondsToSelector:@selector(vungleAdDidFailToLoad:)])
            {
                [delegate vungleAdDidFailToLoad:playabilityError];
            }
        }
    }
}

- (void)vungleDidCloseAdForPlacementID:(nonnull NSString *)placementID
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    id<TPVungleRouterDelegate>delegate = [self.delegatesDic objectForKey:placementID];
    if(delegate && [delegate respondsToSelector:@selector(vungleAdWillDisappear)])
    {
        [delegate vungleAdWillDisappear];
    }
    self.isAdPlaying = NO;
}

- (void)vungleRewardUserForPlacementID:(nullable NSString *)placementID
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    id<TPVungleRouterDelegate>delegate = [self.delegatesDic objectForKey:placementID];
    if (delegate && [delegate respondsToSelector:@selector(vungleAdShouldRewardUser)])
    {
        [delegate vungleAdShouldRewardUser];
    }
}

- (void)vungleAdViewedForPlacement:(NSString *)placementID
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)vungleWillShowAdForPlacementID:(nullable NSString *)placementID
{
    id<TPVungleRouterDelegate>delegate = [self.delegatesDic objectForKey:placementID];
    if(delegate && [delegate respondsToSelector:@selector(vungleAdWillAppear)])
    {
        [delegate vungleAdWillAppear];
    }
}

- (void)vungleDidShowAdForPlacementID:(nullable NSString *)placementID
{
    id<TPVungleRouterDelegate>delegate = [self.delegatesDic objectForKey:placementID];
    if(delegate && [delegate respondsToSelector:@selector(vungleAdDidShow)])
    {
        [delegate vungleAdDidShow];
    }
}

- (void)vungleTrackClickForPlacementID:(nullable NSString *)placementID
{
    id<TPVungleRouterDelegate>delegate = [self.delegatesDic objectForKey:placementID];
    if(delegate && [delegate respondsToSelector:@selector(vungleAdWasTapped)])
    {
        [delegate vungleAdWasTapped];
    }
}


#pragma mark- VungleSDKHBDelegate

- (void)vungleAdPlayabilityUpdate:(BOOL)isAdPlayable placementID:(nullable NSString *)placementID adMarkup:(nullable NSString *)adMarkup error:(nullable NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self vungleAdPlayabilityUpdate:isAdPlayable placementID:placementID error:error];
}

- (void)vungleWillShowAdForPlacementID:(nullable NSString *)placementID adMarkup:(nullable NSString *)adMarkup
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self vungleWillShowAdForPlacementID:placementID];
}

- (void)vungleDidShowAdForPlacementID:(nullable NSString *)placementID adMarkup:(nullable NSString *)adMarkup
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self vungleDidShowAdForPlacementID:placementID];
}


- (void)vungleTrackClickForPlacementID:(nullable NSString *)placementID adMarkup:(nullable NSString *)adMarkup
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self vungleTrackClickForPlacementID:placementID];
}

- (void)vungleDidCloseAdForPlacementID:(nullable NSString *)placementID adMarkup:(nullable NSString *)adMarkup
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self vungleDidCloseAdForPlacementID:placementID];
}

- (void)vungleRewardUserForPlacementID:(nullable NSString *)placementID adMarkup:(nullable NSString *)adMarkup
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self vungleRewardUserForPlacementID:placementID];
}

@end
