//
//  SettingsTVC.m
//  simra
//
//  Created by Christoph Krey on 28.03.19.
//  Copyright © 2019-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "SettingsTVC.h"
#import <MessageUI/MessageUI.h>
#import "IdPicker.h"
#import "AppDelegate.h"
#import "NSTimeInterval+hms.h"
#import "DSBarChart.h"
#import "SimRa-Swift.h"
#import <SSZipArchive/SSZipArchive.h>
#import "NSString+hashCode.h"
#define UPLOAD_SCHEME @"https:"
#if SELF_SIGNED_HACK
#define UPLOAD_HOST @"vm1.mcc.tu-berlin.de:8082"
#else
//#define UPLOAD_HOST @"vm3.mcc.tu-berlin.de:8082"
#ifdef DEBUG
#define UPLOAD_HOST @"vm1.mcc.tu-berlin.de:8082"
#else
#define UPLOAD_HOST @"vm2.mcc.tu-berlin.de:8082"
#endif
#endif
#define UPLOAD_VERSION 12
@interface SettingsTVC ()
{
    AppDelegate *ad;
}

@property (weak, nonatomic) IBOutlet UILabel *version;
@property (weak, nonatomic) IBOutlet UITableViewCell *versionCell;

@property (strong, nonatomic) UIAlertController *ac;

@end

