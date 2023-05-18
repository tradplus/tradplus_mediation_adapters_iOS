#import <Foundation/Foundation.h>
#import <TradPlusAds/TPSDKLoaderDelegate.h>

NS_ASSUME_NONNULL_BEGIN

@interface TradPlusMintegralSDKLoader : NSObject

+ (TradPlusMintegralSDKLoader *)sharedInstance;
- (void)initWithAppID:(NSString *)appID
               apiKey:(NSString *)apiKey
             delegate:(nullable id <TPSDKLoaderDelegate>)delegate;
- (void)setPersonalizedAd;

@property (nonatomic,assign)BOOL didInit;

//初始化来源 1:open 2:bidding 3:load
@property (nonatomic,assign)NSInteger initSource;
@end
NS_ASSUME_NONNULL_END
