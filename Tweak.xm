#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>
#import <QuartzCore/QuartzCore.h>

// ============ OFFSETS ============
#define OFFSET_GET_LOCAL_PLAYER    0x334B268
#define OFFSET_GET_PLAYERS_LIST    0x5D70930
#define OFFSET_GET_TEAM            0x3D496E0
#define OFFSET_GET_TRANSFORM       0x6021A2C
#define OFFSET_GET_POSITION        0x602EC28
#define OFFSET_CAMERA_GET_MAIN     0x84E7148
#define OFFSET_WORLD_TO_SCREEN     0x84E6A54

// ============ VARIABLES ============
static BOOL espLineEnabled = NO;
static NSTimer *gameTimer = nil;
static UIView *espContainer = nil;
static BOOL isGameReady = NO;
static NSMutableArray *allButtons = nil;
static UIButton *secretButton = nil;

// ============ STRUCTURES ============
typedef struct { float x; float y; float z; } vec3_t;

// ============ FONCTIONS ============
static UIWindow* GetKeyWindow() {
    if (@available(iOS 13, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) return window;
                }
            }
        }
    }
    return nil;
}

static void* GetLocalPlayer() {
    void* (*func)() = (void* (*)())OFFSET_GET_LOCAL_PLAYER;
    return func ? func() : NULL;
}

static void** GetPlayersList(int *count) {
    void** (*func)(int*) = (void** (*)(int*))OFFSET_GET_PLAYERS_LIST;
    return func ? func(count) : NULL;
}

static void* GetTransform(void* player) {
    void* (*func)(void*) = (void* (*)(void*))OFFSET_GET_TRANSFORM;
    return func ? func(player) : NULL;
}

static vec3_t GetPosition(void* player) {
    void* transform = GetTransform(player);
    if (!transform) return (vec3_t){0,0,0};
    vec3_t (*func)(void*) = (vec3_t (*)(void*))OFFSET_GET_POSITION;
    return func ? func(transform) : (vec3_t){0,0,0};
}

static int GetTeam(void* player) {
    int (*func)(void*) = (int (*)(void*))OFFSET_GET_TEAM;
    return func ? func(player) : 0;
}

static void* GetMainCamera() {
    void* (*func)() = (void* (*)())OFFSET_CAMERA_GET_MAIN;
    return func ? func() : NULL;
}

static CGPoint WorldToScreen(vec3_t worldPos) {
    vec3_t (*func)(void*, vec3_t) = (vec3_t (*)(void*, vec3_t))OFFSET_WORLD_TO_SCREEN;
    void* camera = GetMainCamera();
    if (!camera) return CGPointMake(-1, -1);
    vec3_t result = func(camera, worldPos);
    return CGPointMake(result.x, result.y);
}

static void DrawLine(CGPoint from, CGPoint to) {
    if (!espContainer) return;
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:from];
    [path addLineToPoint:to];
    
    CAShapeLayer *lineLayer = [CAShapeLayer layer];
    lineLayer.path = path.CGPath;
    lineLayer.strokeColor = [UIColor redColor].CGColor;
    lineLayer.lineWidth = 2;
    lineLayer.fillColor = [UIColor clearColor].CGColor;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [espContainer.layer addSublayer:lineLayer];
    });
}

static void UpdateGame() {
    if (!isGameReady || !espLineEnabled) return;
    
    @autoreleasepool {
        void* localPlayer = GetLocalPlayer();
        if (!localPlayer) return;
        
        int localTeam = GetTeam(localPlayer);
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        CGPoint screenCenter = CGPointMake(screenSize.width / 2, screenSize.height);
        
        int playerCount = 0;
        void** players = GetPlayersList(&playerCount);
        if (!players) return;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (espContainer) espContainer.layer.sublayers = nil;
        });
        
        for (int i = 0; i < playerCount && i < 50; i++) {
            void* player = players[i];
            if (!player || player == localPlayer) continue;
            if (GetTeam(player) == localTeam) continue;
            
            vec3_t enemyPos = GetPosition(player);
            CGPoint screenPos = WorldToScreen(enemyPos);
            
            if (screenPos.x > 0 && screenPos.x < screenSize.width &&
                screenPos.y > 0 && screenPos.y < screenSize.height) {
                DrawLine(screenCenter, screenPos);
            }
        }
    }
}

static void StartGameLoop() {
    if (gameTimer) [gameTimer invalidate];
    gameTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer *timer) {
        UpdateGame();
    }];
}

// === BOUTON DRAGGABLE ===
@interface DraggableButton : UIButton
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, copy) void (^toggleBlock)(void);
@end

@implementation DraggableButton

