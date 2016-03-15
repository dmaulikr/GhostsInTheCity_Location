//
//  DiscoveryService.m
//  GhostsInTheCity_Location
//
//  Created by Pietro Nompleggio on 10/03/16.
//  Copyright © 2016 Pietro Nompleggio. All rights reserved.
//

#import "DiscoveryService.h"
#include <arpa/inet.h>
#import "LocationViewController.h"

@interface DiscoveryService () <NSNetServiceBrowserDelegate,NSNetServiceDelegate>

@property (nonatomic, strong) NSNetServiceBrowser *serviceBrowser;
@property (nonatomic, strong) NSNetService *serviceResolver;
@property (nonatomic, strong) NSMutableArray* services;
@property (nonatomic, strong) NSString *address_selected;

@end

@implementation DiscoveryService

- (IBAction)openIPView:(id)sender {
    
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:@"Insert IP"
                                          message:@""
                                          preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField)
     {
         textField.placeholder = NSLocalizedString(@"IP", @"0.0.0.0");
     }];
    
    UIAlertAction *okAction = [UIAlertAction
                               actionWithTitle:NSLocalizedString(@"OK", @"OK action")
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *action)
                               {
                                   UITextField *ip = alertController.textFields.firstObject;
                                   
                                   self.address_selected = ip.text;
                                   [self performSegueWithIdentifier:@"location_view" sender:self];
                                   
                               }];
    
    [alertController addAction:okAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
    

}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.services = [[NSMutableArray alloc] init];
    self.serviceBrowser = [[NSNetServiceBrowser alloc] init];
    self.serviceBrowser.delegate = self;
    
    self.title = @"Searching Service";
    [self searchForBonjourServices];
}

- (void)searchForBonjourServices
{
    [self.serviceBrowser searchForServicesOfType:@"_http._tcp" inDomain:@"local"];
}

#pragma mark UITableViewDataSourceDelegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    int count = (int)[self.services count];
    if (count == 0) {
        return 1;
    } else {
        return count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *simpleTableIdentifier = @"SimpleTableItem";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
    }
    
    int count = (int)[self.services count];
    NSString* displayString;
    
    if (count == 0) {
        displayString = @"Searching...";
    } else {
        NSNetService *service = [self.services objectAtIndex:indexPath.row];
        displayString = [service name];
    }
    
    cell.textLabel.text = displayString;
    cell.backgroundColor = [UIColor colorWithRed:51 green:51 blue:51 alpha:0];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.textAlignment = NSTextAlignmentCenter;
    
    return cell;
}

#pragma mark UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    if (self.serviceResolver) {
        [self.serviceResolver stop];
    }
    
    int count = (int)[self.services count];
    if (count != 0) {
        self.serviceResolver = [self.services objectAtIndex:indexPath.row];
        self.serviceResolver.delegate = self;
        [self.serviceResolver resolveWithTimeout:0.0];
    }
}

#pragma mark NSNetServiceDelegate
- (void)netServiceDidResolveAddress:(NSNetService *)service {
    [self.serviceResolver stop];
    
    NSLog(@"%ld", (long)service.port);
    NSLog(@"%@",service.name);
    
    [self addressesComplete:[service addresses] forServiceType:[service type]];
    
}


- (void) addressesComplete:(NSArray *)addresses forServiceType:(NSString *)serviceType
{
    
    // Perform appropriate logic to ensure that [netService addresses]
    // contains the appropriate information to connect to the service
    
    NSData *myData = nil;
    myData = [addresses objectAtIndex:0];
    
    NSString *addressString;
    int port=0;
    struct sockaddr *addressGeneric;
    
    addressGeneric = (struct sockaddr *) [myData bytes];
    
    BOOL found = NO;
    
    switch( addressGeneric->sa_family ) {
        case AF_INET: {
            struct sockaddr_in *ip4;
            char dest[INET_ADDRSTRLEN];
            ip4 = (struct sockaddr_in *) [myData bytes];
            port = ntohs(ip4->sin_port);
            self.address_selected = [NSString stringWithFormat:@"%s", inet_ntop(AF_INET, &ip4->sin_addr, dest, sizeof dest)];
            addressString = [NSString stringWithFormat: @"IP4: %s Port: %d", inet_ntop(AF_INET, &ip4->sin_addr, dest, sizeof dest),port];
            found = YES;
        }
            break;
            
        case AF_INET6: {
            struct sockaddr_in6 *ip6;
            char dest[INET6_ADDRSTRLEN];
            ip6 = (struct sockaddr_in6 *) [myData bytes];
            port = ntohs(ip6->sin6_port);
            self.address_selected = [NSString stringWithFormat:@"%s",inet_ntop(AF_INET6, &ip6->sin6_addr, dest, sizeof dest)];
            addressString = [NSString stringWithFormat: @"IP6: %s Port: %d",  inet_ntop(AF_INET6, &ip6->sin6_addr, dest, sizeof dest),port];
            found = YES;
        }
            break;
        default:
            addressString=@"Unknown family";
            break;
    }
    
    if (found) {
        
        NSLog(@"Client Address: %@",addressString);
        [self performSegueWithIdentifier:@"location_view" sender:self];
    } else {
        NSLog(@"Not valid Address Found.");
    }
    
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"location_view"]) {
        LocationViewController *destViewController = segue.destinationViewController;
        destViewController.address_selected = self.address_selected;
    }
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
    [self.serviceResolver stop];
}

#pragma mark NSNetserviceBrowserDelegate
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    [self.services addObject:aNetService];
    
    if (!moreComing) {
        [self.tableView reloadData];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreServicesComing
{
    if (self.serviceResolver && [aNetService isEqual:self.serviceResolver]) {
        [self.serviceResolver stop];
    }
    
    [self.services removeObject:aNetService];
    if (!moreServicesComing) {
        [self.tableView reloadData];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
