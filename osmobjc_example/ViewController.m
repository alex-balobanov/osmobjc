//
//  Created by Alex (alex@itlekt.com)
//  Copyright (c) 2015 ITlekt Corporation. All rights reserved.
//

#import "ViewController.h"

@interface ViewController()
@property(nonatomic) NSMutableDictionary *nodes;
@property(nonatomic) NSMutableDictionary *ways;
@property(nonatomic) NSMutableDictionary *rels;
@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	
	// hawaii coordinates
	_mapView.delegate = self;
	_mapView.showsCompass = YES;
	_mapView.showsZoomControls = YES;
	_mapView.showsScale = YES;
	
	CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(21.311400, -157.796400);
	MKCoordinateRegion region = { coordinate, MKCoordinateSpanMake(3, 3) };
	[_mapView setRegion:region];
	
	// osm data storage
	_nodes = [[NSMutableDictionary alloc] init];
	_ways = [[NSMutableDictionary alloc] init];
	_rels = [[NSMutableDictionary alloc] init];
	
	// progress indicator
	[self showProgressIndicator];
	
	// read data from pbf file
	PBFReader *reader = [[PBFReader alloc] initWithDelegate:self];
	NSString *filename = [[NSBundle mainBundle] pathForResource:@"hawaii-latest.osm.pbf" ofType:nil];
	NSLog(@"Read data from: [%@]", filename);
	[reader readFile:filename];
}

- (void)setRepresentedObject:(id)representedObject {
	[super setRepresentedObject:representedObject];
	// Update the view, if already loaded.
}

#pragma mark -
#pragma mark Drawing code

- (void)showProgressIndicator {
	[_progressIndicator setHidden:NO];
	[_progressIndicator startAnimation:self];
}

- (void)hideProgressIndicator {
	[_progressIndicator setHidden:YES];
	[_progressIndicator stopAnimation:self];
}

- (void)drawWay:(OSMWay *)way {
	NSInteger count = way.refs.count, index = 0;
	CLLocationCoordinate2D coordinates[count];
	for (NSNumber *ref in way.refs) {
		OSMNode *node = _nodes[ref];
		if (node) {
			coordinates[index++] = CLLocationCoordinate2DMake(node.latitude, node.longitude);
		}
	}
	MKPolyline *polyLine = [MKPolyline polylineWithCoordinates:coordinates count:index];
	[_mapView addOverlay:polyLine];
}

- (NSColor *)randomColor {
	return [NSColor colorWithCalibratedRed:(rand() % 255)/255.0
									 green:(rand() % 255)/255.0
									  blue:(rand() % 255)/255.0
									 alpha:1.0];
}

#pragma mark -
#pragma mark MKMapViewDelegate

-(MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
	MKPolylineRenderer *polylineView = [[MKPolylineRenderer alloc] initWithPolyline:overlay];
	polylineView.strokeColor = [self randomColor];
	polylineView.lineWidth = 1.0;
	return polylineView;
}

#pragma mark -
#pragma mark PBFReaderProtocol

// This method is called every time a Node is read
- (void)reader:(PBFReader *)reader didReadNode:(OSMNode *)node {
	_nodes[@(node.osmid)] = node;
}

// This method is called every time a Way is read
- (void)reader:(PBFReader *)reader didReadWay:(OSMWay *)way {
	_ways[@(way.osmid)] = way;
	
	if ([way.tags[@"boundary"] isEqualToString:@"administrative"]) {
		[self drawWay:way];
	}
}

// This method is called every time a Relation is read
- (void)reader:(PBFReader *)reader didReadRelation:(OSMRelation *)rel {
	_rels[@(rel.osmid)] = rel;
}

// This method is called when data has been successfully read
- (void)readerDidFinish:(PBFReader *)reader {
	NSLog(@"Nodes = %ld, Ways = %ld, Relations = %ld", _nodes.count, _ways.count, _rels.count);
	[self hideProgressIndicator];
}

// This method is called when error occurred
- (void)reader:(PBFReader *)reader didFailWithError:(NSError *)error {
	NSLog(@"Error = [%@]", [error localizedDescription]);
	[self hideProgressIndicator];
}

@end
