#import "AppDelegate.h"
#import "CopyExperiments.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;

    NSLog(@"CopyLab: begin");
    CopyExperimentsRun();
    NSLog(@"CopyLab: end");

    // This target is a repeatable lab runner rather than a user-facing app.
    dispatch_async(dispatch_get_main_queue(), ^{
        exit(EXIT_SUCCESS);
    });
    return YES;
}

@end
