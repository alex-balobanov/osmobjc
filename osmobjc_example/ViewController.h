//
//  Created by Alex (alex@itlekt.com)
//  Copyright (c) 2015 ITlekt Corporation. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MapKit/MapKit.h>
#import <osmobjc/osmobjc.h>

@interface ViewController : NSViewController<MKMapViewDelegate, PBFReaderProtocol>

@property (weak) IBOutlet MKMapView *mapView;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;

@end

