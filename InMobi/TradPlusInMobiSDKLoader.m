#import "TradPlusInMobiSDKLoader.h"
#import <InMobiSDK/IMSdk.h>
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MSConsentManager.h>
#import <TradPlusAds/MsEvent.h>
#import "TPInMobiAdapterBaseInfo.h"

@interface TradPlusInMobiSDKLoader()
{
    NSRecursiveLock *tableLock;
}

@property (nonatomic,assign)BOOL isIniting;
@property (nonatomic,strong)NSMutableArray *delegateArray;
@end

@implementation TradPlusInMobiSDKLoader

+ (TradPlusInMobiSDKLoader *)sharedInstance
{
    static TradPlusInMobiSDKLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[TradPlusInMobiSDKLoader alloc] init];
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
    NSString *version = [IMSdk getVersion];
    NSMutableString *adapterInfo = [[NSMutableString alloc] init];
    [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"InMobi"];
    [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_InMobiAdapter_Version];
    [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_InMobiAdapter_PlatformSDK_Version];
    if(version != nil)
    {
        [adapterInfo appendFormat:@"Current version[当前sdk版本]:%@",version];
    }
    MSLogInfo(@"%@", adapterInfo);
}

- (NSDictionary *)getExtras
{
    int ccpa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCCPAStorageKey];
    if (ccpa != 0)
    {
        BOOL isDoNotSell = (ccpa == 1);
        return @{@"do_not_sell":isDoNotSell ? @"true":@"false"};
    }
    else
    {
        return @{};
    }
}

- (void)initWithAccountID:(NSString *)accountID
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
    NSString *gdprStr = @"false";
    if ([MSConsentManager sharedManager].canCollectPersonalInfo)
    {
        gdprStr = @"true";
    }
    NSMutableDictionary *consentdict = [[NSMutableDictionary alloc] init];
    [consentdict setObject:gdprStr forKey:IM_GDPR_CONSENT_AVAILABLE];
    
    int coppa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCOPPAStorageKey];
    if (coppa != 0)
    {
        BOOL isChild = (coppa == 2);
        [IMSdk setIsAgeRestricted:isChild];
    }
    
    __weak typeof(self) weakSelf = self;
    [IMSdk initWithAccountID:accountID consentDictionary:consentdict andCompletionHandler:^(NSError * _Nullable error) {
        weakSelf.isIniting = NO;
        NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970]*1000;
        NSInteger lt = endTime - startTime;
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
        dic[@"lt"] = [NSString stringWithFormat:@"%ld",(long)lt];
        dic[@"cf"] = [NSString stringWithFormat:@"%ld",(long)self.initSource];
        dic[@"as"] = [NSString stringWithFormat:@"%ld",(long)NETWORK_INMOBI];
        dic[@"asn"] = [MsCommon channelID2Name:NETWORK_INMOBI];
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
