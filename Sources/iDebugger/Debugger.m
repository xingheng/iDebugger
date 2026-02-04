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

// Internal class aliases
#define CLS_PREFIX(_name)               IDEBUGGER_##_name
#define NotificationViewController      CLS_PREFIX(NotificationViewController)
#define DebugerViewController           CLS_PREFIX(DebugerViewController)

#define TEST    0

#if TEST
#define RANDOM_COLOR RGB(arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256))
#endif

static NSMutableArray<DebugAction *> *allDebugActions = nil;

NSNotificationName DebuggerMessageNotification = @"DebuggerMessageNotification";

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

+ (BOOL)exist:(NSString *)title group:(nullable NSString *)group {
    initialize_debugger();

    return [allDebugActions indexOfObjectPassingTest:^BOOL(DebugAction * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return [obj.title isEqualToString:title] && (obj.group == nil || [obj.group isEqualToString:group]);
    }] != NSNotFound;
}

@end

@implementation DebugAction (Message)

+ (void)sendMessage:(NSString *)message {
    if (message.length <= 0) {
        return;
    }

    if (NSThread.isMainThread) {
        [NSNotificationCenter.defaultCenter postNotificationName:DebuggerMessageNotification
                                                          object:nil
                                                        userInfo:@{@"Message": message}];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:DebuggerMessageNotification
                                                              object:nil
                                                            userInfo:@{@"Message": message}];
        });
    }
}

@end

#pragma mark - ActionButton

@interface ActionButton : UIButton

@end

@implementation ActionButton

@end

#pragma mark - NotificationViewController

@interface NotificationViewController : UIViewController

@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) NSMutableArray<NSString *> *notifications;
@property (nonatomic, strong) NSTimer *dismissTimer;

@property (nonatomic, assign) BOOL isDisposing;
@property (nonatomic, copy) void (^ dispose)(BOOL finished);

@property (nonatomic, assign) NSTimeInterval timerInterval;
@property (nonatomic, assign) NSUInteger maxQueueCount;

@end

@implementation NotificationViewController

