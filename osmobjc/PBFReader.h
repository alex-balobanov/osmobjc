//
//  Created by Alex (alex@itlekt.com)
//  Copyright (c) 2015 ITlekt Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

// forward declarations
@protocol PBFReaderProtocol;
@class OSMNode;
@class OSMWay;
@class OSMRelation;



//
// PBFReader
//
@interface PBFReader : NSObject

// error code/message
@property(nonatomic, readonly) NSError *error;

// osm bounding box
@property(nonatomic, readonly) double bboxLeft;
@property(nonatomic, readonly) double bboxBottom;
@property(nonatomic, readonly) double bboxRight;
@property(nonatomic, readonly) double bboxTop;

- (instancetype)initWithDelegate:(id<PBFReaderProtocol>)delegate;
- (void)readFile:(NSString *)filename;

@end



//
// PBFReaderProtocol
//
@protocol PBFReaderProtocol <NSObject>

// This method is called every time a Node is read
- (void)reader:(PBFReader *)reader didReadNode:(OSMNode *)node;

// This method is called every time a Way is read
- (void)reader:(PBFReader *)reader didReadWay:(OSMWay *)way;

// This method is called every time a Relation is read
- (void)reader:(PBFReader *)reader didReadRelation:(OSMRelation *)rel;

// This method is called when data has been successfully read
- (void)readerDidFinish:(PBFReader *)reader;

// This method is called when error occurred
- (void)reader:(PBFReader *)reader didFailWithError:(NSError *)error;

@end
