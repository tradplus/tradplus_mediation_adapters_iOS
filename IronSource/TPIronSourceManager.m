#import "TPIronSourceManager.h"
#import <TradPlusAds/MSLogging.h>

@interface TPIronSourceManager ()

@property(nonatomic)
NSMapTable<NSString *, id<IronSourceRewardedVideoDelegate>> *rewardedAdapterDelegates;

@property(nonatomic)
NSMapTable<NSString *, id<IronSourceInterstitialDelegate>> *interstitialAdapterDelegates;

@end

@implementation TPIronSourceManager

+ (instancetype)sharedManager {
    static TPIronSourceManager *sharedManager = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    if (self = [super init]) {
        self.rewardedAdapterDelegates =
        [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory
                              valueOptions:NSPointerFunctionsWeakMemory];
        self.interstitialAdapterDelegates =
        [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory
                              valueOptions:NSPointerFunctionsWeakMemory];
        [IronSource setMediationType:[NSString stringWithFormat:@"%@%@SDK%@",
                                      @"TradPlus",@"310", [self getTradPlusSdkVersion]]];
        [self setDelegates];
    }
    return self;
}

- (NSString *)getTradPlusSdkVersion
{
    NSString * version = @"";
    NSString *sdkVersion = MS_SDK_VERSION;
    @try{
        version = [sdkVersion stringByReplacingOccurrencesOfString:@"." withString:@""];
    }
    @catch (NSException *exception){
        MSLogTrace(@"Unable to parse TradPlus SDK version");
        version = @"";
    }
    return version;
}

- (void)setDelegates
{
    [IronSource setISDemandOnlyInterstitialDelegate:self];
    [IronSource setISDemandOnlyRewardedVideoDelegate:self];
}

- (void)loadRewardedAdWithDelegate:
(id<IronSourceRewardedVideoDelegate>)delegate instanceID:(NSString *)instanceID {
    id<IronSourceRewardedVideoDelegate> adapterDelegate = delegate;
    
    if (adapterDelegate == nil)
    {
        MSLogDebug(@"loadRewardedAdWithDelegate adapterDelegate is null");
        return;
    }
    [self setDelegates];
    [self addRewardedDelegate:adapterDelegate forInstanceID:instanceID];
    MSLogDebug(@"TPIronSourceManager - load Rewarded Video called for instance Id %@", instanceID);
    [IronSource loadISDemandOnlyRewardedVideo:instanceID];
}

- (void)presentRewardedAdFromViewController:(nonnull UIViewController *)viewController
                                 instanceID:(NSString *)instanceID {
    MSLogDebug(@"TPIronSourceManager - show Rewarded Video called for instance Id %@", instanceID);
    [self setDelegates];
    [IronSource showISDemandOnlyRewardedVideo:viewController instanceId:instanceID];
}

- (void)requestInterstitialAdWithDelegate:
(id<IronSourceInterstitialDelegate>)delegate
                               instanceID:(NSString *)instanceID{
    id<IronSourceInterstitialDelegate> adapterDelegate = delegate;
    
    if (adapterDelegate == nil) {
        MSLogDebug(@"TPIronSourceManager - requestInterstitialAdWithDelegate adapterDelegate is null");
        return;
    }
    [self setDelegates];
    [self addInterstitialDelegate:adapterDelegate forInstanceID:instanceID];
    MSLogDebug(@"TPIronSourceManager - load Interstitial called for instance Id %@", instanceID);
    [IronSource loadISDemandOnlyInterstitial:instanceID];
}

- (void)presentInterstitialAdFromViewController:(nonnull UIViewController *)viewController
                                     instanceID: (NSString *) instanceID
{
    [self setDelegates];
    [IronSource showISDemandOnlyInterstitial:viewController instanceId:instanceID];
}

#pragma mark ISDemandOnlyRewardedDelegate

- (void)rewardedVideoAdRewarded:(NSString *)instanceId {
    MSLogDebug(@"TPIronSourceManager rewarded user for instanceId %@", instanceId);

    id<IronSourceRewardedVideoDelegate> delegate =
    [self getRewardedDelegateForInstanceID:instanceId];

    if (delegate) {
        [delegate rewardedVideoAdRewarded:instanceId];
    } else {
        MSLogDebug(@"TPIronSourceManager - rewardedVideoAdRewarded adapterDelegate is null");
    }
}

