#import <Foundation/Foundation.h>
#import <TradPlusAds/TPSDKLoaderDelegate.h>

NS_ASSUME_NONNULL_BEGIN

@interface TradPlusAdColonySDKLoader : NSObject

+ (TradPlusAdColonySDKLoader *)sharedInstance;
- (void)initWithAppID:(NSString *)appID
              zoneIDs:(NSArray <NSString *>*)zoneIDs
             delegate:(nullable id <TPSDKLoaderDelegate>)delegate;
- (void)setUserID:(NSString *)userID;
@property (nonatomic,assign)BOOL testModel;
@property (nonatomic,assign)BOOL didInit;
@property (nonatomic,assign)NSInteger initSource;
@end

NS_ASSUME_NONNULL_END
