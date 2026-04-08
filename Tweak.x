#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

// ============ OFFSETS (remplace par TES valeurs) ============
#define OFFSET_GET_LOCAL_PLAYER   0x65BA5E8
#define OFFSET_GET_TRANSFORM      0x628EE64
#define OFFSET_WORLD_TO_SCREEN    0x62430C4

// ============ STRUCTURES ============
typedef struct {
    float x;
    float y;
    float z;
} vec3_t;

typedef struct {
    float x;
    float y;
} vec2_t;

// ============ FONCTIONS DE BASE ============

static void* GetLocalPlayer() {
    void* (*func)() = (void* (*)())OFFSET_GET_LOCAL_PLAYER;
    return func();
}

static void* GetTransform(void* obj) {
    void* (*func)(void*) = (void* (*)(void*))OFFSET_GET_TRANSFORM;
    return func(obj);
}

static vec3_t GetPositionFromTransform(void* transform) {
    vec3_t pos;
    pos.x = *(float*)((uintptr_t)transform + 0x40);
    pos.y = *(float*)((uintptr_t)transform + 0x44);
    pos.z = *(float*)((uintptr_t)transform + 0x48);
    return pos;
}

static vec3_t GetPlayerPosition(void* player) {
    void* transform = GetTransform(player);
    if (transform) {
        return GetPositionFromTransform(transform);
    }
    vec3_t zero = {0,0,0};
    return zero;
}

static vec2_t WorldToScreenPoint(vec3_t worldPos) {
    vec2_t (*func)(vec3_t) = (vec2_t (*)(vec3_t))OFFSET_WORLD_TO_SCREEN;
    return func(worldPos);
}

// ============ POUR ACCÉDER À oldSharks ============
// Il faut trouver l'instance de la classe qui contient oldSharks
// En attendant, on va hooker la méthode <OnEnableCor>b__2 qui reçoit chaque requin

static NSMutableArray *allSharks = nil;

// Hooker la méthode qui reçoit chaque requin
%hook Shark.<>c__DisplayClass57_0

- (void)<OnEnableCor>b__2:(void*)shark {
    %orig;
    
    // Ajouter le requin à notre liste
    if (!allSharks) allSharks = [NSMutableArray new];
    if (shark && ![allSharks containsObject:[NSValue valueWithPointer:shark]]) {
        [allSharks addObject:[NSValue valueWithPointer:shark]];
        NSLog(@"[ESP] Shark added to list");
    }
}

%end

// ============ ESP CONTAINER ============
static UIView *espContainer = nil;

static void SetupESP() {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (espContainer) return;
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow) return;
        
        espContainer = [[UIView alloc] initWithFrame:keyWindow.bounds];
        espContainer.backgroundColor = [UIColor clearColor];
        espContainer.userInteractionEnabled = NO;
        [keyWindow addSubview:espContainer];
    });
}

static void DrawBox(CGPoint screenPos, float distance) {
    if (!espContainer) return;
    
    float boxSize = 80.0f / distance;
    if (boxSize < 15) boxSize = 15;
    if (boxSize > 60) boxSize = 60;
    
    CGRect boxRect = CGRectMake(screenPos.x - boxSize/2, 
                                 screenPos.y - boxSize/1.5, 
                                 boxSize, 
                                 boxSize);
    
    UIView *box = [[UIView alloc] initWithFrame:boxRect];
    box.backgroundColor = [UIColor clearColor];
    box.layer.borderWidth = 2;
    box.layer.borderColor = [UIColor redColor].CGColor;
    box.layer.cornerRadius = 4;
    box.tag = 999;
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, -18, boxSize, 15)];
    label.text = [NSString stringWithFormat:@"🦈 %.0fm", distance];
    label.textColor = [UIColor redColor];
    label.font = [UIFont boldSystemFontOfSize:10];
    label.textAlignment = NSTextAlignmentCenter;
    [box addSubview:label];
    
    [espContainer addSubview:box];
}

static void ClearBoxes() {
    if (!espContainer) return;
    for (UIView *subview in espContainer.subviews) {
        if (subview.tag == 999) {
            [subview removeFromSuperview];
        }
    }
}

// ============ PARCOURIR TOUS LES REQUINS ============
static void UpdateESP() {
    if (!espContainer) return;
    if (!allSharks || allSharks.count == 0) return;
    
    void* localPlayer = GetLocalPlayer();
    if (!localPlayer) return;
    
    vec3_t localPos = GetPlayerPosition(localPlayer);
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    
    for (NSValue *sharkValue in allSharks) {
        void* shark = [sharkValue pointerValue];
        if (!shark) continue;
        
        // Récupérer la position du requin
        void* transform = GetTransform(shark);
        if (!transform) continue;
        
        vec3_t sharkPos = GetPositionFromTransform(transform);
        
        // Distance
        float dx = sharkPos.x - localPos.x;
        float dz = sharkPos.z - localPos.z;
        float distance = sqrt(dx*dx + dz*dz);
        
        if (distance < 30 && distance > 1) {
            vec2_t screenPos = WorldToScreenPoint(sharkPos);
            
            if (screenPos.x > 0 && screenPos.x < screenSize.width &&
                screenPos.y > 0 && screenPos.y < screenSize.height) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    DrawBox(CGPointMake(screenPos.x, screenPos.y), distance);
                });
            }
        }
    }
}

// ============ HOOK PRINCIPAL ============
%hook AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    
    SetupESP();
    
    // Mettre à jour l'ESP toutes les 0.1 secondes
    [NSTimer scheduledTimerWithTimeInterval:0.1
                                     repeats:YES
                                       block:^(NSTimer *timer) {
                                           dispatch_async(dispatch_get_main_queue(), ^{
                                               ClearBoxes();
                                           });
                                           UpdateESP();
                                       }];
    return result;
}

%end

%hook UIWindow

- (void)layoutSubviews {
    %orig;
    if (espContainer) {
        [espContainer removeFromSuperview];
        espContainer = nil;
        SetupESP();
    }
}

%end
