//
//  Debugger.m
//
//  Created by Will Han on 2024/11/7.
//

#import "Debugger.h"
#if __has_include(<FLEX/FLEX.h>)
#import <FLEX/FLEX.h>
#define IDEBUGGER_FLEX_ENABLED 1
#else
#define IDEBUGGER_FLEX_ENABLED 0
#endif

#define RGBA(r, g, b, a)    [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:(a)]
#define RGB(r, g, b)        RGBA(r, g, b, 1.0)

#define kDebuggerWindowCenterLastPosition   @"debugger.window.center.position"

static NSMutableArray<DebugAction *> *allDebugActions = nil;

#pragma mark - DebugAction

@interface DebugAction ()

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *group;
@property (nonatomic, copy) DebugActionBlock block;

@end

@implementation DebugAction

static void initialize_debugger(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allDebugActions = [NSMutableArray new];

#if IDEBUGGER_FLEX_ENABLED
        [allDebugActions addObject:[DebugAction actionWithTitle:@"FLEX"
                                                          group:nil
                                                          block:^{
            [FLEXManager.sharedManager toggleExplorer];
        }]];
#endif
    });
}

+ (void)load {
    initialize_debugger();
}

+ (instancetype)actionWithTitle:(NSString *)title group:(NSString *)group block:(DebugActionBlock)block {
    DebugAction *action = [DebugAction new];

    action.title = title;
    action.group = group;
    action.block = block;

    return action;
}

+ (void)add:(NSString *)title action:(DebugActionBlock)block {
    [self add:title group:nil action:block];
}

+ (void)add:(NSString *)title group:(NSString *)group action:(DebugActionBlock)block {
    initialize_debugger();

    if (title && block) {
        [allDebugActions addObject:[DebugAction actionWithTitle:title group:group block:block]];
    }
}

+ (void)remove:(NSString *)title {
    [self remove:title group:nil];
}

+ (void)remove:(NSString *)title group:(NSString *)group {
    initialize_debugger();

    if (title) {
        NSIndexSet *indexesToRemove = [allDebugActions indexesOfObjectsPassingTest:^BOOL(DebugAction * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.title isEqualToString:title] && (obj.group == nil || [obj.group isEqualToString:group]);
        }];
        [allDebugActions removeObjectsAtIndexes:indexesToRemove];
    }
}

+ (void)runAction:(NSString *)title {
    [self runAction:title group:nil];
}

+ (void)runAction:(NSString *)title group:(NSString *)group {
    initialize_debugger();

    for (DebugAction *action in allDebugActions) {
        if ([title isEqualToString:action.title] && ([group isEqualToString:action.group] || group == action.group)) {
            DebugActionBlock block = action.block;
            NSLog(@"[Debugger] Running action %@ - %@", action.group, action.title);
            !block ?: block();
            break;
        }
    }
}

@end

#pragma mark - ActionButton

@interface ActionButton : UIButton

@end

@implementation ActionButton

@end

#pragma mark - DebugerViewController

@interface DebugerViewController : UIViewController <UIContextMenuInteractionDelegate>

@property (nonatomic, strong) ActionButton *btnAction;

@property (nonatomic, assign) BOOL isMenuDisplaying;

@end