- (void)rewardedVideoDidFailToShowWithError:(NSError *)error instanceId:(NSString *)instanceId {
    MSLogDebug(@"TPIronSourceManager got rewardedVideoDidFailToShowWithError for instanceId %@ with error: %@", instanceId, error);
    id<IronSourceRewardedVideoDelegate> delegate =
    [self getRewardedDelegateForInstanceID:instanceId];

    if (delegate) {
        [delegate rewardedVideoDidFailToShowWithError:error instanceId:instanceId];
        [self removeRewardedDelegateForInstanceID:instanceId];
    } else {
        MSLogDebug(@"TPIronSourceManager - rewardedVideoDidFailToShowWithError adapterDelegate is null");
    }
}

- (void)rewardedVideoDidOpen:(NSString *)instanceId {
    MSLogDebug(@"TPIronSourceManager got rewardedVideoDidOpen for instanceId %@", instanceId);
    id<IronSourceRewardedVideoDelegate> delegate =
    [self getRewardedDelegateForInstanceID:instanceId];

    if (delegate) {
        [delegate rewardedVideoDidOpen:instanceId];
    } else {
        MSLogDebug(@"TPIronSourceManager - rewardedVideoDidOpen adapterDelegate is null");
    }
}

- (void)rewardedVideoDidClose:(NSString *)instanceId {
    MSLogDebug(@"TPIronSourceManager got rewardedVideoDidClose for instanceId %@", instanceId);
    id<IronSourceRewardedVideoDelegate> delegate =
    [self getRewardedDelegateForInstanceID:instanceId];

    if (delegate) {
        [delegate rewardedVideoDidClose:instanceId];
        [self removeRewardedDelegateForInstanceID:instanceId];
    } else {
        MSLogDebug(@"TPIronSourceManager - rewardedVideoDidClose adapterDelegate is null");
    }
}

- (void)rewardedVideoDidClick:(NSString *)instanceId {
    MSLogDebug(@"TPIronSourceManager got rewardedVideoDidClick for instanceId %@", instanceId);
    id<IronSourceRewardedVideoDelegate> delegate =
    [self getRewardedDelegateForInstanceID:instanceId];

    if (delegate) {
        [delegate rewardedVideoDidClick:instanceId];
    } else {
        MSLogDebug(@"TPIronSourceManager - rewardedVideoDidClick adapterDelegate is null");
    }
}

- (void)rewardedVideoDidLoad:(NSString *)instanceId{
    MSLogDebug(@"TPIronSourceManager got rewardedVideoDidLoad for instanceId %@", instanceId);
    id<IronSourceRewardedVideoDelegate> delegate = [self getRewardedDelegateForInstanceID:instanceId];
    if(delegate){
        [delegate rewardedVideoDidLoad:instanceId];
    } else {
        MSLogDebug(@"TPIronSourceManager - rewardedVideoDidLoad adapterDelegate is null");
    }
}

- (void)rewardedVideoDidFailToLoadWithError:(NSError *)error instanceId:(NSString *)instanceId{
    MSLogDebug(@"TPIronSourceManager got rewardedVideoDidFailToLoadWithError for instanceId %@ with error: %@", instanceId, error);
    id<IronSourceRewardedVideoDelegate> delegate = [self getRewardedDelegateForInstanceID:instanceId];
    if(delegate){
        [delegate rewardedVideoDidFailToLoadWithError:error instanceId:instanceId];
        [self removeRewardedDelegateForInstanceID:instanceId];
    } else {
        MSLogDebug(@"TPIronSourceManager - rewardedVideoDidFailToLoadWithError adapterDelegate is null");
    }
}

#pragma mark ISDemandOnlyInterstitialDelegate

- (void)interstitialDidLoad:(NSString *)instanceId {
    MSLogDebug(@"TPIronSourceManager got interstitialDidLoad for instanceId %@", instanceId);
    id<IronSourceInterstitialDelegate> delegate =
    [self getInterstitialDelegateForInstanceID:instanceId];
    if (delegate) {
        [delegate interstitialDidLoad:instanceId];
    } else {
        MSLogDebug(@"TPIronSourceManager - didClickInterstitial adapterDelegate is null");
    }
}

- (void)interstitialDidFailToLoadWithError:(NSError *)error instanceId:(NSString *)instanceId {
    MSLogDebug(@"TPIronSourceManager got interstitialDidFailToLoadWithError for instanceId %@ with error: %@", instanceId, error);
    id<IronSourceInterstitialDelegate> delegate =
    [self getInterstitialDelegateForInstanceID:instanceId];
    if (delegate) {
        [delegate interstitialDidFailToLoadWithError:error instanceId:instanceId];
        [self removeInterstitialDelegateForInstanceID:instanceId];
    } else {
        MSLogDebug(@"TPIronSourceManager - interstitialDidFailToLoadWithError adapterDelegate is null");
    }
}

