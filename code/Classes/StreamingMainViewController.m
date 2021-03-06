// The BSD 2-Clause License (aka "FreeBSD License")
// 
// Copyright (c) 2012, Benjamin Thiel
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met: 
// 
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer. 
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution. 
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//
//  StreamingMainViewController.m
//  snsrlog
//
//  Created by Benjamin Thiel on 02.07.11.
//

#import "StreamingMainViewController.h"
#import "PacketEncoderDecoder.h"
#import "StreamingLiveViewController.h"
#import "snsrlogAppDelegate.h"

@interface StreamingMainViewController ()

@property(nonatomic, copy) NSArray *serverIDs;
@property(nonatomic, retain) UIActivityIndicatorView *spinningWheel;
@property(nonatomic, retain) NSString *serverIDconnectingTo;

-(void)startSpinningWheelInRowAtIndexPath:(NSIndexPath *)row;
-(void)stopSpinningWheel;
-(NSIndexPath *)rowOfServerID:(NSString *)serverID;

-(void)adaptServerButtonStatus;

-(void)releaseOutletsAndSubviews;

@end

@implementation StreamingMainViewController

@synthesize serverButton, serverStatus, availableServers;
@synthesize serverIDs;
@synthesize spinningWheel, serverIDconnectingTo;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        [StreamingClient sharedInstance].delegate = self;
        [StreamingServer sharedInstance].delegate = self;
        
        self.serverIDconnectingTo = nil;
        
        //display them only on demand
        self.serverStatus.hidden = YES;
        self.availableServers.hidden = YES;
    }
    return self;
}

- (void)dealloc
{
    [StreamingClient sharedInstance].delegate = nil;
    [StreamingServer sharedInstance].delegate = nil;
    
    [self releaseOutletsAndSubviews];
    
    self.serverIDs = nil;
    self.serverIDconnectingTo = nil;
    
    [super dealloc];
}

- (void)releaseOutletsAndSubviews {
    
    self.serverButton = nil;
    self.serverStatus = nil;
    self.availableServers = nil;
    self.spinningWheel = nil;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle
-(void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault
                                                animated:YES];
    [[StreamingClient sharedInstance] start];
}