@implementation SettingsTVC

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    ad = [AppDelegate sharedDelegate];
    [self update];
    [self addTapGestureForVersion];
}
- (void)didTapOnVersion:(UITapGestureRecognizer*)sender {
    NSLog(@"hello taps");
    
    [UIAlertController showAlertWithTitle: NSLocalizedString(@"Send local app data to SimRa team", @"Send local app data to SimRa team") message: NSLocalizedString(@"Attention! Only tap the Continue button, if you were asked to do so by the SimRa team. By Pressing the Upload button in the next step, you send your SimRa configuration to the SimRa team. You can also specify to upload the last 10 rides or all rides.", @"Attention! Only tap the Continue button, if you were asked to do so by the SimRa team. By Pressing the Upload button in the next step, you send your SimRa configuration to the SimRa team. You can also specify to upload the last 10 rides or all rides.") style: UIAlertControllerStyleAlert buttonFirstTitle:@"Cancel" buttonSecondTitle:@"Confirm" buttonFirstAction:^{
        NSLog(@"Cancel pressed");
    } buttonSecondAction:^{
        NSLog(@"Confirm Pressed");
        [self showTotalRidesAlert];
    } over:self];
}
-(NSString *)getTripsSizeGetAllTrips:(BOOL)allTrips{
   
    int totalTrips = ad.trips.tripInfos.count;
    if (!allTrips && totalTrips > minimumTripsToSend){
        totalTrips = minimumTripsToSend;
    }
    long long totalBytes = 0;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentDirectoryURL = [fileManager URLsForDirectory:NSDocumentDirectory
                                                      inDomains:NSUserDomainMask].firstObject;
    for (int i = 1; i <= totalTrips ; i ++){
        NSLog(@"%d",i);
        NSURL *tripURL = [documentDirectoryURL URLByAppendingPathComponent:[NSString stringWithFormat:@"Trip-%d.json", i]];
        NSURL *tripInfoURL = [documentDirectoryURL URLByAppendingPathComponent:[NSString stringWithFormat:@"TripInfo-%d.json", i]];

        NSNumber *fileSizeValueForTripInfo = nil;
        NSNumber *fileSizeValueForTrip = nil;
        NSError *fileSizeError = nil;
        [tripURL getResourceValue:&fileSizeValueForTrip
                           forKey:NSURLFileSizeKey
                            error:&fileSizeError];
        [tripInfoURL getResourceValue:&fileSizeValueForTripInfo
                           forKey:NSURLFileSizeKey
                            error:&fileSizeError];

        if (fileSizeValueForTrip && fileSizeValueForTripInfo) {
            totalBytes += [fileSizeValueForTrip longLongValue];
            totalBytes += [fileSizeValueForTripInfo longLongValue];

        }
        else {
            NSLog(@"error getting size for url %@ error was %@", tripURL, fileSizeError);
        }
    }
    NSString *displayFileSize = [NSByteCountFormatter stringFromByteCount:totalBytes
                                                               countStyle:NSByteCountFormatterCountStyleFile];
    return displayFileSize;

}
-(NSString* )createZipFilesWithPath{
    NSString * documentDirectory = [Utility getDocumentDirectory];
    NSString *tempDir = NSTemporaryDirectory();
    NSString* zipfile = @"";
    zipfile = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"/Logger.zip"]];
    NSLog(@"%@",zipfile);
    BOOL isZipCreated=[SSZipArchive createZipFileAtPath:zipfile withContentsOfDirectory:documentDirectory];
    if (!isZipCreated){
        NSLog(@"Zip file cannot be created");
    }
    return zipfile;
}
-(void)sendZipToServer{
    NSString *fileName = @"Logger.zip";
    NSString *zipFilePath = [self createZipFilesWithPath];
    NSLog(@"Zip file Created at Path : %@",zipFilePath);
    NSData *zipData = [NSData dataWithContentsOfFile:zipFilePath];
    
    NSString *urlString = [NSString stringWithFormat:@"https://vm2.mcc.tu-berlin.de:8082/12/debug?clientHash=%@",NSString.clientHash];
    /* creating URL request to send data */
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    [request setURL:[NSURL URLWithString:urlString]];
    
    [request setHTTPMethod:@"POST"];
    
    NSString *boundary = @"*****";
    
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary];
    
    [request addValue:contentType forHTTPHeaderField: @"Content-Type"];
    [request addValue:@"Keep-Alive" forHTTPHeaderField:@"Connection"];
    /* adding content as a body to post */
    
    NSMutableData *body = [NSMutableData data];
    
    NSString *header = [NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\".%@\"\r\n",[fileName stringByDeletingPathExtension],[fileName pathExtension]];
    
    [body appendData:[[NSString stringWithFormat:@"-–%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [body appendData:[[NSString stringWithString:header] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [body appendData:[NSData dataWithData:zipData]];
    
    [body appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];

    [request setHTTPBody:body];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
                                      {
        // do something with the data
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        NSLog(@"response status code: %ld", (long)[httpResponse statusCode]);

        NSString *requestReply = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        NSData * responseData = [requestReply dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:responseData options:kNilOptions error:&error];
        NSLog(@"requestReply: %@", jsonDict);
    }];
    [dataTask resume];
//    NSData *returnData = [[NSURLSession alloc] init];
    
//    NSString *returnString = [[NSString alloc] initWithData:returnData encoding:NSUTF8StringEncoding] ;
    


}
-(void)showTotalRidesAlert{
    // get all trips
    
    // if trips > 10 show second option of sending 10 rides only
    int totalTrips = ad.trips.tripInfos.count;
   
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:NSLocalizedString(@"Do you also want to send rides?", @"Do you also want to send rides?")
                                 message:@""
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    //Add Buttons
    NSString *allRideTitle = [NSString stringWithFormat:@"%@ (%@)",NSLocalizedString(@"Yes, all", @"Yes, all"), [self getTripsSizeGetAllTrips:true]];
    
    UIAlertAction* allRidesButton = [UIAlertAction
                                     actionWithTitle:allRideTitle
                                     style:UIAlertActionStyleDefault
                                     handler:^(UIAlertAction * action) {
        //Handle your yes please button action here
        [self sendZipToServer];
    }];
    [alert addAction:allRidesButton];

    if (totalTrips > minimumTripsToSend){
        NSString *fewRidesTitle = [NSString stringWithFormat:@"%@ %d (%@)",NSLocalizedString(@"Yes, the last", @"Yes, the last"),minimumTripsToSend, [self getTripsSizeGetAllTrips:false]];

    UIAlertAction* fewRidesButton = [UIAlertAction
                                     actionWithTitle:fewRidesTitle
                                     style:UIAlertActionStyleDefault
                                     handler:^(UIAlertAction * action) {
        //Handle no, thanks button
    }];
    [alert addAction:fewRidesButton];
    }

    UIAlertAction* cancelButton = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"No, don't send any rides", @"No, don't send any rides")
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction * action) {
        //Handle no, thanks button
    }];
    //Add your buttons to alert controller
    
    [alert addAction:cancelButton];
    
    [self presentViewController:alert animated:YES completion:nil];
}
-(void)addTapGestureForVersion{
    UITapGestureRecognizer * tapGesture = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(didTapOnVersion:)];
    tapGesture.numberOfTapsRequired = 1;
    [self.versionCell addGestureRecognizer:tapGesture];
    //    tapGesture.delegate = self;
    
    
}
- (void)update {
    self.version.text = [NSString stringWithFormat:@"%@-%@-%@",
                         [NSBundle mainBundle].infoDictionary[@"CFBundleName"],
                         [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"],
                         [NSLocale currentLocale].languageCode
                         ];
}

- (IBAction)aboutPressed:(UIButton *)sender {
    [[AppDelegate sharedDelegate] openURL:@{
        @"en" : @"https://www.mcc.tu-berlin.de/menue/research/projects/simra/parameter/en/",
        @"de" : @"https://www.mcc.tu-berlin.de/menue/research/projects/simra/parameter/de/"
    }];
}

- (IBAction)privacyPressed:(UIButton *)sender {
    [[AppDelegate sharedDelegate] openURL:@{
        @"en" : @"https://www.mcc.tu-berlin.de/menue/research/projects/simra/privacy_policy_statement/parameter/en",
        @"de" : @"https://www.mcc.tu-berlin.de/menue/forschung/projekte/simra/datenschutzerklaerung/parameter/de/"
    }];
}

- (IBAction)howtoPressed:(UIButton *)sender {
    [[AppDelegate sharedDelegate] showHowTo];
}

- (IBAction)feedbackPressed:(UIButton *)sender {
    if (MFMailComposeViewController.canSendMail) {
        MFMailComposeViewController* controller = [[MFMailComposeViewController alloc] init];
        controller.mailComposeDelegate = self;
        [controller setToRecipients:@[@"ask@mcc.tu-berlin.de"]];
        [controller setSubject:NSLocalizedString(@"Feedback SimRa", @"Feedback SimRa")];
        [controller setMessageBody:NSLocalizedString(@"Dear SimRa Team", @"Dear SimRa Team")
                            isHTML:NO];
        [self presentViewController:controller animated:TRUE completion:nil];
    } else {
        self.ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"SimRa", @"SimRa")
                                                      message:NSLocalizedString(@"Configure your Email, please!", @"Configure your Email, please!")
                                               preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *aad = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK")
                                                      style:UIAlertActionStyleDefault
                                                    handler:nil];
        [self.ac addAction:aad];
        [self presentViewController:self.ac animated:TRUE completion:nil];
        return;
        
    }
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error {
    if (result == MFMailComposeResultSent) {
        NSLog(@"sent");
    }
    [self dismissViewControllerAnimated:TRUE completion:nil];
}

- (IBAction)imprintPressed:(UIButton *)sender {
    [[AppDelegate sharedDelegate] openURL:@{
        @"en" : @"https://www.tu-berlin.de/servicemenue/impressum/parameter/en/mobil/",
        @"de" : @"https://www.tu-berlin.de/servicemenue/impressum/parameter/mobil/"
    }];
}

@end