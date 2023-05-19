#import "TradPlusOgurySDKLoader.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MSConsentManager.h>
#import <OguryAds/OguryAds.h>
#import <OgurySdk/Ogury.h>
#import <OguryChoiceManager/OguryChoiceManager.h>
#import <TradPlusAds/MsEvent.h>
#import "TPOguryAdapterBaseInfo.h"

@interface TradPlusOgurySDKLoader()
{
    NSRecursiveLock *tableLock;
}
@property (nonatomic,assign)BOOL isIniting;
@property (nonatomic,strong)NSMutableArray *delegateArray;
@end

@implementation TradPlusOgurySDKLoader

+ (TradPlusOgurySDKLoader *)sharedInstance
{
    static TradPlusOgurySDKLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[TradPlusOgurySDKLoader alloc] init];
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
    NSString *version = [Ogury getSdkVersion];
    NSMutableString *adapterInfo = [[NSMutableString alloc] init];
    [adapterInfo appendFormat:@"Ad Network[三方源]:%@，",@"Ogury"];
    [adapterInfo appendFormat:@"Adapter version[Adapter版本]:%@，",TP_OguryAdapter_Version];
    [adapterInfo appendFormat:@"Compatible version[适配sdk版本]:%@，",TP_OguryAdapter_PlatformSDK_Version];
    if(version != nil)
    {
        [adapterInfo appendFormat:@"Current version[当前sdk版本]:%@",version];
    }
    MSLogInfo(@"%@", adapterInfo);
}

- (void)initWithAssetKey:(NSString *)assetKey
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
    
    [[OguryAds shared] defineMediationName:@"TradPlus"];
    
    [self setPrivacyWithAssetKey:assetKey];
    
    __weak typeof(self) weakSelf = self;
    OguryConfigurationBuilder *configurationBuilder = [[OguryConfigurationBuilder alloc] initWithAssetKey: assetKey];
    [Ogury startWithConfiguration: [configurationBuilder build]];
    weakSelf.isIniting = NO;
    NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970]*1000;
    NSInteger lt = endTime - startTime;
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    dic[@"lt"] = [NSString stringWithFormat:@"%ld",(long)lt];
    dic[@"cf"] = [NSString stringWithFormat:@"%ld",(long)self.initSource];
    dic[@"as"] = [NSString stringWithFormat:@"%ld",(long)NETWORK_OGURY];
    dic[@"asn"] = [MsCommon channelID2Name:NETWORK_OGURY];
    dic[@"ec"] = @"1";
    weakSelf.didInit = YES;
    [weakSelf initFinish];
    [[MsEvent sharedInstance] uploadEvent:EV_INIT_NETWORK info:dic];
}

- (void)setPrivacyWithAssetKey:(NSString *)assetKey
{
    if ([MSConsentManager sharedManager].isGDPRApplicable == MSBoolYes)
    {
        if ([MSConsentManager sharedManager].currentStatus != MSBoolUnknown)
            [OguryChoiceManagerExternal setTransparencyAndConsentStatus:[[MSConsentManager sharedManager] canCollectPersonalInfo] origin:@"TradPlus" assetKey:assetKey];
    }
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
