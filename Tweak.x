#import <UIKit/UIKit.h>

static UIView *testView = nil;

static void ShowTestRectangle() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow) return;
        
        if (!testView) {
            testView = [[UIView alloc] initWithFrame:CGRectMake(50, 100, 100, 100)];
            testView.backgroundColor = [UIColor redColor];
            testView.layer.borderWidth = 2;
            testView.layer.borderColor = [UIColor whiteColor].CGColor;
            testView.layer.cornerRadius = 10;
            [keyWindow addSubview:testView];
        }
    });
}

%hook AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    
    // Afficher l'alerte de succès
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"ESP Box" 
                                                                       message:@"✅ DYLIB INJECTÉ !" 
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            ShowTestRectangle();
        }];
        [alert addAction:ok];
        
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    });
    
    return result;
}

%end