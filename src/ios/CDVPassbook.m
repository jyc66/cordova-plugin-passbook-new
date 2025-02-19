#import "CDVPassbook.h"
#import <Cordova/CDV.h>
#import <PassKit/PassKit.h>

typedef void (^AddPassResultBlock)(PKPass *pass, BOOL added);

@interface CDVPassbook()<PKAddPassesViewControllerDelegate>

@property (nonatomic, retain) PKPass *lastPass;
@property (nonatomic, copy) AddPassResultBlock lastAddPassCallback;

- (BOOL)ensureAvailability:(CDVInvokedUrlCommand*)command;
- (void)sendPassResult:(PKPass*)pass added:(BOOL)added command:(CDVInvokedUrlCommand*)command;
- (void)sendError:(NSError*)error command:(CDVInvokedUrlCommand*)command;
- (void)downloadPass:(NSURL*) url
          HTTPMethod: (NSString*)HTTPMethod
             headers:(NSDictionary * _Nullable)headers
             params:(NSDictionary * _Nullable)params
             success:(AddPassResultBlock)successBlock
               error:(void (^)(NSError *error))errorBlock;
- (void)tryAddPass:(NSData*)data success:(AddPassResultBlock)successBlock error:(void (^)(NSError *error))errorBlock;
- (UIViewController*) getTopMostViewController;

@end

@implementation CDVPassbook

@synthesize lastPass;
@synthesize lastAddPassCallback;

/*- (BOOL)shouldOverrideLoadWithRequest:(NSURLRequest*)request navigationType:(UIWebViewNavigationType)navigationType
{
    if(PKPassLibrary.isPassLibraryAvailable && [request.URL.pathExtension isEqualToString:@"pkpass"]) {
        [self downloadPass:request.URL headers:nil success:nil error:nil];
        return YES;
    }
    
    return NO;
}*/

+ (BOOL)available
{
    BOOL available = [PKPassLibrary isPassLibraryAvailable];
    if ([PKAddPassesViewController respondsToSelector:@selector(canAddPasses)]) {
        available = available && [PKAddPassesViewController performSelector:@selector(canAddPasses)];
    }
    return available;
}

- (void)available:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:[CDVPassbook available]];
    [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
}

