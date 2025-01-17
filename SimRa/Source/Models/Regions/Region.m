//
//  Region.m
//  SimRa
//
//  Created by Christoph Krey on 21.01.20.
//  Copyright © 2020-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "Region.h"

@implementation Region

- (NSString *)localizedDescription {
    NSString* strLoc = [NSBundle preferredLocalizationsFromArray:@[@"en", @"de"]].firstObject;
    return
        ([strLoc isEqualToString: @"de"] ? self.germanDescription : self.englishDescription)
        ?: self.identifier;
}

- (CLLocation *)location {
    if (self.lat.doubleValue == 0.0 && self.lon.doubleValue == 0.0) {
        return nil;
    }
    CLLocation *myLocation = [[CLLocation alloc] initWithLatitude:self.lat.doubleValue
                                                        longitude:self.lon.doubleValue];
    return myLocation;
}

- (CLLocationDistance)distanceFrom:(CLLocation *)location {
    CLLocation *myLocation = self.location;
    if (!myLocation || !location) {
        return 400000000;
    }
    CLLocationDistance myDistance = [myLocation distanceFromLocation:location];
    return myDistance;
}

@end