- (instancetype)init {
    if (self = [super init]) {
        _notifications = [NSMutableArray new];
        _timerInterval = 1;
        _maxQueueCount = 5;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.textView = [[UITextView alloc] initWithFrame:CGRectZero];
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.editable = NO;
    self.textView.selectable = YES;
    self.textView.scrollEnabled = NO;
    self.textView.font = [UIFont systemFontOfSize:14];
    self.textView.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
    self.textView.backgroundColor = [UIColor.systemBackgroundColor colorWithAlphaComponent:0.65];
    self.textView.layer.cornerRadius = 8;
    self.textView.layer.masksToBounds = YES;

    [self.view addSubview:self.textView];

    [NSLayoutConstraint activateConstraints:@[
        [self.textView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.textView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [self.textView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [self.textView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [self.textView.heightAnchor constraintGreaterThanOrEqualToConstant:20] // Minimal height
    ]];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    // Update text view size when view layout
    [self updateTextViewSize];
}

- (void)dealloc {
    // Clean up timer
    [self.dismissTimer invalidate];
    self.dismissTimer = nil;
    // NSLog(@"dealloc notification vc: %p", self);
}

#pragma mark -

- (void)updateTextViewContent {
    if (!self.textView) {
        return;
    }

    // Combine all notifications with paragraph line breaks
    NSString *combinedText = [self.notifications componentsJoinedByString:@"\n\n"];
    self.textView.text = combinedText;

    // Scroll to end to follow cursor
    if (self.textView.text.length > 0) {
        NSRange range = NSMakeRange(self.textView.text.length - 1, 1);
        [self.textView scrollRangeToVisible:range];
    }

    // Calculate and update text view height
    [self updateTextViewSize];
}

- (void)addNotification:(NSString *)notification {
    if (self.notifications.count >= self.maxQueueCount) {
        [self.notifications removeObjectAtIndex:0];
    }

    [self.notifications addObject:notification];
    [self updateTextViewContent];

    // Schedule removal of the oldest notification using NSTimer
    [self.dismissTimer invalidate];
    self.dismissTimer = [NSTimer scheduledTimerWithTimeInterval:self.timerInterval
                                                         target:self
                                                       selector:@selector(removeOldestNotification)
                                                       userInfo:nil
                                                        repeats:NO];
}

- (void)removeOldestNotification {
    // Invalidate the timer since it's firing
    [self.dismissTimer invalidate];
    self.dismissTimer = nil;

    if (self.notifications.count <= 0) {
        return;
    }

    [self.notifications removeObjectAtIndex:0];

    if (self.notifications.count == 0) {
        // Dismiss when no notifications left
        self.isDisposing = YES;
        !self.dispose ?: self.dispose(NO);

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self dismissViewControllerAnimated:YES completion:nil];
            !self.dispose ?: self.dispose(YES);
            self.isDisposing = NO;
        });
    } else {
        [self updateTextViewContent];
        // Schedule next removal
        self.dismissTimer = [NSTimer scheduledTimerWithTimeInterval:self.timerInterval
                                                             target:self
                                                           selector:@selector(removeOldestNotification)
                                                           userInfo:nil
                                                            repeats:NO];
    }
}

- (void)updateTextViewSize {
    if (!self.textView) {
        return;
    }

    // Get screen dimensions
    CGFloat screenWidth = self.view.window.windowScene.screen.bounds.size.width ?: UIScreen.mainScreen.bounds.size.width;
    CGFloat screenHeight = self.view.window.windowScene.screen.bounds.size.height ?: UIScreen.mainScreen.bounds.size.height;

    // Calculate min and max width
    CGFloat minWidth = screenWidth * 0.3;
    CGFloat maxWidth = screenWidth * 0.8;
    CGFloat maxHeight = screenHeight * 0.5;

    // Calculate required size for text content with maximum width constraint
    CGSize maxSize = CGSizeMake(maxWidth, CGFLOAT_MAX);
    CGSize textSize = [self.textView sizeThatFits:maxSize];

    // Calculate dynamic width: use text width, but clamp between min and max
    CGFloat dynamicWidth = MAX(minWidth, MIN(textSize.width, maxWidth));

    // Calculate dynamic height: use text height, but clamp between min and max
    CGFloat requiredHeight = textSize.height;
    CGFloat dynamicHeight = MAX(30, MIN(requiredHeight, maxHeight));

    // Add safe area insets to the content size
    UIEdgeInsets safeAreaInsets = self.view.safeAreaInsets;
    CGFloat totalWidth = dynamicWidth + safeAreaInsets.left + safeAreaInsets.right;
    CGFloat totalHeight = dynamicHeight + safeAreaInsets.top + safeAreaInsets.bottom;

    // Update preferred content size
    self.preferredContentSize = CGSizeMake(totalWidth, totalHeight);
}

- (void)cancelDismissTimer {
    [self.dismissTimer invalidate];
    self.dismissTimer = nil;
}

- (void)restartDismissTimer {
    [self.dismissTimer invalidate];
    self.dismissTimer = nil;
    
    if (self.notifications.count > 0) {
        self.dismissTimer = [NSTimer scheduledTimerWithTimeInterval:self.timerInterval
                                                             target:self
                                                           selector:@selector(removeOldestNotification)
                                                           userInfo:nil
                                                            repeats:NO];
    }
}

@end

#pragma mark - DebugerViewController

@interface DebugerViewController : UIViewController <UIContextMenuInteractionDelegate, UIPopoverPresentationControllerDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) ActionButton *btnAction;

@property (nonatomic, assign) BOOL isMenuDisplaying;
@property (nonatomic, assign) NotificationViewController *notificationVC;

@end

@implementation DebugerViewController

- (void)viewDidLoad {
    [super viewDidLoad];

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
        panGesture.delegate = self;
        [btnAction addGestureRecognizer:panGesture];

        UIContextMenuInteraction *contextMenuInteraction = [[UIContextMenuInteraction alloc] initWithDelegate:self];
        [btnAction addInteraction:contextMenuInteraction];

        if (@available(iOS 14.0, *)) {
            btnAction.showsMenuAsPrimaryAction = YES;
        } else {
            NSLog(@"Context menu not supported!");
        }
    }