- (void)interstitialDidOpen:(NSString *)instanceId {
    MSLogDebug(@"TPIronSourceManager got interstitialDidOpen for instanceId %@", instanceId);
    id<IronSourceInterstitialDelegate> delegate =
    [self getInterstitialDelegateForInstanceID:instanceId];
    if (delegate) {
        [delegate interstitialDidOpen:instanceId];
    } else {
        MSLogDebug(@"TPIronSourceManager - interstitialDidOpen adapterDelegate is null");
    }
}

- (void)interstitialDidClose:(NSString *)instanceId {
    MSLogDebug(@"TPIronSourceManager got interstitialDidClose for instanceId %@", instanceId);
    id<IronSourceInterstitialDelegate> delegate =
    [self getInterstitialDelegateForInstanceID:instanceId];
    if (delegate) {
        [delegate interstitialDidClose:instanceId];
        [self removeInterstitialDelegateForInstanceID:instanceId];
    } else {
        MSLogDebug(@"TPIronSourceManager - interstitialDidClose adapterDelegate is null");
    }
}

- (void)interstitialDidFailToShowWithError:(NSError *)error instanceId:(NSString *)instanceId {
    MSLogDebug(@"TPIronSourceManager got didClickInterstitial for instanceId %@ with error: %@", instanceId, error);
    id<IronSourceInterstitialDelegate> delegate =
    [self getInterstitialDelegateForInstanceID:instanceId];
    if (delegate) {
        [delegate interstitialDidFailToShowWithError:error instanceId:instanceId];
        [self removeInterstitialDelegateForInstanceID:instanceId];
    } else {
        MSLogDebug(@"TPIronSourceManager - interstitialDidFailToShowWithError adapterDelegate is null");
    }
}

- (void)didClickInterstitial:(NSString *)instanceId {
    MSLogDebug(@"TPIronSourceManager got didClickInterstitial for instanceId %@", instanceId);
    id<IronSourceInterstitialDelegate> delegate =
    [self getInterstitialDelegateForInstanceID:instanceId];
    if (delegate) {
        [delegate didClickInterstitial:instanceId];
    } else {
        MSLogDebug(@"TPIronSourceManager - didClickInterstitial adapterDelegate is null");
    }
}

#pragma Map Utils methods

- (void)addRewardedDelegate:
(id<IronSourceRewardedVideoDelegate>)adapterDelegate
              forInstanceID:(NSString *)instanceID {
    @synchronized(self.rewardedAdapterDelegates) {
        [self.rewardedAdapterDelegates setObject:adapterDelegate forKey:instanceID];
    }
}

- (id<IronSourceRewardedVideoDelegate>)
getRewardedDelegateForInstanceID:(NSString *)instanceID {
    id<IronSourceRewardedVideoDelegate> delegate;
    @synchronized(self.rewardedAdapterDelegates) {
        delegate = [self.rewardedAdapterDelegates objectForKey:instanceID];
    }
    return delegate;
}

- (void)removeRewardedDelegateForInstanceID:(NSString *)InstanceID {
    @synchronized(self.rewardedAdapterDelegates) {
        [self.rewardedAdapterDelegates removeObjectForKey:InstanceID];
    }
}

- (void)addInterstitialDelegate:
(id<IronSourceInterstitialDelegate>)adapterDelegate
                  forInstanceID:(NSString *)instanceID {
    @synchronized(self.interstitialAdapterDelegates) {
        [self.interstitialAdapterDelegates setObject:adapterDelegate forKey:instanceID];
    }
}

- (id<IronSourceInterstitialDelegate>)
getInterstitialDelegateForInstanceID:(NSString *)instanceID {
    id<IronSourceInterstitialDelegate> delegate;
    @synchronized(self.interstitialAdapterDelegates) {
        delegate = [self.interstitialAdapterDelegates objectForKey:instanceID];
    }
    return delegate;
}

- (void)removeInterstitialDelegateForInstanceID:(NSString *)InstanceID {
    @synchronized(self.interstitialAdapterDelegates) {
        [self.interstitialAdapterDelegates removeObjectForKey:InstanceID];
    }
}

@end