- (void)passExists:(CDVInvokedUrlCommand*)command
{
    if(![self ensureAvailability:command]) {
        return;
    }
    
    NSString* passIdentifier;
    NSString* passSerial;
    
    id callData = [command argumentAtIndex:0];

    if ([callData isKindOfClass:[NSDictionary class]]) {
        passIdentifier = callData[@"passIdentifier"];
        passSerial     = callData[@"passSerial"];
    }

    if(!passIdentifier) {
        [self sendError:[NSError errorWithDomain:@"CDVPassbook" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Pass identifier is required"}] command:command];
        return;
    }
    if(!passSerial) {
        [self sendError:[NSError errorWithDomain:@"CDVPassbook" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Pass serial is required"}] command:command];
        return;
    }
    PKPassLibrary *passLibrary = [[PKPassLibrary alloc] init];
    PKPass *pass = [passLibrary passWithPassTypeIdentifier:passIdentifier serialNumber:passSerial];


    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:pass!=nil];
    [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
}

- (void)downloadPass:(CDVInvokedUrlCommand*)command
{
    if(![self ensureAvailability:command]) {
        return;
    }
    
    id callData = [command argumentAtIndex:0];
    
    NSURL *url;
    NSDictionary *headers;
    NSDictionary *params;
    NSString* HTTPMethod;
    
    if ([callData isKindOfClass:[NSDictionary class]]) {
        
        url     = [NSURL URLWithString:callData[@"url"] ];
        HTTPMethod = callData[@"HTTPMethod"];
        headers = callData[@"headers"];
        params = callData[@"params"];
    }
    else { // let assume that is a string
        NSString *urlStr = [command argumentAtIndex:0];
        url = [NSURL URLWithString:urlStr];
    }
    if(!url) {
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_MALFORMED_URL_EXCEPTION];
        [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
        return;
    }
    [self downloadPass:url HTTPMethod:HTTPMethod headers:headers params:params success:^(PKPass *pass, BOOL added){
        [self sendPassResult:pass added:added command:command];
    } error:^(NSError *error) {
        [self sendError:error command:command];
    }];
}

- (void)addPass:(CDVInvokedUrlCommand*)command
{
    if(![self ensureAvailability:command]) {
        return;
    }
    
    NSString *fileStr = [command argumentAtIndex:0];
    if (!fileStr) {
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"no file provided"];
        [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
        return;
    }
    
    NSURL *url = [NSURL URLWithString:fileStr];
    if (!url) {
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"no valid file provided"];
        [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
        return;
    }
    
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data) {
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION];
        [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
        return;
    }
    
    [self tryAddPass:data success:^(PKPass *pass, BOOL added) {
        [self sendPassResult:pass added:added command:command];
    } error:^(NSError *error) {
        [self sendError:error command:command];
    }];
}

- (void)openPass:(CDVInvokedUrlCommand *)command
{
    if(![self ensureAvailability:command]) {
        return;
    }
    
    NSURL *url = nil;
    id argument = [command argumentAtIndex:0];
    if ([argument isKindOfClass:NSDictionary.class]) {
        url = [NSURL URLWithString:argument[@"passURL"]];
    } else if ([argument isKindOfClass:NSString.class]) {
        url = [NSURL URLWithString:argument];
    } else {
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No Pass URL provided"];
        [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
        return;
    }
    
    if (!url) {
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_MALFORMED_URL_EXCEPTION];
        [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
        return;
    }
    
    BOOL opened = [[UIApplication sharedApplication] openURL:url];
    if (opened) {
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];

    } else {
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Could not open Pass"];
        [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
    }
    
}

- (BOOL)ensureAvailability:(CDVInvokedUrlCommand*)command
{
    if(![CDVPassbook available]) {
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_INVALID_ACTION messageAsString:@"Passbook is not available on this device"];
        [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
        return NO;
    }
    return YES;
}

- (void)sendPassResult:(PKPass*)pass added:(BOOL)added command:(CDVInvokedUrlCommand*)command
{
    NSDictionary *data = @{@"added": [NSNumber numberWithBool:added],
                           @"pass":@{
                                   @"passTypeIdentifier": pass.passTypeIdentifier,
                                   @"serialNumber": pass.serialNumber,
                                   @"passURL": pass.passURL.absoluteString
                                   }
                           };
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:data];
    [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
}

- (void)sendError:(NSError*)error command:(CDVInvokedUrlCommand*)command{
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
    [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
}

- (void)tryAddPass:(NSData*)data success:(AddPassResultBlock)successBlock error:(void (^)(NSError *error))errorBlock
{
    NSError *error = nil;
    PKPass *pass = [[PKPass alloc] initWithData:data error:&error];
    if(!pass) {
        if(errorBlock) {
            errorBlock(error);
        }
        return;
    }
    
    self.lastPass = pass;
    self.lastAddPassCallback = successBlock;
    
    PKAddPassesViewController *c = [[PKAddPassesViewController alloc] initWithPass:pass];
    c.delegate = self;
    
    [[self getTopMostViewController] presentViewController:c animated:YES completion:nil];
}

- (UIViewController*) getTopMostViewController {
    UIViewController *presentingViewController = [[UIApplication sharedApplication] keyWindow].rootViewController;
    while (presentingViewController.presentedViewController != nil) {
        presentingViewController = presentingViewController.presentedViewController;
    }
    return presentingViewController;
}

- (void)downloadPass:(NSURL*) url HTTPMethod: (NSString*)HTTPMethod headers:(NSDictionary * _Nullable)headers params:(NSDictionary * _Nullable)params success:(AddPassResultBlock)successBlock error:(void (^)(NSError *error))errorBlock
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20.0];
    // Fake User-Agent to be recognized as Passbook app, so that we directly get the pkpass file (when possible)
    [request addValue:@"Passbook/1.0 CFNetwork/672.0.2 Darwin/14.0.0" forHTTPHeaderField:@"User-Agent"];
    if( HTTPMethod != nil ) {
        request.HTTPMethod = HTTPMethod;
    }
    
    if( headers != nil ) {
        
        for (NSString* key in headers) {
            id value = headers[key];
            [request addValue:value forHTTPHeaderField:key];
        }
 
    }

    if( params != nil ) {
        NSMutableString* postBody = [NSMutableString string];
        for (NSString* key in params) {
            id value = params[key];
            if( [postBody length] > 1 ) {
                [postBody appendString: @"&"];
            }
            [postBody appendFormat:@"%@=%@", key, value];
        }

        [request setHTTPBody:[postBody dataUsingEncoding:NSUTF8StringEncoding]];

 
    }
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        [self tryAddPass:data success:successBlock error:errorBlock];
    }];
}



#pragma mark - PKAddPassesViewControllerDelegate

-(void)addPassesViewControllerDidFinish:(PKAddPassesViewController *)controller
{
    [controller dismissViewControllerAnimated:YES completion:^{
        if (self.lastAddPassCallback && self.lastPass) {
            BOOL passAdded = [[[PKPassLibrary alloc] init] containsPass:self.lastPass];
            self.lastAddPassCallback(self.lastPass, passAdded);
            self.lastAddPassCallback = nil;
            self.lastPass = nil;
        }
    }];
}

@end
