#import "TradPlusAppLovinSDKLoader.h"
#import <TradPlusAds/MSConsentManager.h>
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsEvent.h>
#import "TPAppLovinAdapterBaseInfo.h"

@interface TradPlusAppLovinSDKLoader()
{
    NSRecursiveLock *tableLock;
}

@property (nonatomic,assign)BOOL isIniting;
@property (nonatomic,strong)NSMutableArray *delegateArray;
@property (nonatomic,copy)NSString *serverSideUserID;
@end

@implementation TradPlusAppLovinSDKLoader

+(TradPlusAppLovinSDKLoader *)sharedInstance
{
    static TradPlusAppLovinSDKLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[TradPlusAppLovinSDKLoader alloc] init];
    });
    return loader;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.delegateArray = [[NSMutableArray alloc] init];
        tableLock = [[NSRecursiveLock alloc] init];
        self.initSource = -1;
        [self showAdapterInfo];
    }
    return self;
}

- (void)showAdapterInfo
{
    NSString *version = [ALSdk version];
    NSMutableString *adapterInfo = [[NSMutableString alloc] init];
    [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"AppLovin"];
    [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_AppLovinAdapter_Version];
    [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_AppLovinAdapter_PlatformSDK_Version];
    if(version != nil)
    {
        [adapterInfo appendFormat:@"Current version[当前sdk版本]:%@",version];
    }
    MSLogInfo(@"%@", adapterInfo);
}

- (void)setUserID:(NSString *)userID
{
    if(userID != nil && userID.length > 0)
    {
        self.serverSideUserID = userID;
        if(self.didInit || self.isIniting)
        {
            self.sdk.userIdentifier = userID;
            MSLogTrace(@"AppLovin ServerSideVerification ->userID: %@", self.serverSideUserID);
        }
    }
}

- (void)initWithAppID:(NSString *)appID
             delegate:(id <TPSDKLoaderDelegate>)delegate
{
    if(self.initSource == -1)
    {
        self.initSource = 3;
    }
    if(delegate != nil)
    {
        [tableLock lock];
        [self.delegateArray addObject:delegate];
        [tableLock unlock];
    }
    
    if(self.didInit)
    {
        [self initFinish];
        return;
    }
    
    if(self.isIniting)
    {
        return;
    }
    
    self.isIniting = YES;
    NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970]*1000;
    __weak typeof(self) weakSelf = self;
    tp_dispatch_main_sync_safe(^{
        weakSelf.sdk = [ALSdk sharedWithKey:appID];
    });
    if(self.sdk == nil)
    {
        NSString *errorStr = [[NSString alloc] initWithFormat:@"Init Error with AppId:%@",appID];
        NSError *error = [NSError errorWithDomain:@"AppLovin" code:1001 userInfo:@{NSLocalizedDescriptionKey: errorStr}];
        [self initFailWithError:error];
        return;
    }
    
    if ([[MSConsentManager sharedManager] isGDPRApplicable] == MSBoolYes)
    {
        BOOL canCollectPersonalInfo = [[MSConsentManager sharedManager] canCollectPersonalInfo];
        [ALPrivacySettings setHasUserConsent: canCollectPersonalInfo];
        MSLogTrace(@"AppLovin set gdpr %@",@(canCollectPersonalInfo));
    }
    
    int ccpa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCCPAStorageKey];
    if (ccpa != 0)
    {
        BOOL doNotSell = (ccpa == 1);
        [ALPrivacySettings setDoNotSell:doNotSell];
        MSLogTrace(@"AppLovin set ccpa  setDoNotSell %@",@(doNotSell));
    }
    
    int coppa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCOPPAStorageKey];
    if (coppa != 0)
    {
        BOOL isChild = (coppa == 2);
        [ALPrivacySettings setIsAgeRestrictedUser:isChild];
        MSLogTrace(@"AppLovin set coppa %@",@(isChild));
    }
    
    if(self.serverSideUserID != nil)
    {
        self.sdk.userIdentifier = self.serverSideUserID;
        MSLogTrace(@"AppLovin ServerSideVerification ->userID: %@", self.serverSideUserID);
    }
    [self.sdk initializeSdkWithCompletionHandler:^(ALSdkConfiguration * _Nonnull configuration) {
        weakSelf.isIniting = NO;
        weakSelf.didInit = YES;
        [weakSelf initFinish];
        NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970]*1000;
        NSInteger lt = endTime - startTime;
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
        dic[@"lt"] = [NSString stringWithFormat:@"%ld",(long)lt];
        dic[@"cf"] = [NSString stringWithFormat:@"%ld",(long)self.initSource];
        dic[@"as"] = [NSString stringWithFormat:@"%ld",(long)NETWORK_APPLOVIN];
        dic[@"asn"] = [MsCommon channelID2Name:NETWORK_APPLOVIN];
        dic[@"ec"] = @"1";
        [[MsEvent sharedInstance] uploadEvent:EV_INIT_NETWORK info:dic];
    }];
}

- (void)initFinish
{
    [tableLock lock];
    NSArray *array = [self.delegateArray copy];
    [self.delegateArray removeAllObjects];
    [tableLock unlock];
    for(id delegate in array)
    {
        [self finishWithDelegate:delegate];
    }
}

- (void)initFailWithError:(NSError *)error
{
    [tableLock lock];
    NSArray *array = [self.delegateArray copy];
    [self.delegateArray removeAllObjects];
    [tableLock unlock];
    for(id delegate in array)
    {
        [self failWithDelegate:delegate error:error];
    }
}

- (void)finishWithDelegate:(id <TPSDKLoaderDelegate>)delegate
{
    if(delegate && [delegate respondsToSelector:@selector(tpInitFinish)])
    {
        [delegate tpInitFinish];
    }
}

- (void)failWithDelegate:(id <TPSDKLoaderDelegate>)delegate error:(NSError *)error
{
    if(delegate && [delegate respondsToSelector:@selector(tpInitFailWithError:)])
    {
        [delegate tpInitFailWithError:error];
    }
}
@end
