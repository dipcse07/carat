//
//  DashBoardViewController.m
//  Carat
//
//  Created by Jarno Petteri Laitinen on 29/09/15.
//  Copyright © 2015 University of Helsinki. All rights reserved.
//

#import "DashBoardViewController.h"

#import "Utilities.h"
#import "Flurry.h"
#import "CoreDataManager.h"
#import "CommunicationManager.h"
#import "UIDeviceHardware.h"
#import "Globals.h"
#import "UIImageDoNotCache.h"
#import "CaratConstants.h"

@implementation DashBoardViewController{
}

#pragma mark - View Life Cycle methods
- (id) initWithNibName: (NSString *) nibNameOrNil
                bundle: (NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self->MAX_LIFE = 1209600;
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [_shareBar setHidden:YES];
    
    [_bugsBtn setButtonImage:[UIImage imageNamed:@"bug_icon"]];
    [_bugsBtn setButtonExtraInfo:@"7"];
    [_bugsBtn setButtonTitle:NSLocalizedString(@"Bugs", nil)];
    
    [_hogsBtn setButtonImage:[UIImage imageNamed:@"battery_icon"]];
    [_hogsBtn setButtonExtraInfo:@"4"];
    [_hogsBtn setButtonTitle:NSLocalizedString(@"Hogs", nil)];
    
    [_statisticsBtn setButtonImage:[UIImage imageNamed:@"globe_icon"]];
    [_statisticsBtn setButtonExtraInfo:@"VIEW"];
    [_statisticsBtn setButtonTitle:NSLocalizedString(@"Statistics", nil)];
    
    [_actionsBtn setButtonImage:[UIImage imageNamed:@"action_icon"]];
    [_actionsBtn setButtonExtraInfo:@"4"];
    [_actionsBtn setButtonTitle:NSLocalizedString(@"Actions", nil)];
}


- (void)loadView
{
    [super loadView];
}

- (void)viewWillAppear:(BOOL)animated
{
    //[self.navigationController setNavigationBarHidden:YES animated:YES];
    NSString *title = [super.navigationItem title];
    NSLog(@"title: %@", title);
    NSString *locallizedTitle = [NSLocalizedString(title, nil) uppercaseString];
    NSLog(@"locallizedTitle: %@", locallizedTitle);
    [super.navigationItem setTitle:locallizedTitle];
    
    self.view.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    [super viewWillAppear:animated];
    [self updateView];
    
    // UPDATE REPORT DATA
    if ([[CommunicationManager instance] isInternetReachable] == YES && // online
        ![self isFresh] && // need to update
        [[CoreDataManager instance] getReportUpdateStatus] == nil) // not already updating
    {
        [[CoreDataManager instance] updateLocalReportsFromServer];
        [self.progressBar startAnimating];
    } else if ([[CommunicationManager instance] isInternetReachable] == NO) {
        DLog(@"Starting without reachability; setting notification.");
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNetworkStatus:) name:kUpdateNetworkStatusNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sampleCountUpdated:) name:kSamplesSentCountUpdateNotification object:nil];
    
    [self updateNetworkStatus:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if ([[CoreDataManager instance] getReportUpdateStatus] == nil) {
        // For this screen, let's put sending samples/registrations here so that we don't conflict
        // with the report syncing (need to limit memory/CPU/thread usage so that we don't get killed).
        [[CoreDataManager instance] checkConnectivityAndSendStoredDataToServer];
        [self.progressBar startAnimating];
    }
    
    [self loadDataWithHUD:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(loadDataWithHUD:)
                                                 name:NSLocalizedString(@"CCDMReportUpdateStatusNotification", nil)
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSLocalizedString(@"CCDMReportUpdateStatusNotification", nil) object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kUpdateNetworkStatusNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kSamplesSentCountUpdateNotification object:nil];
}

