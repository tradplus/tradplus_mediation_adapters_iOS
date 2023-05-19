#import "TradPlusAdColonySDKLoader.h"
#import <TradPlusAds/MSConsentManager.h>
#import <AdColony/AdColony.h>
#import <TradPlusAds/TradPlus.h>
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsEvent.h>
#import "TPAdColonyAdapterBaseInfo.h"

@interface TradPlusAdColonySDKLoader()
{
    NSRecursiveLock *tableLock;
}
@property (nonatomic,assign)BOOL isIniting;
@property (nonatomic,strong)NSMutableArray *delegateArray;
@property (nonatomic,copy)NSString *serverSideUserID;
@end

@implementation TradPlusAdColonySDKLoader

+(TradPlusAdColonySDKLoader *)sharedInstance
{
    static TradPlusAdColonySDKLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[TradPlusAdColonySDKLoader alloc] init];
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
        self.testModel = NO;
        self.initSource = -1;
        [self showAdapterInfo];
    }
    return self;
}

- (void)showAdapterInfo
{
    NSString *version = [AdColony getSDKVersion];
    NSMutableString *adapterInfo = [[NSMutableString alloc] init];
    [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"AdColony"];
    [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_AdColonyAdapter_Version];
    [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_AdColonyAdapter_PlatformSDK_Version];
    if(version != nil)
    {
        [adapterInfo appendFormat:@"Current version[当前sdk版本]:%@",version];
    }
    MSLogInfo(@"%@", adapterInfo);
}

- (void)setTestModel:(BOOL)testModel
{
    _testModel = testModel;
    if(self.didInit || self.isIniting)
    {
        AdColonyAppOptions *appOptions = [AdColony getAppOptions];
        if(appOptions != nil)
        {
            appOptions.testMode = testModel;
            [AdColony setAppOptions:appOptions];
        }
    }
}

- (void)setUserID:(NSString *)userID
{
    if(userID != nil && userID.length > 0)
    {
        self.serverSideUserID = userID;
        if(self.didInit || self.isIniting)
        {
            AdColonyAppOptions *appOptions = [AdColony getAppOptions];
            if(appOptions != nil)
            {
                appOptions.userID = userID;
                [AdColony setAppOptions:appOptions];
                MSLogTrace(@"AdColony ServerSideVerification ->userID: %@", userID);
            }
        }
    }
}

- (void)initWithAppID:(NSString *)appID
              zoneIDs:(NSArray <NSString *>*)zoneIDs
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
    
    AdColonyAppOptions *appOptions = [[AdColonyAppOptions alloc] init];
    [appOptions setMediationNetwork:@"TradPlus"];
    NSString *networkVersion = [NSString stringWithFormat:@"%ld.%@",(long)NETWORK_ADCOLONY,[TradPlus getVersion]];
    [appOptions setMediationNetworkVersion:networkVersion];
    
    if([MSConsentManager sharedManager].isGDPRApplicable == MSBoolYes)
    {
        NSString *consent = @"0";
        if([[MSConsentManager sharedManager] canCollectPersonalInfo])
        {
            consent = @"1";
        }
        [appOptions setPrivacyConsentString:consent forType:ADC_GDPR];
    }
    int ccpa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCCPAStorageKey];
    if(ccpa > 0)
    {
        [appOptions setPrivacyFrameworkOfType:ADC_CCPA isRequired:YES];
        NSString *consent = @"0";
        if(ccpa == 2)
        {
            consent = @"1";
        }
        [appOptions setPrivacyConsentString:consent forType:ADC_CCPA];
    }
    int coppa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCOPPAStorageKey];
    if(coppa == 2)
    {
        [appOptions setPrivacyFrameworkOfType:ADC_COPPA isRequired:YES];
    }
    __weak typeof(self) weakSelf = self;
    [AdColony configureWithAppID:appID
                         zoneIDs:zoneIDs
                         options:appOptions
                      completion:^(NSArray<AdColonyZone *> * _Nonnull zones) {
        weakSelf.isIniting = NO;
        
        NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970]*1000;
        NSInteger lt = endTime - startTime;
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
        dic[@"lt"] = [NSString stringWithFormat:@"%ld",(long)lt];
        dic[@"cf"] = [NSString stringWithFormat:@"%ld",(long)self.initSource];
        dic[@"as"] = [NSString stringWithFormat:@"%ld",(long)NETWORK_ADCOLONY];
        dic[@"asn"] = [MsCommon channelID2Name:NETWORK_ADCOLONY];
        if(zones != nil)
        {
            dic[@"ec"] = @"1";
            weakSelf.didInit = YES;
            [weakSelf initFinish];
        }
        else
        {
            dic[@"ec"] = @"2";
            dic[@"emsg"] = @"AdColonyZone zones is nil";
            NSString *errorStr = [[NSString alloc] initWithFormat:@"Init Error with AppId:%@ zoneIDs:%@",appID,zoneIDs];
            NSError *error = [NSError errorWithDomain:@"AdColony" code:1001 userInfo:@{NSLocalizedDescriptionKey: errorStr}];
            [weakSelf initFailWithError:error];
        }
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
