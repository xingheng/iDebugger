//
//  Debugger.h
//
//  Created by Will Han on 2024/11/7.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName DebuggerMessageNotification;

typedef void (^ DebugActionBlock)(void);

@interface DebugAction : NSObject

+ (void)add:(NSString *)title action:(DebugActionBlock)block;

+ (void)add:(NSString *)title group:(nullable NSString *)group action:(DebugActionBlock)block;

+ (void)remove:(NSString *)title;

+ (void)remove:(NSString *)title group:(nullable NSString *)group;

+ (void)runAction:(NSString *)title;

+ (void)runAction:(NSString *)title group:(nullable NSString *)group;

+ (BOOL)exist:(NSString *)title group:(nullable NSString *)group;

@end


@interface DebugAction (Message)

+ (void)sendMessage:(NSString *)message;

@end


@interface DebugWindow : UIWindow

+ (instancetype)sharedInstance;

- (void)show;

@end


@interface DebugVariable : NSObject

+ (nullable id)variableForName:(NSString *)name;

+ (void)setVariableForName:(NSString *)name value:(nullable id)value;

@end

NS_ASSUME_NONNULL_END
