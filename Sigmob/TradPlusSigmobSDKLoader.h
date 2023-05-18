#import <Foundation/Foundation.h>
#import <TradPlusAds/TPSDKLoaderDelegate.h>

NS_ASSUME_NONNULL_BEGIN

@interface TradPlusSigmobSDKLoader : NSObject

+ (TradPlusSigmobSDKLoader *)sharedInstance;
- (void)initWithAppID:(NSString *)appID
               appKey:(NSString *)appKey
                 delegate:(nullable id <TPSDKLoaderDelegate>)delegate;
- (void)setPersonalizedAd;

@property (nonatomic,assign)BOOL didInit;
@property (nonatomic,assign)NSInteger initSource;
@end
NS_ASSUME_NONNULL_END
