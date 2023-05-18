
#import "TradPlusHeliumSDKLoader.h"
#import <TradPlusAds/MSConsentManager.h>
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsEvent.h>
#import <TradPlusAds/MsCommon.h>
#import "TPHeliumAdapterBaseInfo.h"
#import <ChartboostMediationSDK/ChartboostMediationSDK.h>

@interface TradPlusHeliumSDKLoader()<HeliumSdkDelegate>
{
    NSRecursiveLock *tableLock;
}

@property (nonatomic,assign) BOOL isIniting;
@property (nonatomic,strong) NSMutableArray *delegateArray;
@property (nonatomic,copy) NSString *serverSideUserID;
@property (nonatomic, assign) NSTimeInterval startTime;
@end

@implementation TradPlusHeliumSDKLoader

+(TradPlusHeliumSDKLoader *)sharedInstance
{
    static TradPlusHeliumSDKLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[TradPlusHeliumSDKLoader alloc] init];
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
    NSString *version = Helium.sdkVersion;
    NSMutableString *adapterInfo = [[NSMutableString alloc] init];
    [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"Helium"];
    [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_HeliumAdapter_Version];
    [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_HeliumAdapter_PlatformSDK_Version];
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
            [Helium sharedHelium].userIdentifier = userID;
            MSLogTrace(@"Helium ServerSideVerification ->userID: %@", self.serverSideUserID);
        }
    }
}

- (void)initWithAppID:(NSString *)appID appSignature:(NSString *)appSignature
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
    self.startTime = [[NSDate date] timeIntervalSince1970] * 1000;
    
    tp_dispatch_main_async_safe(^{

        [[Helium sharedHelium] setSubjectToGDPR:[MSConsentManager sharedManager].isGDPRApplicable];
        [[Helium sharedHelium] setUserHasGivenConsent:[MSConsentManager sharedManager].canCollectPersonalInfo];

        int ccpa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCCPAStorageKey];
        if(ccpa > 0)
            [[Helium sharedHelium] setCCPAConsent:ccpa == 2];

        int coppa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCOPPAStorageKey];
        if(coppa > 0)
        {
            [[Helium sharedHelium] setSubjectToCoppa:coppa == 2];
        }
        if(self.serverSideUserID != nil)
        {
            [Helium sharedHelium].userIdentifier = self.serverSideUserID;
            MSLogTrace(@"Helium ServerSideVerification ->userID: %@", self.serverSideUserID);
        }
        [[Helium sharedHelium] startWithAppId:appID andAppSignature:appSignature options:nil delegate:self];
    });
}

- (void)heliumDidStartWithError:(nullable ChartboostMediationError *)error
{
    self.isIniting = NO;
    NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970] * 1000;
    NSInteger lt = endTime - self.startTime;
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    dic[@"lt"] = [NSString stringWithFormat:@"%ld",(long)lt];
    dic[@"cf"] = [NSString stringWithFormat:@"%ld",(long)self.initSource];
    dic[@"as"] = [NSString stringWithFormat:@"%ld",(long)NETWORK_HELIUM];
    dic[@"asn"] = [MsCommon channelID2Name:NETWORK_HELIUM];
    if(error == nil)
    {
        dic[@"ec"] = @"1";
        self.didInit = YES;
        [self initFinish];
    }
    else
    {
        dic[@"ec"] = @"2";
        dic[@"emsg"] = @"not finish";
        NSError *error = [NSError errorWithDomain:@"Chartboost" code:1001 userInfo:@{NSLocalizedDescriptionKey: @"Init Error"}];
        [self initFailWithError:error];
    }
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