@implementation DebugerViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.clearColor;

    ActionButton *btnAction = [ActionButton buttonWithType:UIButtonTypeSystem];
    btnAction.tintColor = RGB(130, 160, 255);
    [btnAction setBackgroundImage:[UIImage systemImageNamed:@"inset.filled.circle"] forState:UIControlStateNormal];
    [btnAction setBackgroundImage:[UIImage systemImageNamed:@"circle.circle.fill"] forState:UIControlStateHighlighted];

    // Get saved position or use default
    NSString *savedPosition = [[NSUserDefaults standardUserDefaults] stringForKey:kDebuggerWindowCenterLastPosition];
    NSArray *components = [savedPosition componentsSeparatedByString:@"."];
    CGSize size = self.view.frame.size;
    CGFloat width = 50;

    if (components.count == 2) {
        NSUInteger x = [components[0] integerValue];
        NSUInteger y = [components[1] integerValue];
        btnAction.frame = CGRectMake(x - width / 2, y - width / 2, width, width);
    } else {
        btnAction.frame = CGRectMake(size.width - 100, size.height - 200, width, width);
    }
    self.btnAction = btnAction;

    {
        btnAction.layer.cornerRadius = width / 2;
        btnAction.layer.shadowColor = UIColor.blueColor.CGColor;
        btnAction.layer.shadowOpacity = 0.4;
        btnAction.layer.shadowOffset = CGSizeZero;
        btnAction.layer.shadowRadius = width / 2;
    }
    {
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [btnAction addGestureRecognizer:panGesture];

        UIContextMenuInteraction *contextMenuInteraction = [[UIContextMenuInteraction alloc] initWithDelegate:self];
        [btnAction addInteraction:contextMenuInteraction];

        if (@available(iOS 14.0, *)) {
            btnAction.showsMenuAsPrimaryAction = YES;
        } else {
            NSLog(@"Context menu not supported!");
        }
    }

    [self.view addSubview:btnAction];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.view];
    CGPoint newCenter = CGPointMake(self.btnAction.center.x + translation.x, self.btnAction.center.y + translation.y);

    CGFloat halfWidth = self.btnAction.bounds.size.width / 2;
    CGFloat halfHeight = self.btnAction.bounds.size.height / 2;

    newCenter.x = MAX(halfWidth, MIN(newCenter.x, self.view.bounds.size.width - halfWidth));
    newCenter.y = MAX(halfHeight, MIN(newCenter.y, self.view.bounds.size.height - halfHeight));
    self.btnAction.center = newCenter;

    // Reset translation to zero after updating position
    [gesture setTranslation:CGPointZero inView:self.view];

    // Save position when gesture ends
    if (gesture.state == UIGestureRecognizerStateEnded) {
        NSString *position = [NSString stringWithFormat:@"%ld.%ld", (NSUInteger)newCenter.x, (NSUInteger)newCenter.y];
        [[NSUserDefaults standardUserDefaults] setObject:position forKey:kDebuggerWindowCenterLastPosition];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

#pragma mark UIContextMenuInteractionDelegate

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location {
    NSMutableDictionary<NSString *, NSMutableArray<UIAction *> *> *groupedActions = [NSMutableDictionary new];
    NSMutableArray<UIAction *> *ungroupedActions = [NSMutableArray new];

    // First, group all actions by their group property
    for (DebugAction *action in allDebugActions) {
        DebugActionBlock block = action.block;
        UIAction *uiAction = [UIAction actionWithTitle:action.title
                                               image:nil
                                          identifier:nil
                                             handler:^(__kindof UIAction * _Nonnull action) {
            !block ?: block();
        }];

        if (action.group) {
            if (!groupedActions[action.group]) {
                groupedActions[action.group] = [NSMutableArray new];
            }
            [groupedActions[action.group] addObject:uiAction];
        } else {
            [ungroupedActions addObject:uiAction];
        }
    }

    // Create menu items
    NSMutableArray<UIMenuElement *> *menuElements = [NSMutableArray new];

    // Add ungrouped actions directly to the root
    [menuElements addObjectsFromArray:ungroupedActions];

    // Add grouped actions as submenus
    [groupedActions enumerateKeysAndObjectsUsingBlock:^(NSString *group, NSMutableArray<UIAction *> *actions, BOOL *stop) {
        UIMenuOptions options = UIMenuOptionsDisplayInline;

        if (@available(iOS 15.0, *)) {
            options = UIMenuOptionsSingleSelection;
        }

        UIMenu *submenu = [UIMenu menuWithTitle:group
                                          image:nil
                                     identifier:nil
                                        options:options
                                       children:actions];
        [menuElements addObject:submenu];
    }];

    return [UIContextMenuConfiguration configurationWithIdentifier:nil
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
        return [UIMenu menuWithTitle:@"" children:menuElements];
    }];
}

- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willDisplayMenuForConfiguration:(UIContextMenuConfiguration *)configuration animator:(nullable id<UIContextMenuInteractionAnimating>)animator {
    self.isMenuDisplaying = YES;
}

- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willEndForConfiguration:(UIContextMenuConfiguration *)configuration animator:(nullable id<UIContextMenuInteractionAnimating>)animator {
    self.isMenuDisplaying = NO;
}

@end

#pragma mark - DebugWindow

@implementation DebugWindow

+ (void)load {
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(didReceiveNotificaion:) name:UIWindowDidBecomeKeyNotification object:nil];
}

+ (void)didReceiveNotificaion:(id)sender {
    NSNotification *notification = sender;

    if ([notification.name isEqualToString:UIWindowDidBecomeKeyNotification]) {
        [[DebugWindow sharedInstance] show];
    }
}

+ (instancetype)sharedInstance {
    static DebugWindow *window;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        window = [[DebugWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    });

    return window;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        self.windowLevel = UIWindowLevelStatusBar + 1;
        self.backgroundColor = UIColor.clearColor;
    }

    return self;
}

- (DebugerViewController *)contentViewController {
    return (DebugerViewController *)self.rootViewController;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *view = [super hitTest:point withEvent:event];

    if (self.contentViewController.isMenuDisplaying ||
        [view isKindOfClass:ActionButton.class]) {
        return view;
    }

    // NSLog(@"hit view in debugger window: %@", view)

    return nil;
}

- (void)show {
    if (!self.rootViewController) {
        self.rootViewController = [DebugerViewController new];
    }

    self.hidden = NO;

    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *windowScene in UIApplication.sharedApplication.connectedScenes) {
            if ([windowScene isKindOfClass:[UIWindowScene class]]) {
                self.windowScene = windowScene;
                break;
            }
        }
    }
}

- (BOOL)canBecomeKeyWindow {
    return NO;
}

@end


@implementation DebugVariable

+ (NSString *)fullKeyName:(NSString *)name {
    return [@"iDebugger." stringByAppendingString:name];
}

+ (id)variableForName:(NSString *)name {
    return [NSUserDefaults.standardUserDefaults valueForKey:[self fullKeyName:name]];
}

+ (void)setVariableForName:(NSString *)name value:(id)value {
    [NSUserDefaults.standardUserDefaults setValue:value forKey:[self fullKeyName:name]];
    [NSUserDefaults.standardUserDefaults synchronize];
}

@end
