#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>

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
        
        vec3_t localPos = GetPosition(localPlayer);
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

static void SetupUI() {
    UIWindow *keyWindow = GetKeyWindow();
    if (!keyWindow) return;
    
    espContainer = [[UIView alloc] initWithFrame:keyWindow.bounds];
    espContainer.backgroundColor = [UIColor clearColor];
    espContainer.userInteractionEnabled = NO;
    [keyWindow addSubview:espContainer];
    
    UIButton *toggleBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    toggleBtn.frame = CGRectMake(20, 100, 120, 40);
    [toggleBtn setTitle:@"ESP LINE: OFF" forState:UIControlStateNormal];
    toggleBtn.backgroundColor = [UIColor redColor];
    [toggleBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [toggleBtn addTarget:self action:@selector(toggleESPLine) forControlEvents:UIControlEventTouchUpInside];
    [keyWindow addSubview:toggleBtn];
}

void toggleESPLine() {
    espLineEnabled = !espLineEnabled;
    UIWindow *keyWindow = GetKeyWindow();
    UIButton *btn = nil;
    for (UIView *v in keyWindow.subviews) {
        if ([v isKindOfClass:[UIButton class]]) btn = (UIButton*)v;
    }
    if (espLineEnabled) {
        [btn setTitle:@"ESP LINE: ON" forState:UIControlStateNormal];
        btn.backgroundColor = [UIColor greenColor];
        if (!gameTimer) StartGameLoop();
    } else {
        [btn setTitle:@"ESP LINE: OFF" forState:UIControlStateNormal];
        btn.backgroundColor = [UIColor redColor];
    }
}

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        SetupUI();
        isGameReady = YES;
    });
}