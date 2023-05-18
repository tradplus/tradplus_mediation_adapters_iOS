#import "TradPlusGoogleMediaVideoAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import "TPGoogleIMAAdapterBaseInfo.h"
#import "TradPlusGoogleIMASDKSetting.h"
#import <GoogleInteractiveMediaAds/GoogleInteractiveMediaAds.h>

@interface TradPlusGoogleMediaVideoAdapter ()<IMAAdsLoaderDelegate,IMAAdsManagerDelegate,IMALinkOpenerDelegate>

@property (nonatomic, strong) IMAAdsLoader *adsLoader;
@property (nonatomic, strong) IMAAdsManager *adsManager;
@property (nonatomic, strong) IMAAdsRequest *request;
@property (nonatomic, strong) IMAAdDisplayContainer *adDisplayContainer;
@property (nonatomic, strong) IMAAd *customObject;
@property (nonatomic, assign) BOOL isAppBrowser;
@property (nonatomic, strong) NSString *urlAddressStr;
@property (nonatomic, assign) BOOL hideCountDown;
@end

@implementation TradPlusGoogleMediaVideoAdapter

- (void)dealloc
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self destory];
}

#pragma mark - Extra
- (BOOL)extraActWithEvent:(NSString *)event info:(NSDictionary *)config
{
    if([event isEqualToString:@"AdapterVersion"])
    {
        [self adapterVersionCallback];
    }
    else if([event isEqualToString:@"PlatformSDKVersion"])
    {
        [self platformSDKVersionCallback];
    }
    else if([event isEqualToString:@"videoAds_start"])
    {
        [self showAdContainerViewControllerWithInfo:config];
    }
    else if([event isEqualToString:@"videoAds_pause"])
    {
        [self pause];
    }
    else if([event isEqualToString:@"videoAds_resume"])
    {
        [self resume];
    }
    else if([event isEqualToString:@"videoAds_destory"])
    {
        [self destory];
    }
    else
    {
        return NO;
    }
    return YES;
}

- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_GoogleIMAAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

