#import "TradPlusSigmobSDKLoader.h"
#import <TradPlusAds/MSConsentManager.h>
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <WindSDK/WindSDK.h>
#import <TradPlusAds/MsEvent.h>
#import "TPSigmobAdapterBaseInfo.h"

@interface TradPlusSigmobSDKLoader()
{
    NSRecursiveLock *tableLock;
}

@property (nonatomic,assign)BOOL isIniting;
@property (nonatomic,strong)NSMutableArray *delegateArray;
@property (nonatomic, assign) BOOL openPersonalizedAd;
@end

@implementation TradPlusSigmobSDKLoader

+ (TradPlusSigmobSDKLoader *)sharedInstance
{
    static TradPlusSigmobSDKLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[TradPlusSigmobSDKLoader alloc] init];
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
        self.openPersonalizedAd = YES;
        self.initSource = -1;
        [self showAdapterInfo];
    }
    return self;
}

- (void)showAdapterInfo
{
    NSString *version = [WindAds sdkVersion];
    NSMutableString *adapterInfo = [[NSMutableString alloc] init];
    [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"Sigmob"];
    [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_SigmobAdapter_Version];
    [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_SigmobAdapter_PlatformSDK_Version];
    if(version != nil)
    {
        [adapterInfo appendFormat:@"Current version[当前sdk版本]:%@",version];
    }
    MSLogInfo(@"%@", adapterInfo);
}

- (void)setPersonalizedAd
{
    if(self.openPersonalizedAd != gTPOpenPersonalizedAd)
    {
        self.openPersonalizedAd = gTPOpenPersonalizedAd;
        MSLogTrace(@"***********");
        MSLogTrace(@"Sigmob OpenPersonalizedAd %@", @(self.openPersonalizedAd));
        MSLogTrace(@"***********");
        if(self.openPersonalizedAd)
        {
            [WindAds setPersonalizedAdvertising:WindPersonalizedAdvertisingOn];
        }
        else
        {
            [WindAds setPersonalizedAdvertising:WindPersonalizedAdvertisingOff];
        }
    }
}

- (void)initWithAppID:(NSString *)appID
               appKey:(NSString *)appKey
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
    
    if ([[MSConsentManager sharedManager] isGDPRApplicable] == MSBoolYes)
    {
        BOOL canCollectPersonalInfo = [[MSConsentManager sharedManager] canCollectPersonalInfo];
        [WindAds setUserGDPRConsentStatus:canCollectPersonalInfo ? WindConsentAccepted : WindConsentDenied];
    }
    
    int ccpa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCCPAStorageKey];
    if (ccpa != 0)
    {
        BOOL ccpaStatus = (ccpa == 2);
        [WindAds updateCCPAStatus:ccpaStatus ? WindCCPAAccepted : WindCCPADenied];
    }
    
    int coppa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCOPPAStorageKey];
    if (coppa != 0)
    {
        BOOL isChild = (coppa == 2);
        [WindAds setIsAgeRestrictedUser:isChild ? WindAgeRestrictedStatusYES : WindAgeRestrictedStatusNO];
    }
    
    WindAdOptions *options = [[WindAdOptions alloc] initWithAppId:appID appKey:appKey];
    tp_dispatch_main_sync_safe(^{
        [WindAds startWithOptions:options];
    });
    self.isIniting = NO;
    self.didInit = YES;
    [self initFinish];
    
    NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970]*1000;
    NSInteger lt = endTime - startTime;
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    dic[@"lt"] = [NSString stringWithFormat:@"%ld",(long)lt];
    dic[@"cf"] = [NSString stringWithFormat:@"%ld",(long)self.initSource];
    dic[@"as"] = [NSString stringWithFormat:@"%ld",(long)NETWORK_SIGMOB];
    dic[@"asn"] = [MsCommon channelID2Name:NETWORK_SIGMOB];
    dic[@"ec"] = @"1";
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
