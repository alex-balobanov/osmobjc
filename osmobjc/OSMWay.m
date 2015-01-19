//
//  Created by Alex (alex@itlekt.com)
//  Copyright (c) 2015 ITlekt Corporation. All rights reserved.
//

#import "OSMWay.h"

@implementation OSMWay

- (instancetype)initWithID:(uint64_t)osmid refs:(NSArray *)refs tags:(NSDictionary *)tags {
	if ((self = [super init])) {
		_osmid = osmid;
		_refs = refs;
		_tags = tags;
	}
	return self;
}

+ (instancetype)wayWithID:(uint64_t)osmid refs:(NSArray *)refs tags:(NSDictionary *)tags {
	return [[self alloc] initWithID:osmid refs:refs tags:tags];
}

@end
