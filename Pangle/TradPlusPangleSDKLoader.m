#import "TradPlusPangleSDKLoader.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlus.h>
#import <TradPlusAds/MSConsentManager.h>
#import <PAGAdSDK/PAGAdSDK.h>
#import <TradPlusAds/MsEvent.h>
#import "TPPangleAdapterBaseInfo.h"

@interface TradPlusPangleSDKLoader()
{
    NSRecursiveLock *tableLock;
}

@property (nonatomic,assign)BOOL isIniting;
@property (nonatomic,strong)NSMutableArray *delegateArray;
@end

@implementation TradPlusPangleSDKLoader

static int notifyIndex = 0;
+ (NSString *)getNotificationStr
{
    return [NSString stringWithFormat:@"pangle_image_download_%d", notifyIndex++];
}

+ (TradPlusPangleSDKLoader *)sharedInstance
{
    static TradPlusPangleSDKLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[TradPlusPangleSDKLoader alloc] init];
    });
    return loader;
}


+ (NSString *)getSDKVersion
{
    NSMutableString *versionStr = [[NSMutableString alloc] initWithString:@""];
    if([PAGSdk respondsToSelector:@selector(SDKVersion)])
    {
        NSString *PAGVersion = [PAGSdk performSelector:@selector(SDKVersion)];
        if(PAGVersion != nil)
        {
            [versionStr appendFormat:@"%@",PAGVersion];
        }
    }
    return versionStr;
}

+ (NSString *)getCurrentVersion
{
    Class PAGSdk = NSClassFromString(@"PAGSdk");
    if(PAGSdk != nil)
    {
        if([PAGSdk respondsToSelector:@selector(SDKVersion)])
        {
            NSString *PAGVersion = [PAGSdk performSelector:@selector(SDKVersion)];
            if(PAGVersion != nil)
            {
                return PAGVersion;
            }
        }
    }
    return [PAGSdk SDKVersion];
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
    NSString *version = [TradPlusPangleSDKLoader getSDKVersion];
    NSMutableString *adapterInfo = [[NSMutableString alloc] init];
    [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"Pangle"];
    [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_PangleAdapter_Version];
    [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_PangleAdapter_PlatformSDK_Version];
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
    NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970]*1000;
    
    PAGConfig *config = [PAGConfig shareConfig];
    NSString *userDataString = [NSString stringWithFormat:@"[{\"name\":\"mediation\",\"value\":\"tradplus\"},{\"name\":\"adapter_version\",\"value\":\"19.%@\"}]",[TradPlus getVersion]];
    config.userDataString = userDataString;
    if ([[MSConsentManager sharedManager] isGDPRApplicable] == MSBoolYes)
    {
        BOOL canCollectPersonalInfo = [[MSConsentManager sharedManager] canCollectPersonalInfo];
        config.GDPRConsent = canCollectPersonalInfo ? PAGGDPRConsentTypeConsent : PAGGDPRConsentTypeNoConsent;
        MSLogTrace(@"Pangle gdpr:%@", canCollectPersonalInfo?@"PAGGDPRConsentTypeConsent":@"PAGGDPRConsentTypeNoConsent");
    }
    int coppa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCOPPAStorageKey];
    config.childDirected = coppa == 2 ? PAGChildDirectedTypeChild:PAGChildDirectedTypeNonChild;
    int ccpa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCCPAStorageKey];
    config.doNotSell = ccpa == 2 ? PAGDoNotSellTypeSell:PAGDoNotSellTypeNotSell;

    config.appID = appID;
    if(gMsSDKDebugMode)
    {
        config.debugLog = YES;
    }
    __weak typeof(self) weakSelf = self;
    [PAGSdk startWithConfig:config completionHandler:^(BOOL success, NSError * _Nonnull error) {
        weakSelf.isIniting = NO;
        NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970]*1000;
        NSInteger lt = endTime - startTime;
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
        dic[@"lt"] = [NSString stringWithFormat:@"%ld",(long)lt];
        dic[@"cf"] = [NSString stringWithFormat:@"%ld",(long)weakSelf.initSource];
        dic[@"as"] = [NSString stringWithFormat:@"%ld",(long)NETWORK_PANGLE];
        dic[@"asn"] = [MsCommon channelID2Name:NETWORK_PANGLE];
        if (success)
        {
            dic[@"ec"] = @"1";
            weakSelf.didInit = YES;
            tp_dispatch_main_async_safe(^{
                [weakSelf initFinish];
            });
        }
        else
        {
            dic[@"ec"] = @"2";
            dic[@"emsg"] = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.localizedDescription];
            tp_dispatch_main_async_safe(^{
                [weakSelf initFailWithError:error];
            });
        }
        [[MsEvent sharedInstance] uploadEvent:EV_INIT_NETWORK info:dic];
    }];
}

- (void)setIcon:(UIImage *)image
{
    [[PAGConfig shareConfig] setAppLogoImage:image];
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