- (instancetype)initWithFrame:(CGRect)frame title:(NSString *)title block:(void (^)(void))block {
    self = [super initWithFrame:frame];
    if (self) {
        self.toggleBlock = block;
        self.isActive = NO;
        
        [self setTitle:title forState:UIControlStateNormal];
        [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        self.backgroundColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:0.85];
        self.layer.cornerRadius = 12;
        self.layer.borderWidth = 1;
        self.layer.borderColor = [UIColor whiteColor].CGColor;
        
        [self addTarget:self action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
    }
    return self;
}

- (void)buttonTapped {
    if (self.toggleBlock) self.toggleBlock();
    
    self.isActive = !self.isActive;
    if (self.isActive) {
        self.backgroundColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:0.9];
        self.layer.borderColor = [UIColor greenColor].CGColor;
    } else {
        self.backgroundColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:0.85];
        self.layer.borderColor = [UIColor whiteColor].CGColor;
    }
    
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformMakeScale(0.95, 0.95);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            self.transform = CGAffineTransformIdentity;
        }];
    }];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self.superview];
}

@end

// === BOUTON SECRET ===
@interface SecretButton : UIButton
@end

@implementation SecretButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.0 green:0.6 blue:0.0 alpha:0.85];
        self.layer.cornerRadius = frame.size.width / 2;
        self.titleLabel.font = [UIFont boldSystemFontOfSize:22];
        [self setTitle:@"🔓" forState:UIControlStateNormal];
        [self addTarget:self action:@selector(toggleSecret) forControlEvents:UIControlEventTouchUpInside];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self.superview];
}

- (void)toggleSecret {
    isGameReady = !isGameReady;
    
    if (isGameReady) {
        [self setTitle:@"🔓 ON" forState:UIControlStateNormal];
        self.backgroundColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.0 alpha:0.9];
        SetupESP();
        StartGameLoop();
        NSLog(@"✅ Cheats activés");
        
        for (UIView *btn in allButtons) {
            if (btn != secretButton) btn.hidden = NO;
        }
    } else {
        [self setTitle:@"🔒 OFF" forState:UIControlStateNormal];
        self.backgroundColor = [UIColor colorWithRed:0.0 green:0.6 blue:0.0 alpha:0.85];
        ClearESP();
        NSLog(@"❌ Cheats désactivés");
        
        for (UIView *btn in allButtons) {
            if (btn != secretButton) btn.hidden = YES;
        }
    }
}

@end

static void SetupESP() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = GetKeyWindow();
        if (!keyWindow) return;
        
        if (!espContainer) {
            espContainer = [[UIView alloc] initWithFrame:keyWindow.bounds];
            espContainer.backgroundColor = [UIColor clearColor];
            espContainer.userInteractionEnabled = NO;
            [keyWindow addSubview:espContainer];
        }
    });
}

static void ClearESP() {
    if (!espContainer) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIView *subview in espContainer.subviews) {
            [subview removeFromSuperview];
        }
        espContainer.layer.sublayers = nil;
    });
}

// === ACTIONS ===
void updateESPLine() { espLineEnabled = !espLineEnabled; }

// === CRÉATION DE L'UI ===
static void CreateUI() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = GetKeyWindow();
        UIViewController *root = keyWindow.rootViewController;
        if (!root || !root.view) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                CreateUI();
            });
            return;
        }
        
        allButtons = [NSMutableArray new];
        
        CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
        CGFloat btnW = 100, btnH = 40;
        
        // Texte XSNPMODZZZ
        UILabel *xsnLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 15, 200, 20)];
        xsnLabel.text = @"XSNPMODZZZ";
        xsnLabel.textColor = [UIColor colorWithRed:0.6 green:0.2 blue:1.0 alpha:0.8];
        xsnLabel.font = [UIFont systemFontOfSize:10];
        [root.view addSubview:xsnLabel];
        
        // Bouton secret
        secretButton = [[SecretButton alloc] initWithFrame:CGRectMake(screenW - 55, 45, 45, 45)];
        [root.view addSubview:secretButton];
        
        // Un seul bouton : ESP LINE
        DraggableButton *btn = [[DraggableButton alloc] initWithFrame:CGRectMake(screenW/2 - btnW/2, 100, btnW, btnH) title:@"ESP LINE" block:^{ updateESPLine(); }];
        btn.hidden = YES;
        [root.view addSubview:btn];
        [allButtons addObject:btn];
        
        NSLog(@"✅ UI créée - 1 bouton ESP LINE");
    });
}

%ctor {
    NSLog(@"👾 Dylib chargé - Appuie sur 🔓 en jeu");
    CreateUI();
}

%hook SKPaymentQueue
- (void)addPayment:(SKPayment *)payment { %orig; }
%end