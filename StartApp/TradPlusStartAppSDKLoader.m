#import "TradPlusStartAppSDKLoader.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MSConsentManager.h>
#import <StartApp/StartApp.h>
#import <TradPlusAds/TradPlusAds.h>
#import "TPStartAppAdapterBaseInfo.h"

@interface TradPlusStartAppSDKLoader()
{
    NSRecursiveLock *tableLock;
}

@property (nonatomic,assign)BOOL isIniting;
@property (nonatomic,strong)NSMutableArray *delegateArray;
@end

@implementation TradPlusStartAppSDKLoader

+ (TradPlusStartAppSDKLoader *)sharedInstance
{
    static TradPlusStartAppSDKLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[TradPlusStartAppSDKLoader alloc] init];
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
    NSString *version = [[STAStartAppSDK sharedInstance] version];
    NSMutableString *adapterInfo = [[NSMutableString alloc] init];
    [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"StartApp"];
    [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_StartAppAdapter_Version];
    [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_StartAppAdapter_PlatformSDK_Version];
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
    STAStartAppSDK* sdk = [STAStartAppSDK sharedInstance];
    [sdk addWrapperWithName:@"TradPlus" version:TP_StartAppAdapter_Version];
    sdk.returnAdEnabled = NO;
    sdk.appID = appID;
    if(gMsSDKDebugMode || gTPTestMode)
    {
        sdk.testAdsEnabled = YES;
    }
    
    if ([[MSConsentManager sharedManager] isGDPRApplicable] == MSBoolYes)
    {
        BOOL canCollectPersonalInfo = [[MSConsentManager sharedManager] canCollectPersonalInfo];
        [[STAStartAppSDK sharedInstance] setUserConsent:canCollectPersonalInfo forConsentType:@"pas" withTimestamp:[[NSDate date] timeIntervalSince1970]];
        MSLogTrace(@"StartApp set gdpr %@",@(canCollectPersonalInfo));
    }
    
    int ccpa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCCPAStorageKey];
    if (ccpa > 0)
    {
        [sdk handleExtras:^(NSMutableDictionary<NSString*,id>* extras) {
            if (ccpa == 2)
            {
                [extras setObject:@"1YNN" forKey:@"IABUSPrivacy_String"];
            }
            else
            {
                [extras setObject:@"1YYN" forKey:@"IABUSPrivacy_String"];
            }
        }];
        MSLogTrace(@"StartApp set ccpa:%d", ccpa);
    }
    
    self.isIniting = NO;
    self.didInit = YES;
    [self initFinish];
    
    NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970]*1000;
    NSInteger lt = endTime - startTime;
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    dic[@"lt"] = [NSString stringWithFormat:@"%ld",(long)lt];
    dic[@"cf"] = [NSString stringWithFormat:@"%ld",(long)self.initSource];
    dic[@"as"] = [NSString stringWithFormat:@"%ld",(long)NETWORK_STARTAPP];
    dic[@"asn"] = [MsCommon channelID2Name:NETWORK_STARTAPP];
    dic[@"ec"] = @"1";
    [[MsEvent sharedInstance] uploadEvent:EV_INIT_NETWORK info:dic];
}

- (void)setTestMode
{
    [STAStartAppSDK sharedInstance].testAdsEnabled = YES;
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
