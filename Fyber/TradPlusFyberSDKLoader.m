#import "TradPlusFyberSDKLoader.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MSConsentManager.h>
#import <IASDKCore/IASDKCore.h>
#import <TradPlusAds/MsEvent.h>
#import "TPFyberAdapterBaseInfo.h"

@interface TradPlusFyberSDKLoader()
{
    NSRecursiveLock *tableLock;
}
@property (nonatomic, assign) BOOL isIniting;
@property (nonatomic, strong) NSMutableArray *delegateArray;
@end

@implementation TradPlusFyberSDKLoader

+ (TradPlusFyberSDKLoader *)sharedInstance
{
    static TradPlusFyberSDKLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[TradPlusFyberSDKLoader alloc] init];
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
    NSString *version = [[IASDKCore sharedInstance] version];
    NSMutableString *adapterInfo = [[NSMutableString alloc] init];
    [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"Fyber"];
    [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_FyberAdapter_Version];
    [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_FyberAdapter_PlatformSDK_Version];
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
    
    if ([[MSConsentManager sharedManager] isGDPRApplicable] == MSBoolYes)
    {
        BOOL canCollectPersonalInfo = [[MSConsentManager sharedManager] canCollectPersonalInfo];
        IASDKCore.sharedInstance.GDPRConsent = canCollectPersonalInfo ? IAGDPRConsentTypeGiven : IAGDPRConsentTypeDenied;
        MSLogTrace(@"Fyber set gdpr %@",@(canCollectPersonalInfo));
    }
    
    int ccpa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCCPAStorageKey];
    if (ccpa == 2)
    {
        IASDKCore.sharedInstance.CCPAString = @"1YNN";
    }
    MSLogTrace(@"fyber set ccpa:%d", ccpa);
    
    int lgpd = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"tradplus_consent_lgpd"];
    if (lgpd > 0)
    {
        IASDKCore.sharedInstance.LGPDConsent = lgpd == 2 ? IALGPDConsentTypeGiven:IALGPDConsentTypeDenied;
        MSLogTrace(@"fyber set lgpd:%d", lgpd);
    }
    
    __weak typeof(self) weakSelf = self;
    [IASDKCore.sharedInstance initWithAppID:appID completionBlock:^(BOOL success, NSError * _Nullable error) {
        weakSelf.isIniting = NO;
        NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970]*1000;
        NSInteger lt = endTime - startTime;
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
        dic[@"lt"] = [NSString stringWithFormat:@"%ld",(long)lt];
        dic[@"cf"] = [NSString stringWithFormat:@"%ld",(long)self.initSource];
        dic[@"as"] = [NSString stringWithFormat:@"%ld",(long)NETWORK_FYBER];
        dic[@"asn"] = [MsCommon channelID2Name:NETWORK_FYBER];
        if(error == nil)
        {
            dic[@"ec"] = @"1";
            weakSelf.didInit = YES;
            [weakSelf initFinish];
        }
        else
        {
            dic[@"ec"] = @"2";
            dic[@"emsg"] = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.localizedDescription];
            [weakSelf initFailWithError:error];
        }
        [[MsEvent sharedInstance] uploadEvent:EV_INIT_NETWORK info:dic];
    } completionQueue:nil];
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
