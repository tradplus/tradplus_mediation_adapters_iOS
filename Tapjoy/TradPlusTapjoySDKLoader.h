#import <Foundation/Foundation.h>
#import <TradPlusAds/TPSDKLoaderDelegate.h>

NS_ASSUME_NONNULL_BEGIN

@interface TradPlusTapjoySDKLoader : NSObject

+ (TradPlusTapjoySDKLoader *)sharedInstance;
- (void)initWithSDKKey:(NSString *)SDKKey
              delegate:(nullable id <TPSDKLoaderDelegate>)delegate;

@property (nonatomic,assign)BOOL didInit;
@property (nonatomic,assign)NSInteger initSource;
@end
NS_ASSUME_NONNULL_END
