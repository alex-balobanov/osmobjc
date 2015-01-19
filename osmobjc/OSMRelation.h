//
//  Created by Alex (alex@itlekt.com)
//  Copyright (c) 2015 ITlekt Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

//
// OSMRelation
//
@interface OSMRelation : NSObject

@property(nonatomic, readonly) uint64_t osmid;					// unique identifier
@property(nonatomic, readonly) NSArray *refs;					// refs is an array of OSMRelationReference objects
@property(nonatomic, readonly) NSDictionary *tags;				// associated tags

- (instancetype)initWithID:(uint64_t)osmid refs:(NSArray *)refs tags:(NSDictionary *)tags;
+ (instancetype)relationWithID:(uint64_t)osmid refs:(NSArray *)refs tags:(NSDictionary *)tags;

@end



//
// OSMRelationReference
//
typedef NS_ENUM(uint8_t, OSMRelationReferenceType) {
	OSMRelationReferenceTypeNode = 0,
	OSMRelationReferenceTypeWay = 1,
	OSMRelationReferenceTypeRelation = 2
};

@interface OSMRelationReference : NSObject

@property(nonatomic, readonly) uint64_t osmid;					// unique identifier of an object
@property(nonatomic, readonly) OSMRelationReferenceType type;	// reference type indicates a type of the object
@property(nonatomic, readonly) NSString *role;					// object's role

- (instancetype)initWithID:(uint64_t)osmid type:(OSMRelationReferenceType)type role:(NSString *)role;
+ (instancetype)referenceWithID:(uint64_t)osmid type:(OSMRelationReferenceType)type role:(NSString *)role;

@end
