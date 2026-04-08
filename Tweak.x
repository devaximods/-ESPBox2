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

// ============ VARIABLE GLOBALE POUR ACTIVATION ============
static BOOL isESPActive = YES;  // Activé par défaut

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

// ============ ESP CONTAINER ============
static UIView *espContainer = nil;
static UIButton *toggleButton = nil;

static void SetupESP() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow) return;
        
        // Conteneur pour les boîtes ESP
        if (!espContainer) {
            espContainer = [[UIView alloc] initWithFrame:keyWindow.bounds];
            espContainer.backgroundColor = [UIColor clearColor];
            espContainer.userInteractionEnabled = NO;
            [keyWindow addSubview:espContainer];
        }
        
        // Bouton flottant ON/OFF
        if (!toggleButton) {
            toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
            toggleButton.frame = CGRectMake(20, 80, 80, 40);
            toggleButton.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
            toggleButton.layer.cornerRadius = 10;
            toggleButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            toggleButton.userInteractionEnabled = YES;
            
            // Mettre à jour l'apparence du bouton
            [toggleButton setTitle:isESPActive ? @"ESP: ON" : @"ESP: OFF" forState:UIControlStateNormal];
            [toggleButton setTitleColor:isESPActive ? [UIColor greenColor] : [UIColor redColor] forState:UIControlStateNormal];
            
            // Ajouter l'action
            [toggleButton addTarget:self action:@selector(toggleESP) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:toggleButton];
        }
    });
}

// Action pour activer/désactiver l'ESP
static void toggleESP() {
    isESPActive = !isESPActive;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [toggleButton setTitle:isESPActive ? @"ESP: ON" : @"ESP: OFF" forState:UIControlStateNormal];
        [toggleButton setTitleColor:isESPActive ? [UIColor greenColor] : [UIColor redColor] forState:UIControlStateNormal];
        
        // Si on désactive, effacer toutes les boîtes
        if (!isESPActive) {
            for (UIView *subview in espContainer.subviews) {
                if (subview.tag == 999) {
                    [subview removeFromSuperview];
                }
            }
        }
    });
}

static void DrawBox(CGPoint screenPos, float distance) {
    if (!espContainer || !isESPActive) return;
    
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

// ============ TROUVER LES REQUINS (À COMPLÉTER) ============
static NSArray *GetAllSharks() {
    // TODO: Implémenter la recherche des requins
    // Pour l'instant, on retourne un tableau vide
    
    // On va créer un requin de test pour vérifier que le système d'affichage marche
    // Dès que tu auras la bonne méthode, on remplace ça
    
    return @[];
}

// ============ MISE À JOUR ESP ============
static void UpdateESP() {
    if (!espContainer || !isESPActive) return;
    
    void* localPlayer = GetLocalPlayer();
    if (!localPlayer) return;
    
    vec3_t localPos = GetPlayerPosition(localPlayer);
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    
    // Récupérer tous les requins
    NSArray *sharks = GetAllSharks();
    
    // SI AUCUN REQUIN N'EST TROUVÉ, ON AFFICHE UN RECTANGLE DE TEST
    // Cela permet de savoir si le dylib est actif
    if (sharks.count == 0) {
        // Afficher un message de test en haut de l'écran
        static UILabel *testLabel = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!testLabel) {
                testLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 130, 200, 30)];
                testLabel.text = @"ESP ACTIF (aucun requin)";
                testLabel.textColor = [UIColor yellowColor];
                testLabel.font = [UIFont systemFontOfSize:12];
                testLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
                testLabel.layer.cornerRadius = 5;
                testLabel.textAlignment = NSTextAlignmentCenter;
                [espContainer addSubview:testLabel];
            }
        });
        return;
    } else {
        // Enlever le message de test si on trouve des requins
        dispatch_async(dispatch_get_main_queue(), ^{
            for (UIView *subview in espContainer.subviews) {
                if ([subview isKindOfClass:[UILabel class]] && subview.tag != 999) {
                    [subview removeFromSuperview];
                }
            }
        });
    }
    
    for (id shark in sharks) {
        void* sharkPtr = (__bridge void*)shark;
        if (!sharkPtr) continue;
        
        void* transform = GetTransform(sharkPtr);
        if (!transform) continue;
        
        vec3_t sharkPos = GetPositionFromTransform(transform);
        
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
