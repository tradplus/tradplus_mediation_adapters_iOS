#import "TradPlusIronSourceSDKLoader.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MSConsentManager.h>
#import <IronSource/IronSource.h>
#import <TradPlusAds/MsEvent.h>
#import "TPIronSourceAdapterBaseInfo.h"

@interface TradPlusIronSourceSDKLoader()
{
    NSRecursiveLock *tableLock;
}

@property (nonatomic,assign)BOOL isIniting;
@property (nonatomic,strong)NSMutableArray *delegateArray;
@end

@implementation TradPlusIronSourceSDKLoader

+ (TradPlusIronSourceSDKLoader *)sharedInstance
{
    static TradPlusIronSourceSDKLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[TradPlusIronSourceSDKLoader alloc] init];
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
    NSString *version = [IronSource sdkVersion];
    NSMutableString *adapterInfo = [[NSMutableString alloc] init];
    [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"IronSource"];
    [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_IronSourceAdapter_Version];
    [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_IronSourceAdapter_PlatformSDK_Version];
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
        [IronSource setConsent:canCollectPersonalInfo];
        MSLogTrace(@"IronSource set gdpr %@",@(canCollectPersonalInfo));
    }
    
    int ccpa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCCPAStorageKey];
    if (ccpa != 0)
    {
        [IronSource setMetaDataWithKey:@"do_not_sell" value:(ccpa == 1)?@"YES":@"NO"];
    }

    int coppa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCOPPAStorageKey];
    if (coppa != 0)
    {
        [IronSource setMetaDataWithKey:@"is_child_directed" value:(coppa == 2)?@"YES":@"NO"];
    }
    MSLogTrace(@"ironsource 设置 ccpa:%d, coppa:%d", ccpa, coppa);
    
    [IronSource initISDemandOnly:appID adUnits:@[IS_INTERSTITIAL,IS_REWARDED_VIDEO]];
    self.isIniting = NO;
    self.didInit = YES;
    [self initFinish];
    
    
    NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970]*1000;
    NSInteger lt = endTime - startTime;
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    dic[@"lt"] = [NSString stringWithFormat:@"%ld",(long)lt];
    dic[@"cf"] = [NSString stringWithFormat:@"%ld",(long)self.initSource];
    dic[@"as"] = [NSString stringWithFormat:@"%ld",(long)NETWORK_IRONSOURCE];
    dic[@"asn"] = [MsCommon channelID2Name:NETWORK_IRONSOURCE];
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
