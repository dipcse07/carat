//
//  SettingsViewController.h
//  Carat
//
//  Created by Jonatan C Hamberg on 22/01/16.
//  Copyright © 2016 University of Helsinki. All rights reserved.
//

#import "BaseViewController.h"

@interface SettingsViewController : BaseViewController

@property (retain, nonatomic) IBOutlet UILabel *mobileNetworkType;
@property (retain, nonatomic) IBOutlet UILabel *batteryState;
@property (retain, nonatomic) IBOutlet UILabel *cpuUsage;
@property (retain, nonatomic) IBOutlet UILabel *screenBrightness;
@property (retain, nonatomic) IBOutlet UILabel *locationEnabled;
@property (retain, nonatomic) IBOutlet UILabel *bluetoothEnabled;
@property (retain, nonatomic) IBOutlet UILabel *wifiUsage;
@property (retain, nonatomic) IBOutlet UILabel *mobileUsage;
@property (retain, nonatomic) IBOutlet UILabel *deviceUptime;
@property (retain, nonatomic) IBOutlet UILabel *deviceSleepTime;
@property (retain, nonatomic) IBOutlet UILabel *deviceStorage;
@property (retain, nonatomic) IBOutlet UILabel *powerSaver;

@end