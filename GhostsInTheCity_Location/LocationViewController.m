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
@property (weak, nonatomic) IBOutlet UILabel *lastUpdateLabel;
@property (strong, nonatomic) GCDAsyncSocket *socket;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activity_indicator;
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UILabel *errorLabel;
@property (weak, nonatomic) IBOutlet MKMapView *locationMap;

@end

@implementation LocationViewController {
    NSDateFormatter *formatter;
    NSString *dateString;
    NSTimer *lastUpdateTimer;
    NSTimeInterval lastUpdateTimeInterval;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self.latitudeLabel setText:@"..."];
    [self.longitudeLabel setText:@"..."];
    
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss"];
    
    self.locationManager = [[CLLocationManager alloc] init];
    
    [self.locationManager requestAlwaysAuthorization];
    
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    
    // Set a movement threshold for new events.
    self.locationManager.distanceFilter = 1; // meters
    
    // Map settings
    self.locationMap.mapType = MKMapTypeSatellite;
    self.locationMap.hidden = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)start_sending_location:(id)sender {
    
    self.activity_indicator.hidden = NO;
    self.startButton.hidden = YES;
    
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    NSError *err = nil;
    if (![self.socket connectToHost:self.address_selected onPort:8080 withTimeout:10000 error:&err]) // Asynchronous!
    {
        self.activity_indicator.hidden = YES;
        self.errorLabel.text = [NSString stringWithFormat:@"%@", err];
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
        
        lastUpdateTimeInterval = [[NSDate date] timeIntervalSince1970];
        
        lastUpdateTimer = [NSTimer scheduledTimerWithTimeInterval: 1.0
                                                           target: self
                                                         selector:@selector(onTick:)
                                                         userInfo: nil repeats:YES];
        
        self.longitudeLabel.text = [NSString stringWithFormat:@"%.8f", newLocation.coordinate.longitude];
        self.latitudeLabel.text = [NSString stringWithFormat:@"%.8f", newLocation.coordinate.latitude];
        
        self.locationMap.showsUserLocation = YES;
        MKCoordinateRegion region =
        MKCoordinateRegionMakeWithDistance (
                                            newLocation.coordinate, 100, 100);
        [self.locationMap setRegion:region animated:NO];
        self.locationMap.hidden = NO;
        
        NSData *location_data = [[NSString stringWithFormat:@"%@,%@\r\n",self.latitudeLabel.text,self.longitudeLabel.text] dataUsingEncoding:NSUTF8StringEncoding];
        
        [self.socket writeData:location_data withTimeout:-1 tag:1];
    }
}

-(void) viewWillDisappear:(BOOL)animated {
    if ([self.navigationController.viewControllers indexOfObject:self]==NSNotFound) {
        [self.socket disconnect];
        [self.locationManager stopUpdatingLocation];
        [lastUpdateTimer invalidate];
    }
    [super viewWillDisappear:animated];
}

-(void)onTick:(NSTimer *)timer {
    
    self.lastUpdateLabel.text = [NSString stringWithFormat:@"%.1f seconds ago", [[NSDate date] timeIntervalSince1970] - lastUpdateTimeInterval];
    
}

@end
