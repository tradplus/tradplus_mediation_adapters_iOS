
#import "TradPlusVerveSDKLoader.h"
#import <TradPlusAds/MSConsentManager.h>
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsEvent.h>
#import <TradPlusAds/MsCommon.h>
#import "TPVerveAdapterBaseInfo.h"

@interface TradPlusVerveSDKLoader()
{
    NSRecursiveLock *tableLock;
}

@property (nonatomic,assign)BOOL isIniting;
@property (nonatomic,strong)NSMutableArray *delegateArray;
@property (nonatomic,copy)NSString *serverSideUserID;
@end

@implementation TradPlusVerveSDKLoader

+(TradPlusVerveSDKLoader *)sharedInstance
{
    static TradPlusVerveSDKLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[TradPlusVerveSDKLoader alloc] init];
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
    NSString *version = [HyBid sdkVersion];
    NSMutableString *adapterInfo = [[NSMutableString alloc] init];
    [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"Verve"];
    [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_VerveAdapter_Version];
    [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_VerveAdapter_PlatformSDK_Version];
    if(version != nil)
    {
        [adapterInfo appendFormat:@"Current version[当前sdk版本]:%@",version];
    }
    MSLogInfo(@"%@", adapterInfo);
}

- (void)setTestMode
{
    [HyBid setTestMode: YES];
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
        NSString* verveGDPRConsentString = [[HyBidUserDataManager sharedInstance] getIABGDPRConsentString];
        if ( !verveGDPRConsentString || [verveGDPRConsentString isEqualToString:@""] )
        {
            [[HyBidUserDataManager sharedInstance] setIABGDPRConsentString: canCollectPersonalInfo ? @"1" : @"0"];
        }
    }
    
    int ccpa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCCPAStorageKey];
    if (ccpa != 0)
    {
        BOOL doNotSell = (ccpa == 1);
        NSString* verveUSPrivacyString = [[HyBidUserDataManager sharedInstance] getIABUSPrivacyString];
            
        if ( !verveUSPrivacyString || [verveUSPrivacyString isEqualToString:@""] )
        {
            if (doNotSell)
            {
                [[HyBidUserDataManager sharedInstance] setIABUSPrivacyString: @"1NYN"];
            }
            else
            {
                [[HyBidUserDataManager sharedInstance] removeIABUSPrivacyString];
            }
        }
    }
    
    int coppa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCOPPAStorageKey];
    if (coppa != 0)
    {
        BOOL isChild = (coppa == 2);
        [HyBid setCoppa: isChild];
    }
    
    if (gMsSDKDebugMode)
    {
        [HyBid setTestMode: YES];
        [HyBidLogger setLogLevel: HyBidLogLevelDebug];
    }

    [HyBid setLocationUpdates: NO];
    __weak typeof(self) weakSelf = self;
    [HyBid initWithAppToken: appID completion:^(BOOL success) {
        weakSelf.isIniting = NO;
        weakSelf.didInit = YES;
        [weakSelf initFinish];
        NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970]*1000;
        NSInteger lt = endTime - startTime;
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
        dic[@"lt"] = [NSString stringWithFormat:@"%ld",(long)lt];
        dic[@"cf"] = [NSString stringWithFormat:@"%ld",(long)self.initSource];
        dic[@"as"] = [NSString stringWithFormat:@"%ld",(long)NETWORK_VERVE];
        dic[@"asn"] = [MsCommon channelID2Name:NETWORK_VERVE];
        dic[@"ec"] = @"1";
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