- (void)updateView
{
    // J-Score
    int vScore = (MIN( MAX([[CoreDataManager instance] getJScore], -1.0), 1.0)*100);
    // Expected Battery Life
    NSTimeInterval eb; // expected life in seconds
    double jev = [[[CoreDataManager instance] getJScoreInfo:YES] expectedValue];
    if (jev > 0) eb = MIN(MAX_LIFE,100/jev);
    else eb = MAX_LIFE;
    NSString *vBatteryLife = [[Utilities doubleAsTimeNSString:eb] stringByTrimmingCharactersInSet:
                              [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    //Last updated
    [self sampleCountUpdated:nil];
    
    [self.scoreView setScore:vScore];
    self.batteryLastLabel.text = vBatteryLife;
    
    [self.view setNeedsDisplay];
}

-(void)sampleCountUpdated:(NSNotification*)notification{
    // Last Updated
    [self.progressBar stopAnimating];
    NSTimeInterval howLong = [[NSDate date] timeIntervalSinceDate:[[CoreDataManager instance] getLastReportUpdateTimestamp]];
    self.updateLabel.text = [Utilities formatNSTimeIntervalAsUpdatedNSString:howLong];
    [self.updateLabel setNeedsDisplay];
}


#pragma mark - Controller specific helpfull UI mehtods
-(void)setTextLabel:(UILabel*) label text:(NSString *)text top:(CGFloat)top
{
     CGFloat fontSize = 20.0f;
     UIFont *font = [UIFont fontWithName:@"HelveticaNeue" size:fontSize];
    
    label.frame = [self getTextFrame:text font:font top:top];
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.numberOfLines = 0;
    label.font = font;
    label.text = text;
  }

-(CGRect)getTextFrame:(NSString *)text font:(UIFont *) font top:(CGFloat)top
{
    NSDictionary *attributes = @{NSFontAttributeName: font};
    CGRect textSize = [text boundingRectWithSize:CGSizeMake(UI_SCREEN_W, CGFLOAT_MAX)
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:attributes
                                         context:nil];
    CGRect textRect = CGRectMake((UI_SCREEN_W / 2.0) - textSize.size.width/2.0, top, textSize.size.width, textSize.size.height);
    return textRect;
}

- (NSString *) getJScoreString
{
    NSNumber *jScore = [NSNumber numberWithInt:(int)(MIN( MAX([[CoreDataManager instance] getJScore], -1.0), 1.0)*100)];
    return [NSString stringWithFormat:NSLocalizedString(@"JScoreShareMessage", nil), [jScore stringValue]];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    switch (result) {
        case MFMailComposeResultSent:
            NSLog(@"You sent the email.");
            break;
        case MFMailComposeResultSaved:
            NSLog(@"You saved a draft of this email");
            break;
        case MFMailComposeResultCancelled:
            NSLog(@"You cancelled sending this email.");
            break;
        case MFMailComposeResultFailed:
            NSLog(@"Mail failed:  An error occurred when trying to compose this email");
            break;
        default:
            NSLog(@"An error occurred when trying to compose this email");
            break;
    }
    
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (IBAction)showShareBar:(id)sender {
    [_shareBar setHidden:NO];
    [_shareBtn setHidden:YES];
}

- (IBAction)closeShareBar:(id)sender {
    [_shareBar setHidden:YES];
    [_shareBtn setHidden:NO];
}

#pragma mark - -HUD methods
- (void)loadDataWithHUD:(id)obj
{
     DLog(@"[CoreDataManager instance] getReportUpdateStatus] = %@", [[CoreDataManager instance] getReportUpdateStatus]);
    if([[CoreDataManager instance] getReportUpdateStatus] == nil){
        [self.progressBar stopAnimating];
        [self sampleCountUpdated:nil];
    }
    else{
        self.updateLabel.text = [[CoreDataManager instance] getReportUpdateStatus];
        [self.updateLabel setNeedsDisplay];
    }
    DLog(@"loadDataWithHUD");
}


#pragma mark - MBProgressHUDDelegate method
- (void)hudWasHidden:(MBProgressHUD *)hud
{
    // Remove HUD from screen when the HUD was hidded
    [self sampleCountUpdated:nil];
}

- (BOOL) isFresh
{
    return [[CoreDataManager instance] secondsSinceLastUpdate] < 600; // 600 == 10 minutes
}

- (void) updateNetworkStatus:(NSNotification *) notice
{
    DLog(@"%s", __PRETTY_FUNCTION__);
    NSDictionary *dict = [notice userInfo];
    BOOL isInternetActive = [dict[kIsInternetActive] boolValue];
    
    if (isInternetActive || [[CommunicationManager instance] isInternetReachable]) {
        DLog(@"Checking if update needed with new reachability status...");
        if (![self isFresh] && // need to update
            [[CoreDataManager instance] getReportUpdateStatus] == nil) // not already updating
        {
            DLog(@"Update possible; initiating.");
            [[CoreDataManager instance] updateLocalReportsFromServer];
            [self.progressBar startAnimating];
            
        }
    }
}



#pragma mark - Navigation methods
- (IBAction)showScoreInfo:(id)sender {
    [self showInfoView:@"JScore" message:@"JScoreDesc"];
    [Flurry logEvent:NSLocalizedString(@"selectedJScoreInfo", nil)];
}

- (IBAction)showMyDevice:(id)sender {
    MyScoreViewController *controler = [[MyScoreViewController alloc]initWithNibName:@"MyScoreViewController" bundle:nil];
    [self.navigationController pushViewController:controler animated:YES];
    [Flurry logEvent:NSLocalizedString(@"selectedMyDeviceView", nil)];
}

- (IBAction)showBugs:(id)sender {
    NSLog(@"bugsTapped");
    BugsViewController *controler = [[BugsViewController alloc]initWithNibName:@"BugsViewController" bundle:nil];
    [self.navigationController pushViewController:controler animated:YES];
    [Flurry logEvent:NSLocalizedString(@"selectedBugsView", nil)];
}

- (IBAction)showHogs:(id)sender {
    HogsViewController *controler = [[HogsViewController alloc]initWithNibName:@"HogsViewController" bundle:nil];
    [self.navigationController pushViewController:controler animated:YES];
    [Flurry logEvent:NSLocalizedString(@"selectedHogsView", nil)];
}

- (IBAction)showStatistics:(id)sender {
    StatisticsViewController *controler = [[StatisticsViewController alloc]initWithNibName:@"StatisticsViewController" bundle:nil];
    [self.navigationController pushViewController:controler animated:YES];
    [Flurry logEvent:NSLocalizedString(@"selectedStatisticsView", nil)];
}
- (IBAction)showActions:(id)sender {
    ActionsViewController *controler = [[ActionsViewController alloc]initWithNibName:@"ActionsViewController" bundle:nil];
    [self.navigationController pushViewController:controler animated:YES];
    [Flurry logEvent:NSLocalizedString(@"selectedActionsView", nil)];
}
- (IBAction)showFacebook:(id)sender {
    id<SZEntity> entity = [SZEntity entityWithKey:@"http://carat.cs.helsinki.fi" name:@"Carat"];
    SZShareOptions *options = [SZShareUtils userShareOptions];
    // http://developers.facebook.com/docs/reference/api/link/
    options.willAttemptPostingToSocialNetworkBlock = ^(SZSocialNetwork network, SZSocialNetworkPostData *postData) {
        if (network == SZSocialNetworkFacebook) {
            [postData.params setObject:[[@"My J-Score is " stringByAppendingString:[[NSNumber numberWithInt:(int)(MIN( MAX([[CoreDataManager instance] getJScore], -1.0), 1.0)*100)] stringValue]] stringByAppendingString:@". Find out yours and improve your battery life!"] forKey:@"message"];
            [postData.params setObject:@"http://carat.cs.helsinki.fi" forKey:@"link"];
            [postData.params setObject:@"Carat: Collaborative Energy Diagnosis" forKey:@"caption"];
            [postData.params setObject:@"Carat" forKey:@"name"];
            [postData.params setObject:@"Carat is a free app that tells you what is using up your battery, whether that's normal, and what you can do about it." forKey:@"description"];
            [postData.params setObject:@"http://carat.cs.helsinki.fi/img/icon144.png" forKey:@"picture"];
        } else if (network == SZSocialNetworkTwitter) {
            [postData.params setObject:[[@"My J-Score is " stringByAppendingString:[[NSNumber numberWithInt:(int)(MIN( MAX([[CoreDataManager instance] getJScore], -1.0), 1.0)*100)] stringValue]] stringByAppendingString:@". Find out yours and improve your battery life! http://is.gd/caratweb"] forKey:@"status"];
        }
    };
    
    options.willShowEmailComposerBlock = ^(SZEmailShareData *emailData) {
        emailData.subject = @"Battery Diagnosis with Carat";
        
        //        NSString *appURL = [emailData.propagationInfo objectForKey:@"http://bit.ly/xurpWS"];
        //        NSString *entityURL = [emailData.propagationInfo objectForKey:@"entity_url"];
        //        id<SZEntity> entity = emailData.share.entity;
        NSString *appName = emailData.share.application.name;
        
        emailData.messageBody = [NSString stringWithFormat:@"Check out this free app called %@ that tells you what is using up your mobile device's battery, whether that's normal, and what you can do about it: http://is.gd/caratweb\n\n\n", appName];
    };
    
    options.willShowSMSComposerBlock = ^(SZSMSShareData *smsData) {
        //        NSString *appURL = [smsData.propagationInfo objectForKey:@"application_url"];
        //        NSString *entityURL = [smsData.propagationInfo objectForKey:@"entity_url"];
        //        id<SZEntity> entity = smsData.share.entity;
        NSString *appName = smsData.share.application.name;
        
        smsData.body = [NSString stringWithFormat:@"Check out this free app called %@ that helps improve your mobile device's battery life: http://is.gd/caratweb", appName];
    };
    
    [SZShareUtils showShareDialogWithViewController:self options:options entity:entity completion:^(NSArray *shares) {
        //NSLog(@"Created %d shares: %@", [shares count], shares);
    } cancellation:^{
        NSLog(@"Share creation cancelled");
    }];
   
    /*
    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeFacebook]) {
        fbSLComposeViewController = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeFacebook];
        [fbSLComposeViewController addImage:someImage];
        [fbSLComposeViewController setInitialText:@"Some Text"];
        [self presentViewController:fbSLComposeViewController animated:YES completion:nil];
        
        fbSLComposeViewController.completionHandler = ^(SLComposeViewControllerResult result) {
            switch(result) {
                case SLComposeViewControllerResultCancelled:
                    NSLog(@"facebook: CANCELLED");
                    break;
                case SLComposeViewControllerResultDone:
                    NSLog(@"facebook: SHARED");
                    break;
            }
        };
    }
    else {
        UIAlertView *fbError = [[UIAlertView alloc] initWithTitle:@"Facebook Unavailable" message:@"Sorry, we're unable to find a Facebook account on your device.\nPlease setup an account in your devices settings and try again." delegate:self cancelButtonTitle:@"Close" otherButtonTitles:nil];
        [fbError show];
    }
    
    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeFacebook]) {
        
        SLComposeViewController *mySLComposerSheet = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeFacebook];
        
        [mySLComposerSheet setInitialText:@"iOS 6 Social Framework test!"];
        
        [mySLComposerSheet addImage:[UIImage imageNamed:@"icon144"]];
        //@"http://carat.cs.helsinki.fi/img/icon144.png" forKey:@"picture"
        [mySLComposerSheet addURL:[NSURL URLWithString:@"http://stackoverflow.com/questions/12503287/tutorial-for-slcomposeviewcontroller-sharing"]];
        
        [mySLComposerSheet setCompletionHandler:^(SLComposeViewControllerResult result) {
            switch (result) {
                case SLComposeViewControllerResultCancelled:
                    NSLog(@"Post Canceled");
                    break;
                case SLComposeViewControllerResultDone:
                    NSLog(@"Post Sucessful");
                    break;
                    
                default:
                    break;
            }
        }];
        
        [self.navigationController pushViewController:mySLComposerSheet animated:YES];
    }
     */
   
    [Flurry logEvent:NSLocalizedString(@"selectedShareFacebook", nil)];
}

- (IBAction)showTwitter:(id)sender {
    
    [Flurry logEvent:NSLocalizedString(@"selectedShareTwitter", nil)];
}


- (IBAction)showEmail:(id)sender {
    if ([MFMailComposeViewController canSendMail])
    {
        MFMailComposeViewController *mail = [[MFMailComposeViewController alloc] init];
        mail.mailComposeDelegate = self;
        [mail setSubject:NSLocalizedString(@"EmailMessageTittle", nil)];
        
        NSMutableString *messageBody = [[NSMutableString alloc]init];
        [messageBody appendString:[self getJScoreString]];
        [messageBody appendString:@"\n\n"];
        [messageBody appendString:[NSString stringWithFormat:NSLocalizedString(@"CaratEmailSalesPitch", nil), NSLocalizedString(@"Carat", nil)]];
   
        [mail setMessageBody:messageBody isHTML:NO];
        
        //[self.navigationController pushViewController:mail animated:YES];
        [self presentViewController:mail animated:YES completion:NULL];
    }
    else
    {
        NSLog(@"This device cannot send email");
    }
    [Flurry logEvent:NSLocalizedString(@"selectedShareEmail", nil)];
}

- (void)dealloc {
    [_scoreView release];
    [_updateLabel release];
    [_batteryLastLabel release];
    [_bugsBtn release];
    [_hogsBtn release];
    [_statisticsBtn release];
    [_actionsBtn release];
    [_shareBtn release];
    [_shareBar release];
    [_shareBar release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_progressBar release];
    [super dealloc];
}
@end