- (void)platformSDKVersionCallback
{
    NSString *version = [IMAAdsLoader sdkVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_GoogleIMAAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *adTagUrl = item.config[@"placementId"];
    if(adTagUrl == nil)
    {
        [self AdConfigError];
        return;
    }
    self.waterfallItem.extraInfoDictionary[@"main_thread_release"] = @(1);
    [TradPlusGoogleIMASDKSetting sharedInstance];
    if([[TradPlus sharedInstance].settingDataParam valueForKey:@"GoogleIMA_MediaVideo_isAppBrowser"])
    {
        self.isAppBrowser = [[TradPlus sharedInstance].settingDataParam[@"GoogleIMA_MediaVideo_isAppBrowser"] boolValue];
    }
    if([[TradPlus sharedInstance].settingDataParam valueForKey:@"GoogleIMA_MediaVideo_hideCountDown"])
    {
        self.hideCountDown = [[TradPlus sharedInstance].settingDataParam[@"GoogleIMA_MediaVideo_hideCountDown"] boolValue];
    }
    
    NSMutableDictionary *dic = [self dictionaryWithUrlString:adTagUrl];
    if(dic == nil)
    {
        dic = [NSMutableDictionary dictionary];
    }
    if([MSConsentManager sharedManager].isGDPRApplicable == MSBoolYes)
    {
        NSString *consent = @"0";
        if([[MSConsentManager sharedManager] canCollectPersonalInfo])
        {
            consent = @"1";
        }
        dic[@"npa"] = consent;
        MSLogTrace(@"GoogleIMA set gdpr with %@",consent);
    }
    int ccpa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCCPAStorageKey];
    if(ccpa > 0)
    {
        NSString *consent = @"0";
        if(ccpa == 2)
        {
            consent = @"1";
        }
        dic[@"rdp"] = consent;
        MSLogTrace(@"GoogleIMA set ccpa with %@",consent);
    }
    int coppa = (int)[[NSUserDefaults standardUserDefaults] integerForKey:gTPCOPPAStorageKey];
    if (coppa != 0)
    {
        BOOL isChild = (coppa == 2);
        NSString *consent = @"0";
        if(isChild)
        {
            consent = @"1";
        }
        dic[@"tfcd"] = consent;
        MSLogTrace(@"GoogleIMA set coppa with %@",@(isChild));
    }
    if(self.waterfallItem.extraInfoDictionary != nil
       && [self.waterfallItem.extraInfoDictionary valueForKey:@"localParams"])
    {
        id localParams = self.waterfallItem.extraInfoDictionary[@"localParams"];
        if([localParams isKindOfClass:[NSDictionary class]]
           && [localParams valueForKey:@"ima_url_parameters"])
        {
            id parameters = localParams[@"ima_url_parameters"];
            if([parameters isKindOfClass:[NSDictionary class]])
            {
                NSMutableDictionary *newDictionary = [[NSMutableDictionary alloc] init];
                NSDictionary *oldDictionary = parameters;
                NSArray *keyArray = oldDictionary.allKeys;
                NSArray *valueArray = oldDictionary.allValues;
                for(int i = 0 ; i < keyArray.count ; i++)
                {
                    NSString *key = keyArray[i];
                    key = [key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    id value = valueArray[i];
                    if([value isKindOfClass:[NSString class]])
                    {
                        value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    }
                    newDictionary[key] = value;
                }
                [dic addEntriesFromDictionary:newDictionary];
                MSLogTrace(@"GoogleIMA parameters %@",newDictionary);
            }
        }
    }

    adTagUrl = [self urlStringWithDic:dic];
    MSLogTrace(@"adTagUrl--%@",adTagUrl);
    
    self.adsLoader = [[IMAAdsLoader alloc] initWithSettings:nil];
    self.adsLoader.delegate = self;
    
    self.adDisplayContainer = [[IMAAdDisplayContainer alloc] initWithAdContainer:item.mediaVideoAdContainer
                                            viewController:item.mediaVideoViewController
                                            companionSlots:nil];
    IMAAdsRequest *request = [[IMAAdsRequest alloc] initWithAdTagUrl:adTagUrl
                                                  adDisplayContainer:self.adDisplayContainer
                                                     contentPlayhead:nil
                                                         userContext:nil];
    [self.adsLoader requestAdsWithRequest:request];
    
}

- (id)getCustomObject
{
    return self.customObject;
}

- (BOOL)isReady
{
    return (self.adsManager != nil);
}

- (void)play
{
    [self.adsManager start];
}

- (void)pause
{
    [self.adsManager pause];
}

- (void)skip
{
    [self.adsManager skip];
}

- (void)resume
{
    [self.adsManager resume];
}

- (void)destory
{
    if (self.adsLoader)
    {
        [self.adsLoader contentComplete];
        self.adsLoader = nil;
    }
    if (self.adsManager)
    {
        [self.adsManager destroy];
        self.adsManager = nil;
    }
}

- (void)showAdContainerViewControllerWithInfo:(NSDictionary *)info
{
    if (info != nil) {
        if ([info valueForKey:@"viewController"]) {
            UIViewController *viewController = info[@"viewController"];
            self.adDisplayContainer.adContainerViewController = viewController;
        }
    }
    [self play];
}

- (void)adsLoader:(IMAAdsLoader *)loader adsLoadedWithData:(IMAAdsLoadedData *)adsLoadedData
{
    self.adsManager = (IMAAdsManager *)adsLoadedData.adsManager;
    self.adsManager.delegate = self;
    
    if (self.waterfallItem.mute) {
        self.adsManager.volume = 0;
    }
    
    IMAAdsRenderingSettings *adsRenderingSettings = [[IMAAdsRenderingSettings alloc] init];
    if (self.isAppBrowser) {
        adsRenderingSettings.linkOpenerPresentingController = self.waterfallItem.mediaVideoViewController;
        adsRenderingSettings.linkOpenerDelegate = self;
    }
    if(self.hideCountDown)
    {
        adsRenderingSettings.uiElements = @[@(kIMAUiElements_COUNTDOWN)];
    }
    [self.adsManager initializeWithAdsRenderingSettings:adsRenderingSettings];
}

- (void)adsLoader:(IMAAdsLoader *)loader failedWithErrorData:(IMAAdLoadingErrorData *)adErrorData
{
    __weak typeof(self) weakSelf = self;
    tp_dispatch_main_async_safe(^{
        [weakSelf destory];
    })
    
    IMAAdError * adError = adErrorData.adError;
    MSLogTrace(@"%s",__FUNCTION__);
    NSString *errorMessage = @"load failed";
    if(adError.message != nil)
    {
        errorMessage = adError.message;
    }
    NSError *error = [NSError errorWithDomain:@"GoogleIMA" code:adError.code userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
    [self AdLoadFailWithError:error];
}

- (void)adsManager:(IMAAdsManager *)adsManager didReceiveAdError:(IMAAdError *)error
{
    __weak typeof(self) weakSelf = self;
    tp_dispatch_main_async_safe(^{
        [weakSelf destory];
    })
    
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    NSString *errorMessage = [NSString stringWithFormat:@"show fail, reason:%@", error.message];
    NSError *strError = [NSError errorWithDomain:@"GoogleIMA" code:error.code userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
    [self ADShowExtraCallbackWithEvent:@"mediavideo_playError" info:@{@"error":strError}];
}

- (void)adsManager:(IMAAdsManager *)adsManager didReceiveAdEvent:(IMAAdEvent *)event
{
    MSLogTrace(@"%s %@",__PRETTY_FUNCTION__,event.typeString);
    switch (event.type) {
        case kIMAAdEvent_LOADED:
        {
            self.customObject = event.ad;
            [self AdLoadFinsh];
            break;
        }
        case kIMAAdEvent_CLICKED:
        {
            [self AdClick];
            break;
        }
        case kIMAAdEvent_STARTED:
        {
            [self ADShowExtraCallbackWithEvent:@"mediavideo_start" info:nil];
            break;
        }
        case kIMAAdEvent_SKIPPED:
        {
            [self ADShowExtraCallbackWithEvent:@"mediavideo_skiped" info:nil];
            break;
        }
        case kIMAAdEvent_TAPPED:
        {
            [self ADShowExtraCallbackWithEvent:@"mediavideo_tapped" info:nil];
            break;
        }
        case kIMAAdEvent_PAUSE:
        {
            [self ADShowExtraCallbackWithEvent:@"mediavideo_pause" info:nil];
            break;
        }
        case kIMAAdEvent_RESUME:
        {
            [self ADShowExtraCallbackWithEvent:@"mediavideo_resume" info:nil];
            break;
        }
        case kIMAAdEvent_ALL_ADS_COMPLETED:
        {
            __weak typeof(self) weakSelf = self;
            tp_dispatch_main_async_safe(^{
                [weakSelf destory];
            })
            [self ADShowExtraCallbackWithEvent:@"mediavideo_complete" info:nil];
            break;
        }
        default:
            break;
    }
    if(event != nil)
    {
        [self ADShowExtraCallbackWithEvent:@"mediavideo_event" info:@{@"event":event}];
    }
}

- (void)adsManagerAdDidStartBuffering:(IMAAdsManager *)adsManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"mediavideo_adDidStartBuffering" info:nil];
}

- (void)adsManager:(IMAAdsManager *)adsManager adDidBufferToMediaTime:(NSTimeInterval)mediaTime
{
    MSLogTrace(@"%s mediaTime:%@", __PRETTY_FUNCTION__,@(mediaTime));
    [self ADShowExtraCallbackWithEvent:@"mediavideo_adDidBufferToMediaTime" info:@{@"mediaTime":@(mediaTime)}];
}

- (void)adsManagerAdPlaybackReady:(IMAAdsManager *)adsManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self ADShowExtraCallbackWithEvent:@"mediavideo_adPlaybackReady" info:nil];
}

