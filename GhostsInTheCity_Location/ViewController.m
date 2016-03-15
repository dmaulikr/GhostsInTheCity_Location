//
//  ViewController.m
//  GhostsInTheCity_Location
//
//  Created by Pietro Nompleggio on 08/03/16.
//  Copyright © 2016 Pietro Nompleggio. All rights reserved.
//

#import "ViewController.h"
#import <CoreLocation/CoreLocation.h>
#import "GCDWebServer.h"
#import "GCDWebServerDataResponse.h"
#import "GCDAsyncSocket.h"

#define WELCOME_MSG  0

@interface ViewController () <CLLocationManagerDelegate>

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (weak, nonatomic) IBOutlet UILabel *latitudeLabel;
@property (weak, nonatomic) IBOutlet UILabel *longitudeLabel;
@property (strong, nonatomic) GCDAsyncSocket *socket;
@property (strong, nonatomic) GCDAsyncSocket *serverSocket;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.locationManager = [[CLLocationManager alloc] init];
    
    [self.locationManager requestAlwaysAuthorization];
    
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    
    // Set a movement threshold for new events.
    self.locationManager.distanceFilter = 1; // meters
    
    self.serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    NSError *error = nil;
    if (![self.serverSocket acceptOnPort:8081 error:&error])
    {
        NSLog(@"Error open server socket: %@", error);
    }
    
    // Create server
    GCDWebServer* webServer = [[GCDWebServer alloc] init];
    
    // Add a handler to respond to GET requests on any URL
    [webServer addDefaultHandlerForMethod:@"GET"
                             requestClass:[GCDWebServerRequest class]
                             processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
                                 
                                 NSLog(@"Remote Address: %@",request.remoteAddressString);
                                 
                                 return [GCDWebServerDataResponse responseWithText:@"Hi, you want a real GPS position?"];
                                 
                             }];
    
    
    // Use convenience method that runs server on port 8080
    // until SIGINT (Ctrl-C in Terminal) or SIGTERM is received
    [webServer startWithPort:8080 bonjourName:[NSString stringWithFormat:@"GhostInTheCity_Location_by_%@",[[UIDevice currentDevice] name]]];
    
    //NSLog(@"Visit %@ in your web browser", webServer.serverURL);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)startLocation:(id)sender {
    
    [self.locationManager startUpdatingLocation];
}

#pragma mark - GCDAsyncSocketDelegate Server

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    // This method is executed on the socketQueue (not the main thread)
    NSString *welcomeMsg = @"Welcome\r\n";
    NSData *welcomeData = [welcomeMsg dataUsingEncoding:NSUTF8StringEncoding];
    
    [newSocket writeData:welcomeData withTimeout:-1 tag:WELCOME_MSG];
    
    [self.serverSocket disconnect];
    
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    NSError *err = nil;
    if (![self.socket connectToHost:[newSocket connectedHost] onPort:8080 error:&err]) // Asynchronous!
    {
        // If there was an error, it's likely something like "already connected" or "no delegate set"
        NSLog(@"Error Socket: %@", err);
    }

}

#pragma mark - GCDAsyncSocketDelegate Client

- (void)socket:(GCDAsyncSocket *)sender didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSLog(@"Cool, I'm connected! That was easy.");
    NSLog(@"AsyncSocket didConnectToHost: %@ port: %d",host, port);
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"didFailWithError: %@", error);
    UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"Error" message:@"Failed to get your location" preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:errorAlert animated:YES completion:nil];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    NSLog(@"didUpdateToLocation: %@", newLocation);
    CLLocation *currentLocation = newLocation;
    
    if (currentLocation != nil) {
        self.longitudeLabel.text = [NSString stringWithFormat:@"%.8f", currentLocation.coordinate.longitude];
        self.latitudeLabel.text = [NSString stringWithFormat:@"%.8f", currentLocation.coordinate.latitude];
    }
}

@end
