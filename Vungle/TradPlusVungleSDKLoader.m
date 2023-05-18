#import "TradPlusVungleSDKLoader.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MSConsentManager.h>
#import <TradPlusAds/TradPlus.h>
#import <TradPlusAds/MsEvent.h>
#import "TPVungleAdapterBaseInfo.h"

@interface TradPlusVungleSDKLoader()<VungleSDKDelegate>
{
    NSRecursiveLock *tableLock;
}
@property (nonatomic,assign)NSInteger startTime;
@property (nonatomic,assign)BOOL isIniting;
@property (nonatomic,strong)NSMutableArray *delegateArray;
@end

@implementation TradPlusVungleSDKLoader

+ (TradPlusVungleSDKLoader *)sharedInstance
{
    static TradPlusVungleSDKLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[TradPlusVungleSDKLoader alloc] init];
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
    NSString *version = VungleSDKVersion;
    NSMutableString *adapterInfo = [[NSMutableString alloc] init];
    [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"Vungle"];
    [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_VungleAdapter_Version];
    [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_VungleAdapter_PlatformSDK_Version];
    if(version != nil)
    {
        [adapterInfo appendFormat:@"Current version[当前sdk版本]:%@",version];
    }
    MSLogInfo(@"%@", adapterInfo);
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
    
    //已初始化完成
    if(self.didInit)
    {
        [self initFinish];
        return;
    }
    //正在初始化
    if(self.isIniting)
    {
        return;
    }
    
    self.isIniting = YES;
    self.startTime = [[NSDate date] timeIntervalSince1970]*1000;
    if ([[MSConsentManager sharedManager] isGDPRApplicable] == MSBoolYes)
    {
        BOOL canCollectPersonalInfo = [[MSConsentManager sharedManager] canCollectPersonalInfo];
        [[VungleSDK sharedSDK] updateConsentStatus:(canCollectPersonalInfo) ? VungleConsentAccepted : VungleConsentDenied consentMessageVersion:@""];
    }
    
    int ccpa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCCPAStorageKey];
    if (ccpa != 0)
        [[VungleSDK sharedSDK] updateCCPAStatus:ccpa==2?VungleCCPAAccepted:VungleCCPADenied];
    
    int coppa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCOPPAStorageKey];
    BOOL isChild = (coppa == 2);
    [[VungleSDK sharedSDK] updateCOPPAStatus:isChild];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    [[VungleSDK sharedSDK] performSelector:@selector(setPluginName:version:) withObject:@"TradPlusAd" withObject:[TradPlus getVersion]];
#pragma clang diagnostic pop
    
    [[VungleSDK sharedSDK] setDelegate:self];
    NSError *error = nil;
    if(![[VungleSDK sharedSDK] startWithAppId:appID error:&error])
    {
        if(error == nil)
        {
            error = [NSError errorWithDomain:@"Vungle" code:1000 userInfo:@{NSLocalizedDescriptionKey: @"init fail"}];
        }
        [self vungleSDKFailedToInitializeWithError:error];
    }
}

- (void)updateConsentStatus:(VungleConsentStatus)status
{
    [[VungleSDK sharedSDK] updateConsentStatus:status consentMessageVersion:@""];
}

- (VungleConsentStatus)getCurrentConsentStatus
{
    return [[VungleSDK sharedSDK] getCurrentConsentStatus];
}

- (void)vungleSDKDidInitialize
{
    self.isIniting = NO;
    self.didInit = YES;
    [self initFinish];
    
    NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970]*1000;
    NSInteger lt = endTime - self.startTime;
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    dic[@"lt"] = [NSString stringWithFormat:@"%ld",(long)lt];
    dic[@"cf"] = [NSString stringWithFormat:@"%ld",(long)self.initSource];
    dic[@"as"] = [NSString stringWithFormat:@"%ld",(long)NETWORK_VUNGLE];
    dic[@"asn"] = [MsCommon channelID2Name:NETWORK_VUNGLE];
    dic[@"ec"] = @"1";
    [[MsEvent sharedInstance] uploadEvent:EV_INIT_NETWORK info:dic];
}

- (void)vungleSDKFailedToInitializeWithError:(NSError *)error
{
    self.isIniting = NO;
    [self initFailWithError:error];
    
    NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970]*1000;
    NSInteger lt = endTime - self.startTime;
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    dic[@"lt"] = [NSString stringWithFormat:@"%ld",(long)lt];
    dic[@"cf"] = [NSString stringWithFormat:@"%ld",(long)self.initSource];
    dic[@"as"] = [NSString stringWithFormat:@"%ld",(long)NETWORK_VUNGLE];
    dic[@"asn"] = [MsCommon channelID2Name:NETWORK_VUNGLE];
    dic[@"ec"] = @"2";
    dic[@"emsg"] = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.localizedDescription];
    [[MsEvent sharedInstance] uploadEvent:EV_INIT_NETWORK info:dic];
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
