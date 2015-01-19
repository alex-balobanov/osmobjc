//
//  Created by Alex (alex@itlekt.com)
//  Copyright (c) 2015 ITlekt Corporation. All rights reserved.
//

#import "OSMNode.h"

@implementation OSMNode

- (instancetype)initWithID:(uint64_t)osmid latitude:(double)latitude longitude:(double)longitude tags:(NSDictionary *)tags {
	if ((self = [super init])) {
		_osmid = osmid;
		_latitude = latitude;
		_longitude = longitude;
		_tags = tags;
	}
	return self;
}

+ (instancetype)nodeWithID:(uint64_t)osmid latitude:(double)latitude longitude:(double)longitude tags:(NSDictionary *)tags {
	return [[self alloc] initWithID:osmid latitude:latitude longitude:longitude tags:tags];
}

@end
