#import "TradPlusGDTMobSDKLoader.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import "GDTSDKConfig.h"
#import <TradPlusAds/MsEvent.h>
#import "TPGDTMobAdapterBaseInfo.h"

@interface TradPlusGDTMobSDKLoader()
{
    NSRecursiveLock *tableLock;
}
@property (nonatomic,assign)BOOL isIniting;
@property (nonatomic,strong)NSMutableArray *delegateArray;
@property (nonatomic, assign) BOOL openPersonalizedAd;
@end

@implementation TradPlusGDTMobSDKLoader

+ (TradPlusGDTMobSDKLoader *)sharedInstance
{
    static TradPlusGDTMobSDKLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[TradPlusGDTMobSDKLoader alloc] init];
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
    NSString *version = [GDTSDKConfig sdkVersion];
    NSMutableString *adapterInfo = [[NSMutableString alloc] init];
    [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"优量汇"];
    [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_GDTMobAdapter_Version];
    [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_GDTMobAdapter_PlatformSDK_Version];
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
        MSLogTrace(@"GDTMob OpenPersonalizedAd %@", @(self.openPersonalizedAd));
        MSLogTrace(@"***********");
        if(self.openPersonalizedAd)
        {
            [GDTSDKConfig setPersonalizedState:0];
        }
        else
        {
            [GDTSDKConfig setPersonalizedState:1];
        }
    }
}

- (void)setAudioSessionSettingWithExtraInfo:(NSDictionary *)extraInfo
{
    BOOL audioSessionSetting = NO;
    if(extraInfo != nil && [extraInfo valueForKey:@"settingDataParam"])
    {
        NSDictionary *settingDataParam = extraInfo[@"settingDataParam"];
        if([settingDataParam isKindOfClass:[NSDictionary class]])
        {
            if([settingDataParam valueForKey:@"GDT_EnableDefaultAudioSessionSetting"])
            {
                audioSessionSetting = [settingDataParam[@"GDT_EnableDefaultAudioSessionSetting"] boolValue];
            }
        }
    }
    
    [GDTSDKConfig enableDefaultAudioSessionSetting:audioSessionSetting];
    MSLogTrace(@"GDT_EnableDefaultAudioSessionSetting %@", audioSessionSetting?@"YES":@"NO");
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
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    dic[@"cf"] = [NSString stringWithFormat:@"%ld",(long)self.initSource];
    dic[@"as"] = [NSString stringWithFormat:@"%ld",(long)NETWORK_GDTMOB];
    dic[@"asn"] = [MsCommon channelID2Name:NETWORK_GDTMOB];
    if([GDTSDKConfig registerAppId:appID])
    {
        dic[@"ec"] = @"1";
        self.isIniting = NO;
        self.didInit = YES;
        [self initFinish];
    }
    else
    {
        dic[@"ec"] = @"2";
        dic[@"emsg"] = @"init error";
        self.isIniting = NO;
        NSString *errorStr = [[NSString alloc] initWithFormat:@"Init Error with AppId:%@",appID];
        NSError *error = [NSError errorWithDomain:@"GDTMob" code:1001 userInfo:@{NSLocalizedDescriptionKey: errorStr}];
        [self initFailWithError:error];
    }
    NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970]*1000;
    NSInteger lt = endTime - startTime;
    dic[@"lt"] = [NSString stringWithFormat:@"%ld",(long)lt];
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
