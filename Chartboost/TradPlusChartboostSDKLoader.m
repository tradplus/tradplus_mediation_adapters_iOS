#import "TradPlusChartboostSDKLoader.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MSConsentManager.h>
#import <ChartboostSDK/Chartboost.h>
#import <TradPlusAds/MsEvent.h>
#import "TPChartboostAdapterBaseInfo.h"

@interface TradPlusChartboostSDKLoader()
{
    NSRecursiveLock *tableLock;
}

@property (nonatomic,assign)BOOL isIniting;
@property (nonatomic,strong)NSMutableArray *delegateArray;
@end

@implementation TradPlusChartboostSDKLoader

+ (TradPlusChartboostSDKLoader *)sharedInstance
{
    static TradPlusChartboostSDKLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[TradPlusChartboostSDKLoader alloc] init];
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
    NSString *version = [Chartboost getSDKVersion];
    NSMutableString *adapterInfo = [[NSMutableString alloc] init];
    [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"Chartboost"];
    [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_ChartboostAdapter_Version];
    [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_ChartboostAdapter_PlatformSDK_Version];
    if(version != nil)
    {
        [adapterInfo appendFormat:@"Current version[当前sdk版本]:%@",version];
    }
    MSLogInfo(@"%@", adapterInfo);
}

- (void)initWithAppId:(NSString *)appId
         appSignature:(NSString *)appSignature
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
    
    if ([MSConsentManager sharedManager].isGDPRApplicable == MSBoolYes)
    {
        CHBGDPRDataUseConsent *GDPRDataUseConsent = [CHBGDPRDataUseConsent gdprConsent:CHBGDPRConsentNonBehavioral];
        if ([[MSConsentManager sharedManager] canCollectPersonalInfo])
        {
            GDPRDataUseConsent = [CHBGDPRDataUseConsent gdprConsent:CHBGDPRConsentBehavioral];
        }
        [Chartboost addDataUseConsent:GDPRDataUseConsent];
        MSLogTrace(@"Chartboost set GDPR %@",GDPRDataUseConsent);
    }
    
    int ccpa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCCPAStorageKey];
    if (ccpa != 0)
    {
        CHBCCPADataUseConsent * CCPADataUseConsent = [CHBCCPADataUseConsent ccpaConsent:CHBCCPAConsentOptOutSale];
        if(ccpa == 2)
        {
            CCPADataUseConsent = [CHBCCPADataUseConsent ccpaConsent:CHBCCPAConsentOptInSale];
        }
        [Chartboost addDataUseConsent:CCPADataUseConsent];
        MSLogTrace(@"Chartboost set CCPA %@",CCPADataUseConsent);
    }
    
    int coppa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCOPPAStorageKey];
    if (coppa != 0)
    {
        BOOL isChild = (coppa == 2);
        CHBCOPPADataUseConsent * COPPADataUseConsent = [CHBCOPPADataUseConsent isChildDirected:isChild];
        [Chartboost addDataUseConsent:COPPADataUseConsent];
        MSLogTrace(@"Chartboost set COPPA %@",@(isChild));
    }
    
    int lgpd = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"tradplus_consent_lgpd"];
    if (lgpd > 0)
    {
        BOOL isLGPD = (lgpd == 2);
        [Chartboost addDataUseConsent:[CHBLGPDDataUseConsent allowBehavioralTargeting:isLGPD]];
        MSLogTrace(@"Chartboost set LGPD:%d",lgpd);
    }
    
    __weak typeof(self) weakSelf = self;
    [Chartboost startWithAppID:appId appSignature:appSignature completion:^(CHBStartError * _Nullable error) {
        weakSelf.isIniting = NO;
        NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970]*1000;
        NSInteger lt = endTime - startTime;
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
        dic[@"lt"] = [NSString stringWithFormat:@"%ld",(long)lt];
        dic[@"cf"] = [NSString stringWithFormat:@"%ld",(long)self.initSource];
        dic[@"as"] = [NSString stringWithFormat:@"%ld",(long)NETWORK_CHARTBOOST];
        dic[@"asn"] = [MsCommon channelID2Name:NETWORK_CHARTBOOST];
        if(error == nil)
        {
            dic[@"ec"] = @"1";
            weakSelf.didInit = YES;
            [weakSelf initFinish];
        }
        else
        {
            dic[@"ec"] = @"2";
            dic[@"emsg"] = @"init error";
            NSString *errorStr = [[NSString alloc] initWithFormat:@"Init Error with AppId:%@ AppSignature:%@ errCode:%ld",appId,appSignature,(long)error.code];
            NSError *error = [NSError errorWithDomain:@"Chartboost" code:1001 userInfo:@{NSLocalizedDescriptionKey: errorStr}];
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