#if TEST
    [btnAction addTarget:self action:@selector(test) forControlEvents:UIControlEventTouchUpInside];
#endif

    [self.view addSubview:btnAction];

    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(receiveMessage:) name:DebuggerMessageNotification object:nil];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark -

#if TEST
- (void)test {
    static NSInteger count = 0;
    // Generate random string with random length
    NSInteger randomLength = arc4random_uniform(100) + 20;
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ";
    NSMutableString *randomString = [NSMutableString stringWithCapacity:randomLength];

    for (NSInteger i = 0; i < randomLength; i++) {
        [randomString appendFormat:@"%C", [letters characterAtIndex:arc4random_uniform((uint32_t)[letters length])]];
    }

    count++;

    [DebugAction sendMessage:[NSString stringWithFormat:@"#%ld: %@ [END]", count, randomString]];
}
#endif

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

- (void)receiveMessage:(NSNotification *)notification {
    NSString *message = notification.userInfo[@"Message"];

    if (message.length <= 0) {
        return;
    }

    // Check if we already have a notification VC that's not being disposed
    if (self.notificationVC && !self.notificationVC.isDisposing) {
        [self.notificationVC addNotification:message];
        return;
    }

    // If notificationVC exists but isDisposing is YES, wait for it to complete
    if (self.notificationVC) {
        NSLog(@"Ignore the message: %@", message);
        return;
    }

    __weak DebugerViewController *weakSelf = self;

    NotificationViewController *notificationVC = [NotificationViewController new];
    // NSLog(@"create notification vc: %p", notificationVC);
    notificationVC.modalPresentationStyle = UIModalPresentationPopover;
    notificationVC.dispose = ^(BOOL finished) {
        if (finished) {
            DebugerViewController *strongSelf = weakSelf;
            strongSelf.notificationVC = nil;
        }
    };
    self.notificationVC = notificationVC;

    UIPopoverPresentationController *popover = notificationVC.popoverPresentationController;
    popover.delegate = self;
    popover.sourceView = self.btnAction;
    popover.sourceRect = self.btnAction.bounds;
    popover.canOverlapSourceViewRect = YES;
    popover.passthroughViews = @[self.btnAction];
    popover.permittedArrowDirections = UIPopoverArrowDirectionAny;

    [self presentViewController:notificationVC animated:YES completion:nil];
    [notificationVC addNotification:message];
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

- (nullable UITargetedPreview *)contextMenuInteraction:(UIContextMenuInteraction *)interaction previewForHighlightingMenuWithConfiguration:(UIContextMenuConfiguration *)configuration {
    // Cancel popover auto-dismiss timer when context menu interaction begins
    if (self.notificationVC) {
        [self.notificationVC cancelDismissTimer];
    }
    
    return nil; // Use default preview
}

- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willDisplayMenuForConfiguration:(UIContextMenuConfiguration *)configuration animator:(nullable id<UIContextMenuInteractionAnimating>)animator {
    self.isMenuDisplaying = YES;
}

- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willEndForConfiguration:(UIContextMenuConfiguration *)configuration animator:(nullable id<UIContextMenuInteractionAnimating>)animator {
    self.isMenuDisplaying = NO;
    
    // Resume popover auto-dismiss timer if popover is still showing
    if (self.notificationVC && self.notificationVC.notifications.count > 0) {
        [self.notificationVC restartDismissTimer];
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    // Allow our gesture recognizers to work simultaneously with other recognizers
    // This helps prevent the popover dismissal gesture from interfering with our button gestures
    return YES;
}

#pragma mark - UIPopoverPresentationControllerDelegate

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {
    return UIModalPresentationNone; // Ensure popover is not adapted for compact size classes
}

- (BOOL)presentationControllerShouldDismiss:(UIPresentationController *)presentationController {
    // Don't allow dismissal when context menu is displaying
    return !self.isMenuDisplaying;
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    // Reset state when popover is dismissed by user
    self.notificationVC = nil;
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