- (void)adsManagerDidRequestContentPause:(IMAAdsManager *)adsManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)adsManagerDidRequestContentResume:(IMAAdsManager *)adsManager
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)adsManager:(IMAAdsManager *)adsManager
    adDidProgressToTime:(NSTimeInterval)mediaTime
              totalTime:(NSTimeInterval)totalTime
{
    MSLogTrace(@"%s mediaTime:%@,totalTime:%@", __PRETTY_FUNCTION__,@(mediaTime),@(totalTime));
    NSDictionary *info = @{@"mediaTime":@(mediaTime),@"totalTime":@(totalTime)};
    [self ADShowExtraCallbackWithEvent:@"mediavideo_playback_progress" info:info];
}


- (void)linkOpenerWillCloseInAppLink:(NSObject *)linkOpener
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if (self.adsManager != nil) {
        [self.adsManager resume];
    }
}

-(NSMutableDictionary *)dictionaryWithUrlString:(NSString *)urlStr
{
    NSArray *array = [urlStr componentsSeparatedByString:@"?"];
    self.urlAddressStr = array.firstObject;
    if(array.count != 2)
    {
        return nil;
    }
    NSString *paramsStr = array[1];
    if (paramsStr.length == 0)
    {
        return nil;
    }
     
    NSMutableDictionary *paramsDict = [NSMutableDictionary dictionary];
    NSArray *paramArray = [paramsStr componentsSeparatedByString:@"&"];
    for (NSString *param in paramArray)
    {
        if (param.length > 0)
        {
            NSArray *parArr = [param componentsSeparatedByString:@"="];
            if (parArr.count == 2)
            {
                NSString *key = parArr[0];
                NSString *value = parArr[1];
                if(value == nil)
                {
                    value = @"";
                }
                paramsDict[key] = value;
            }
        }
    }
    return paramsDict;
}

-(NSString *)urlStringWithDic:(NSDictionary *)dic
{
    NSMutableString *urlStr = [[NSMutableString alloc] initWithString:self.urlAddressStr];
    if(dic.count > 0)
    {
        [urlStr appendString:@"?"];
        [dic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [urlStr appendFormat:@"%@=%@&",key,obj];
        }];
        [urlStr deleteCharactersInRange:NSMakeRange(urlStr.length - 1, 1)];
    }
    return urlStr;
}

@end
