#import "TradPlusCSJSDKLoader.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlus.h>
#import <TradPlusAds/MSConsentManager.h>
#import <BUAdSDK/BUAdSDK.h>
#import <BUAdSDK/BUAdSDKManager.h>
#import <TradPlusAds/MsEvent.h>
#import "TPCSJAdapterBaseInfo.h"

@interface TradPlusCSJSDKLoader()
{
    NSRecursiveLock *tableLock;
}

@property (nonatomic,assign)BOOL isIniting;
@property (nonatomic,strong)NSMutableArray *delegateArray;
@property (nonatomic, assign) BOOL openPersonalizedAd;
@end

@implementation TradPlusCSJSDKLoader

+ (TradPlusCSJSDKLoader *)sharedInstance
{
    static TradPlusCSJSDKLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[TradPlusCSJSDKLoader alloc] init];
    });
    return loader;
}

+ (NSString *)getSDKVersion
{
    NSMutableString *versionStr = [[NSMutableString alloc] initWithString:@""];
    [versionStr appendFormat:@"%@",[BUAdSDKManager SDKVersion]];
    return versionStr;
}

+ (NSString *)getCurrentVersion
{
    return [BUAdSDKManager SDKVersion];
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.openPersonalizedAd = YES;
        self.delegateArray = [[NSMutableArray alloc] init];
        tableLock = [[NSRecursiveLock alloc] init];
        self.initSource = -1;
        [self showAdapterInfo];
    }
    return self;
}

- (void)showAdapterInfo
{
    NSString *version = [TradPlusCSJSDKLoader getSDKVersion];
    NSMutableString *adapterInfo = [[NSMutableString alloc] init];
    [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"CSJ"];
    [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_CSJAdapter_Version];
    [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_CSJAdapter_PlatformSDK_Version];
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
        MSLogTrace(@"CSJ OpenPersonalizedAd %@", @(self.openPersonalizedAd));
        MSLogTrace(@"***********");
        NSString *isOpen = @"1";
        if(!self.openPersonalizedAd)
        {
            isOpen = @"0";
        }
        NSString *userExtData = [NSString stringWithFormat:@"[{\"name\":\"mediation\",\"value\":\"tradplus\"},{\"name\":\"adapter_version\",\"value\":\"19.%@\"},{\"name\":\"personal_ads_type\",\"value\":\"%@\"}]",[TradPlus getVersion],isOpen];
        MSLogTrace(@"CSJ userExtData %@", userExtData);
        [BUAdSDKManager setUserExtData:userExtData];
    }
}

- (void)setAllowModifyAudioSessionSettingWithExtraInfo:(NSDictionary *)extraInfo
{
    if(extraInfo != nil && [extraInfo valueForKey:@"settingDataParam"])
    {
        NSDictionary *settingDataParam = extraInfo[@"settingDataParam"];
        if([settingDataParam isKindOfClass:[NSDictionary class]])
        {
            if([settingDataParam valueForKey:@"CSJ_AllowModifyAudioSessionSetting"])
            {
                BOOL sessionSetting = [settingDataParam[@"CSJ_AllowModifyAudioSessionSetting"] boolValue];
                [BUAdSDKConfiguration configuration].allowModifyAudioSessionSetting = sessionSetting;
                MSLogTrace(@"CSJ_AllowModifyAudioSessionSetting %@", sessionSetting?@"YES":@"NO");
            }
        }
    }
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
    
    BUAdSDKConfiguration *configuration = [BUAdSDKConfiguration configuration];
    NSString *userExtData = [NSString stringWithFormat:@"[{\"name\":\"mediation\",\"value\":\"tradplus\"},{\"name\":\"adapter_version\",\"value\":\"19.%@\"}]",[TradPlus getVersion]];
    configuration.userExtData = userExtData;
    configuration.appID = appID;
    __weak typeof(self) weakSelf = self;
    [BUAdSDKManager startWithAsyncCompletionHandler:^(BOOL success, NSError *error) {
        weakSelf.isIniting = NO;
        NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970]*1000;
        NSInteger lt = endTime - startTime;
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
        dic[@"lt"] = [NSString stringWithFormat:@"%ld",(long)lt];
        dic[@"cf"] = [NSString stringWithFormat:@"%ld",(long)weakSelf.initSource];
        dic[@"as"] = [NSString stringWithFormat:@"%ld",(long)NETWORK_BYTEDANCE];
        dic[@"asn"] = [MsCommon channelID2Name:NETWORK_BYTEDANCE];
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