-(void)viewWillDisappear:(BOOL)animated {
    
    [super viewWillDisappear:animated];
    
    //Is the view disappearing because it is not hidden by the StreamingLiveView modalViewController?
    if ([StreamingClient sharedInstance].connectionState != Connected) {
        
        [[StreamingClient sharedInstance] stop];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    //to be displayed in the tableView while connecting
    self.spinningWheel = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease];
    
    //let the views represent the current status, as they might have been released by a memory warning
    [self adaptServerButtonStatus];
    [self serverStatusChanged];
    [self serverAvailabilityChanged];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
    [self releaseOutletsAndSubviews];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

//MARK: - reacting to buttons
-(IBAction)serverButtonPressed:(UISegmentedControl *)sender {
    
    if (![StreamingServer sharedInstance].isStarted) {
        
        [[StreamingServer sharedInstance] start];
        self.serverStatus.hidden = NO;
        
        //prevent the device from sleeping and activate the proximity sensor (which also turns off the display)
        snsrlogAppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
        [appDelegate preventAutoLock:YES];
        [appDelegate enableProximitySensing:YES];
        
    } else {
        
        [[StreamingServer sharedInstance] stop];
        self.serverStatus.hidden = YES;
        
        //allow the device to auto-lock itself again and disable proximity sensing
        snsrlogAppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
        [appDelegate preventAutoLock:NO];
        [appDelegate enableProximitySensing:NO];
    }
    [self adaptServerButtonStatus];
}

-(void)adaptServerButtonStatus {
    
    if ([StreamingServer sharedInstance].isStarted) {
        
        self.serverButton.backgroundColor = [UIColor redColor];
        [self.serverButton setTitle:@"Stop Streaming to Others" forState:UIControlStateNormal];
        
    } else {
        
        self.serverButton.backgroundColor = [BTFancyButton aestheticallyPleasingGreen];
        [self.serverButton setTitle:@"Start Streaming to Others" forState:UIControlStateNormal];
    }
}


//MARK: - StreamingClientDelegate
-(void)clientConnectionStatusChanged {
    
    ConnectionState clientState = [[StreamingClient sharedInstance] connectionState];
    
    switch (clientState) {
        
        case Connecting:
            [self startSpinningWheelInRowAtIndexPath:[self rowOfServerID:self.serverIDconnectingTo]];
            break;
        
        case Connected:
            [self stopSpinningWheel];
            StreamingLiveViewController *liveVC = [[StreamingLiveViewController alloc] initWithNibName:nil bundle:nil];
            [self presentModalViewController:liveVC animated:YES];
            [liveVC release];
            break;
        
        case Disconnected:
            [self stopSpinningWheel];
            [self dismissModalViewControllerAnimated:YES];
            break;
            
        case NetworkUnavailable:
            /*
             * In order to save screen estate and complexity, we fumble with the
             * server status display although we are the client. Dirty code is dirty.
             */
            if (![StreamingServer sharedInstance].isStarted) {
                
                self.serverStatus.text = @"No Bluetooth or WiFi network available!";
                self.serverStatus.textColor = [UIColor redColor];
                self.serverStatus.hidden = NO;
            
            } else {
                
                //the server will notice that there is no network anyway and change serverStatus appropriately
            }
            break; 
        
        default:
            [self stopSpinningWheel];
            break;
    }
    
    //hide the possibly previously set "no network" label
    if (clientState != NetworkUnavailable && ![StreamingServer sharedInstance].isStarted) {
        
        self.serverStatus.hidden = YES;
    }
}

-(void)serverAvailabilityChanged {
    
    //prevent querying of our array while it is updated
    self.availableServers.dataSource = nil;
    
    //copy the array
    self.serverIDs = [StreamingClient sharedInstance].availablePeers;
    
    //(un)hide the table view
    if ([self.serverIDs count] > 0) {
        
        self.availableServers.hidden = NO;
        
    } else {
        
        self.availableServers.hidden = YES;
    }
    
    //act as data source again
    self.availableServers.dataSource = self;
    [self.availableServers reloadData];
}

//MARK: - StreamingServerDelegate
-(void)serverStatusChanged {
    
    switch ([[StreamingServer sharedInstance] connectionState]) {
        
        case NetworkUnavailable:
            self.serverStatus.text = @"No Bluetooth or WiFi network available!";
            self.serverStatus.textColor = [UIColor redColor];
            break; 
            
        case Disconnected:
            self.serverStatus.text = @"Waiting for connections...";
            self.serverStatus.textColor = [UIColor darkGrayColor];

            break;
        
        case Connecting:
            self.serverStatus.text = @"Connecting...";
            self.serverStatus.textColor = [UIColor orangeColor];
            break; 
        
        case Connected:
            self.serverStatus.text = [NSString stringWithFormat:@"Connected to \"%@\".", [StreamingServer sharedInstance].currentClientScreenName];
            self.serverStatus.textColor = [UIColor colorWithRed:0 green:0.7 blue:0 alpha:1];//dark green
            
            break;
            
        default:
            self.serverStatus.text = @"An error occured, trying to recover...";
            self.serverStatus.textColor = [UIColor blackColor];
            break;
    }
}

//MARK: - spinning wheel

-(NSIndexPath *)rowOfServerID:(NSString *)serverID {
    
    NSUInteger indexOfEntry = [serverIDs indexOfObject:serverID];
    
    if (indexOfEntry != NSNotFound) {
        
        return [NSIndexPath indexPathForRow:indexOfEntry inSection:0];
    
    } else {
        
        return nil;
    }
}

-(void)startSpinningWheelInRowAtIndexPath:(NSIndexPath *)row { 
    
    UITableViewCell *cell = [self.availableServers cellForRowAtIndexPath:row];
    cell.accessoryView = self.spinningWheel;
    
    [self.spinningWheel startAnimating];

}

-(void)stopSpinningWheel {
    
    self.serverIDconnectingTo = nil;
    
    UITableViewCell *cell = (UITableViewCell *) self.spinningWheel.superview;
    
    [self.spinningWheel stopAnimating];
    
    //restore the cell
    [self.spinningWheel removeFromSuperview];
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

#pragma mark -
#pragma mark Table View Data Source

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    NSString *serverID = [self.serverIDs objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [[StreamingClient sharedInstance] displayNameForServer:serverID];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    //show spinning wheel?
    if (([serverID isEqualToString:self.serverIDconnectingTo]) && [self.spinningWheel isAnimating]) {

        cell.accessoryView = self.spinningWheel;
        
    } else {
        
        cell.accessoryView = nil;

    }
    
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return [self.serverIDs count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    
    if (section == 0) {
        
        return @"Available devices to stream from:";
    } else {
        return nil;
    }
}

#pragma mark -
#pragma mark Table View Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *serverID = [serverIDs objectAtIndex:indexPath.row];
    
    //remember where to display the spinning wheel, actual displaying takes place in ClientConnectionStatusChanged
    self.serverIDconnectingTo = serverID;
    
    [[StreamingClient sharedInstance] connectTo:serverID];
    
    [self.availableServers deselectRowAtIndexPath:indexPath animated:YES];
}

@end
