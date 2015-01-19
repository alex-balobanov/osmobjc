//
//  Created by Alex (alex@itlekt.com)
//  Copyright (c) 2015 ITlekt Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

//
// OSMWay
//
@interface OSMWay : NSObject

@property(nonatomic, readonly) uint64_t osmid;					// unique identifier
@property(nonatomic, readonly) NSArray *refs;					// refs is an array of nodes's osmid wrapped into NSNumber
@property(nonatomic, readonly) NSDictionary *tags;				// associated tags

- (instancetype)initWithID:(uint64_t)osmid refs:(NSArray *)refs tags:(NSDictionary *)tags;
+ (instancetype)wayWithID:(uint64_t)osmid refs:(NSArray *)refs tags:(NSDictionary *)tags;

@end
