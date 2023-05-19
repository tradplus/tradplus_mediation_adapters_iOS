#import "TradPlusTapjoySDKLoader.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MSConsentManager.h>
#import <Tapjoy/Tapjoy.h>
#import <TradPlusAds/MsEvent.h>
#import "TPTapjoyAdapterBaseInfo.h"

@interface TradPlusTapjoySDKLoader()
{
    NSRecursiveLock *tableLock;
}
@property (nonatomic,assign)NSInteger startTime;
@property (nonatomic,assign)BOOL isIniting;
@property (nonatomic,strong)NSMutableArray *delegateArray;
@end

@implementation TradPlusTapjoySDKLoader

+ (TradPlusTapjoySDKLoader *)sharedInstance
{
    static TradPlusTapjoySDKLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[TradPlusTapjoySDKLoader alloc] init];
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
    NSString *version = [Tapjoy getVersion];
    NSMutableString *adapterInfo = [[NSMutableString alloc] init];
    [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"Tapjoy"];
    [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_TapjoyAdapter_Version];
    [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_TapjoyAdapter_PlatformSDK_Version];
    if(version != nil)
    {
        [adapterInfo appendFormat:@"Current version[当前sdk版本]:%@",version];
    }
    MSLogInfo(@"%@", adapterInfo);
}

- (void)initWithSDKKey:(NSString *)SDKKey
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
    self.startTime = [[NSDate date] timeIntervalSince1970]*1000;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tjcConnectSuccess:) name:TJC_CONNECT_SUCCESS object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tjcConnectFail:) name:TJC_CONNECT_FAILED object:nil];
    
    int ccpa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCCPAStorageKey];
    if (ccpa != 0)
    {
        if (ccpa == 2)
        {
            [[TJPrivacyPolicy sharedInstance] setUSPrivacy:@"1YYY"];
        }
    }
    
    int coppa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCOPPAStorageKey];
    if (coppa != 0)
    {
        [[TJPrivacyPolicy sharedInstance] setBelowConsentAge:coppa == 2];
    }
    
    if([MSConsentManager sharedManager].isGDPRApplicable == MSBoolYes)
    {
        NSString *consent = @"0";
        if([[MSConsentManager sharedManager] canCollectPersonalInfo])
        {
            consent = @"1";
        }
        [[TJPrivacyPolicy sharedInstance] setUserConsent:consent];
    }
    
    NSMutableDictionary *connectOptions = [[NSMutableDictionary alloc] init];
    [connectOptions setObject:@(NO) forKey:TJC_OPTION_ENABLE_LOGGING];
    [Tapjoy connect:SDKKey options:connectOptions];
}


- (void)tjcConnectSuccess:(NSNotification *)notifyObj
{
    self.isIniting = NO;
    self.didInit = YES;
    [self initFinish];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970]*1000;
    NSInteger lt = endTime - self.startTime;
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    dic[@"lt"] = [NSString stringWithFormat:@"%ld",(long)lt];
    dic[@"cf"] = [NSString stringWithFormat:@"%ld",(long)self.initSource];
    dic[@"as"] = [NSString stringWithFormat:@"%ld",(long)NETWORK_TAPJOY];
    dic[@"asn"] = [MsCommon channelID2Name:NETWORK_TAPJOY];
    dic[@"ec"] = @"1";
    [[MsEvent sharedInstance] uploadEvent:EV_INIT_NETWORK info:dic];
}

- (void)tjcConnectFail:(NSNotification *)notifyObj
{
    self.isIniting = NO;
    NSString *errorStr = [[NSString alloc] initWithFormat:@"Init Error"];
    NSError *error = [NSError errorWithDomain:@"Tapjoy" code:1001 userInfo:@{NSLocalizedDescriptionKey: errorStr}];
    [self initFailWithError:error];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970]*1000;
    NSInteger lt = endTime - self.startTime;
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    dic[@"lt"] = [NSString stringWithFormat:@"%ld",(long)lt];
    dic[@"cf"] = [NSString stringWithFormat:@"%ld",(long)self.initSource];
    dic[@"as"] = [NSString stringWithFormat:@"%ld",(long)NETWORK_TAPJOY];
    dic[@"asn"] = [MsCommon channelID2Name:NETWORK_TAPJOY];
    dic[@"ec"] = @"2";
    dic[@"emsg"] = errorStr;
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
