#import "TradPlusUnitySDKLoader.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MSConsentManager.h>
#import <UnityAds/UnityAds.h>
#import <TradPlusAds/MsEvent.h>
#import "TPUnityAdapterBaseInfo.h"

@interface TradPlusUnitySDKLoader()<UnityAdsInitializationDelegate>
{
    NSRecursiveLock *tableLock;
}
@property (nonatomic,assign)NSInteger startTime;
@property (nonatomic,assign)BOOL isIniting;
@property (nonatomic,strong)NSMutableArray *delegateArray;
@property (nonatomic, assign) BOOL openPersonalizedAd;
@end

@implementation TradPlusUnitySDKLoader

+ (TradPlusUnitySDKLoader *)sharedInstance
{
    static TradPlusUnitySDKLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[TradPlusUnitySDKLoader alloc] init];
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
    NSString *version = [UnityAds getVersion];
    NSMutableString *adapterInfo = [[NSMutableString alloc] init];
    [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"Unity"];
    [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_UnityAdapter_Version];
    [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_UnityAdapter_PlatformSDK_Version];
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
        MSLogTrace(@"UnityAds OpenPersonalizedAd %@", @(self.openPersonalizedAd));
        MSLogTrace(@"***********");
        UADSMetaData *piplConsentMetaData = [[UADSMetaData alloc] init];
        [piplConsentMetaData set:@"pipl.consent" value:@(self.openPersonalizedAd)];
        [piplConsentMetaData commit];
        UADSMetaData *privacyConsentMetaData = [[UADSMetaData alloc] init];
        [privacyConsentMetaData set:@"privacy.consent" value:@(self.openPersonalizedAd)];
        [privacyConsentMetaData commit];
    }
}

- (void)initWithGameID:(NSString *)gameID
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
    //gdpr
    if ([[MSConsentManager sharedManager] isGDPRApplicable] == MSBoolYes)
    {
        UADSMetaData *gdprConsentMetaData = [[UADSMetaData alloc] init];
        if ([[MSConsentManager sharedManager] canCollectPersonalInfo] == YES)
        {
            [gdprConsentMetaData set:@"gdpr.consent" value:@YES];
        }
        else {
            [gdprConsentMetaData set:@"gdpr.consent" value:@NO];
        }
        [gdprConsentMetaData commit];
        MSLogTrace(@"unity 设置 gdpr:%@", @([[MSConsentManager sharedManager] canCollectPersonalInfo]));
    }
    
    //ccpa
    int ccpa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCCPAStorageKey];
    if (ccpa > 0)
    {
        UADSMetaData *ccpaConsentMetaData = [[UADSMetaData alloc] init];
        if (ccpa == 2)
        {
            [ccpaConsentMetaData set:@"privacy.consent" value:@(YES)];
        }
        else
        {
            [ccpaConsentMetaData set:@"privacy.consent" value:@(NO)];
        }
        [ccpaConsentMetaData commit];
    }
    
    UADSMediationMetaData *mediationMetaData = [[UADSMediationMetaData alloc] init];
    [mediationMetaData setName:@"TradPlus"];
    [mediationMetaData setVersion:MS_SDK_VERSION];
    [mediationMetaData commit];
    //初始化
    [UnityAds initialize:gameID testMode:false initializationDelegate:self];
}

#pragma mark- UnityAdsInitializationDelegate

- (void)initializationComplete
{
    self.isIniting = NO;
    self.didInit = YES;
    [self initFinish];
    
    NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970]*1000;
    NSInteger lt = endTime - self.startTime;
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    dic[@"lt"] = [NSString stringWithFormat:@"%ld",(long)lt];
    dic[@"cf"] = [NSString stringWithFormat:@"%ld",(long)self.initSource];
    dic[@"as"] = [NSString stringWithFormat:@"%ld",(long)NETWORK_UNITYADS];
    dic[@"asn"] = [MsCommon channelID2Name:NETWORK_UNITYADS];
    dic[@"ec"] = @"1";
    [[MsEvent sharedInstance] uploadEvent:EV_INIT_NETWORK info:dic];
}

- (void)initializationFailed: (UnityAdsInitializationError)error withMessage: (NSString *)message
{
    self.isIniting = NO;
    NSString *errorStr = @"Init Error";
    if(message != nil)
    {
        errorStr = message;
    }
    NSError *unityError = [NSError errorWithDomain:@"Unity" code:1001 userInfo:@{NSLocalizedDescriptionKey: errorStr}];
    [self initFailWithError:unityError];
    
    NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970]*1000;
    NSInteger lt = endTime - self.startTime;
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    dic[@"lt"] = [NSString stringWithFormat:@"%ld",(long)lt];
    dic[@"cf"] = [NSString stringWithFormat:@"%ld",(long)self.initSource];
    dic[@"as"] = [NSString stringWithFormat:@"%ld",(long)NETWORK_UNITYADS];
    dic[@"asn"] = [MsCommon channelID2Name:NETWORK_UNITYADS];
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
