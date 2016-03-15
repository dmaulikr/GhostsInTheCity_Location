//
//  LocationViewController.m
//  GhostsInTheCity_Location
//
//  Created by Pietro Nompleggio on 10/03/16.
//  Copyright © 2016 Pietro Nompleggio. All rights reserved.
//

#import "LocationViewController.h"
#import <CoreLocation/CoreLocation.h>
#import "GCDAsyncSocket.h"

@interface LocationViewController () <CLLocationManagerDelegate,GCDAsyncSocketDelegate>

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (weak, nonatomic) IBOutlet UILabel *latitudeLabel;
@property (weak, nonatomic) IBOutlet UILabel *longitudeLabel;
@property (strong, nonatomic) GCDAsyncSocket *socket;

@end

@implementation LocationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self.latitudeLabel setText:@""];
    [self.longitudeLabel setText:@""];
    
    self.locationManager = [[CLLocationManager alloc] init];
    
    [self.locationManager requestAlwaysAuthorization];
    
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    
    // Set a movement threshold for new events.
    self.locationManager.distanceFilter = 1; // meters
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)start_sending_location:(id)sender {
    
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    NSError *err = nil;
    if (![self.socket connectToHost:self.address_selected onPort:8080 error:&err]) // Asynchronous!
    {
        // If there was an error, it's likely something like "already connected" or "no delegate set"
        NSLog(@"Error Socket: %@", err);
    }
}

#pragma mark - GCDAsyncSocketDelegate Client

- (void)socket:(GCDAsyncSocket *)sender didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSLog(@"AsyncSocket didConnectToHost: %@ port: %d",host, port);
    
    [self.locationManager startUpdatingLocation];
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
    
    if (newLocation != nil) {
        self.longitudeLabel.text = [NSString stringWithFormat:@"%.8f", newLocation.coordinate.longitude];
        self.latitudeLabel.text = [NSString stringWithFormat:@"%.8f", newLocation.coordinate.latitude];
        
        NSData *location_data = [[NSString stringWithFormat:@"%@,%@\r\n",self.latitudeLabel.text,self.longitudeLabel.text] dataUsingEncoding:NSUTF8StringEncoding];
        
        [self.socket writeData:location_data withTimeout:-1 tag:1];
    }
}

@end
