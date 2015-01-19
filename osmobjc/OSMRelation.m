//
//  Created by Alex (alex@itlekt.com)
//  Copyright (c) 2015 ITlekt Corporation. All rights reserved.
//

#import "OSMRelation.h"

//
// OSMRelation
//
@implementation OSMRelation

- (instancetype)initWithID:(uint64_t)osmid refs:(NSArray *)refs tags:(NSDictionary *)tags {
	if ((self = [super init])) {
		_osmid = osmid;
		_refs = refs;
		_tags = tags;
	}
	return self;
}

+ (instancetype)relationWithID:(uint64_t)osmid refs:(NSArray *)refs tags:(NSDictionary *)tags {
	return [[self alloc] initWithID:osmid refs:refs tags:tags];
}

@end



//
// OSMRelationReference
//
@implementation OSMRelationReference

- (instancetype)initWithID:(uint64_t)osmid type:(OSMRelationReferenceType)type role:(NSString *)role {
	if ((self = [super init])) {
		_osmid = osmid;
		_type = type;
		_role = role;
	}
	return self;
}

+ (instancetype)referenceWithID:(uint64_t)osmid type:(OSMRelationReferenceType)type role:(NSString *)role {
	return [[self alloc] initWithID:osmid type:type role:role];
}

@end
