//
//  Created by Alex (alex@itlekt.com)
//  Copyright (c) 2015 ITlekt Corporation. All rights reserved.
//

#import "PBFReader.h"
#import "OSMNode.h"
#import "OSMWay.h"
#import "OSMRelation.h"

// system libraries
#import <stdio.h>
#import <zlib.h>
#import <netinet/in.h>

// protocol buffers files (the low-level blob storage and the high-level OSM objects)
#import "protobuf/fileformat.pb.h"
#import "protobuf/osmformat.pb.h"

// osm constants
#define MAX_BLOB_HEADER_SIZE		(64 * 1024)				// 64 kB (the maximum size of a blob header in bytes)
#define MAX_UNCOMPRESSED_BLOB_SIZE	(32 * 1024 * 1024)		// 32 MB (the maximum size of an uncompressed blob in bytes)
#define LONLAT_RESOLUTION			(1000 * 1000 * 1000)	// 64 kB (resolution for longitude/latitude used for conversion double<->int)

@interface PBFReader()
@property(nonatomic, weak) id<PBFReaderProtocol> delegate;
@property(nonatomic) NSMutableData *buffer;
@property(nonatomic) NSMutableData *unpackBuffer;
@end

@implementation PBFReader

#pragma mark -
#pragma mark Public methods

- (instancetype)initWithDelegate:(id<PBFReaderProtocol>)delegate {
	if ((self = [super init])) {
		_delegate = delegate;
		_buffer = [[NSMutableData alloc] initWithLength:MAX_UNCOMPRESSED_BLOB_SIZE];
		_unpackBuffer = [[NSMutableData alloc] initWithLength:MAX_UNCOMPRESSED_BLOB_SIZE];
	}
	return self;
}

- (void)readFile:(NSString *)filename {
	// reset ivars
	_error = nil;
	_bboxLeft = _bboxBottom = _bboxRight = _bboxTop = 0;
	
	// read data asynchronously
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		FILE *file = fopen(filename.UTF8String, "rb");
		if (file) {
			// read while the file has not reached its end
			while (!feof(file)) {
				// header
				OSMPBF::BlobHeader header;
				if (![self readHeader:header fromFile:file]) {
					break;
				}
				
				// blob
				OSMPBF::Blob blob;
				uint32_t size = [self readBlob:blob forHeader:header fromFile:file];
				if (size <= 0) {
					break;
				}
				
				// blob data
				if (header.type() == "OSMHeader") {
					[self parseOSMHeader:size];
				}
				else if (header.type() == "OSMData") {
					[self parseOSMData:size];
				}
				else {
					[self updateErrorStatusWithCode:-1 message:[NSString stringWithFormat:@"Unknown blob type: %s", header.type().c_str()]];
				}
				if (_error) {
					break;
				}
			}
			fclose(file);
		}
		else {
			[self updateErrorStatusWithCode:-1 message:[NSString stringWithFormat:@"Can't open file '%@'", filename]];
		}
		
		if (!_error) {
			// call delegate
			dispatch_sync(dispatch_get_main_queue(), ^{
				[_delegate readerDidFinish:self];
			});
		}
		
		google::protobuf::ShutdownProtobufLibrary();
	});
}

#pragma mark -
#pragma mark Private methods

- (BOOL)readHeader:(OSMPBF::BlobHeader &)header fromFile:(FILE *)file {
	BOOL result = NO;
	// read the first 4 bytes of the file, this is the size of the blob-header
	uint32_t headerSize;
	if (fread(&headerSize, sizeof(headerSize), 1, file) == 1) {
		// convert the size from network byte-order to host byte-order
		headerSize = ntohl(headerSize);
		
		// ensure the blob-header is smaller then MAX_BLOB_HEADER_SIZE
		if (headerSize <= MAX_BLOB_HEADER_SIZE) {
			
			// read the blob-header from the file
			if (fread(_buffer.mutableBytes, headerSize, 1, file) == 1) {
				// parse the blob-header from the read-buffer
				if (header.ParseFromArray(_buffer.mutableBytes, headerSize)) {
					result = YES;
				}
				else {
					[self updateErrorStatusWithCode:-1 message:@"Unable to parse blob header"];
				}
			}
			else {
				[self updateErrorStatusWithCode:-1 message:@"Unable to read blob-header from file"];
			}
		}
		else {
			[self updateErrorStatusWithCode:-1 message:[NSString stringWithFormat:@"blob-header-size is bigger then allowed (%u > %u)",
														headerSize, MAX_BLOB_HEADER_SIZE]];
		}
	}
	return result;
}

- (int32_t)readBlob:(OSMPBF::Blob &)blob forHeader:(const OSMPBF::BlobHeader &)header fromFile:(FILE *)file {
	uint32_t result = 0;
	// size of the following blob
	int32_t dataSize = header.datasize();
	if (dataSize <= MAX_UNCOMPRESSED_BLOB_SIZE) {
		// read the blob from the file
		if (fread(_buffer.mutableBytes, dataSize, 1, file) == 1) {
			// parse the blob from the read-buffer
			if (blob.ParseFromArray(_buffer.mutableBytes, dataSize)) {
				// if the blob has uncompressed data
				if (blob.has_raw()) {
					// size of the blob-data
					uint32_t rawBlobSize = blob.raw().size();
					
					// copy the uncompressed data over to the unpack_buffer
					memcpy(_unpackBuffer.mutableBytes, _buffer.mutableBytes, rawBlobSize);
					result = rawBlobSize;
				}
				
				// if the blob has zlib-compressed data
				if (blob.has_zlib_data()) {
					// the size of the compressesd data
					uint32_t zlibBlobSize = blob.zlib_data().size();
					z_stream z;
					z.next_in   = (unsigned char*) blob.zlib_data().c_str();
					z.avail_in  = zlibBlobSize;
					z.next_out  = (unsigned char *)_unpackBuffer.mutableBytes;
					z.avail_out = blob.raw_size();
					z.zalloc    = Z_NULL;
					z.zfree     = Z_NULL;
					z.opaque    = Z_NULL;
					
					if (inflateInit(&z) == Z_OK) {
						if (inflate(&z, Z_FINISH) == Z_STREAM_END) {
							if (inflateEnd(&z) == Z_OK) {
								// unpacked size
								result = z.total_out;
							}
							else {
								[self updateErrorStatusWithCode:-1 message:@"Failed to deinit zlib stream"];
							}
						}
						else {
							[self updateErrorStatusWithCode:-1 message:@"Failed to inflate zlib stream"];
						}
					}
					else {
						[self updateErrorStatusWithCode:-1 message:@"Failed to init zlib stream"];
					}
				}
				
				// if the blob has lzma-compressed data
				if (blob.has_lzma_data()) {
					[self updateErrorStatusWithCode:-1 message:@"lzma-decompression is not supported"];
				}
				
				// check data stream
				if (result == 0) {
					[self updateErrorStatusWithCode:-1 message:@"Does not contain any known data stream"];
				}
			}
			else {
				[self updateErrorStatusWithCode:-1 message:@"Unable to parse blob"];
			}
		}
		else {
			[self updateErrorStatusWithCode:-1 message:@"Unable to read blob from file"];
		}
	}
	else {
		[self updateErrorStatusWithCode:-1 message:[NSString stringWithFormat:@"Blob-size is bigger then allowed (%u > %u)",
													dataSize, MAX_UNCOMPRESSED_BLOB_SIZE]];
	}
	
	
	
	return result;
}

- (void)parseOSMHeader:(uint32_t)size {
	// parse the HeaderBlock from the blob
	OSMPBF::HeaderBlock headerblock;
	if (headerblock.ParseFromArray(_unpackBuffer.mutableBytes, size)) {
		// tell about the bbox
		if (headerblock.has_bbox()) {
			OSMPBF::HeaderBBox bbox = headerblock.bbox();
			_bboxLeft = (double)bbox.left() / LONLAT_RESOLUTION;
			_bboxBottom = (double)bbox.bottom() / LONLAT_RESOLUTION;
			_bboxRight = (double)bbox.right() / LONLAT_RESOLUTION;
			_bboxTop = (double)bbox.top() / LONLAT_RESOLUTION;
		}
	}
	else {
		[self updateErrorStatusWithCode:-1 message:@"Unable to parse header block"];
	}
}

- (void)parseNodesFromPrimitiveGroup:(const OSMPBF::PrimitiveGroup &)primgroup primitiveBlock:(const OSMPBF::PrimitiveBlock &)primblock {
	for(int i = 0; i < primgroup.nodes_size(); ++i) {
		OSMPBF::Node node = primgroup.nodes(i);
		
		// coordinates
		double lon = 0.000000001 * (primblock.lon_offset() + (primblock.granularity() * node.lon()));
		double lat = 0.000000001 * (primblock.lat_offset() + (primblock.granularity() * node.lat()));
		
		// tags
		NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithCapacity:node.keys_size()];
		for(int j = 0; j < node.keys_size(); ++j) {
			uint64_t key = node.keys(j);
			uint64_t val = node.vals(j);
			NSString *key_string = [NSString stringWithUTF8String:primblock.stringtable().s(key).c_str()];
			NSString *val_string = [NSString stringWithUTF8String:primblock.stringtable().s(val).c_str()];
			tags[key_string] = val_string;
		}
		
		// call delegate
		dispatch_sync(dispatch_get_main_queue(), ^{
			[_delegate reader:self didReadNode:[OSMNode nodeWithID:node.id() latitude:lat longitude:lon tags:[tags copy]]];
		});
	}
}

- (void)parseDenseNodesFromPrimitiveGroup:(const OSMPBF::PrimitiveGroup &)primgroup primitiveBlock:(const OSMPBF::PrimitiveBlock &)primblock {
	if (primgroup.has_dense()) {
		OSMPBF::DenseNodes dn = primgroup.dense();
		uint64_t osmid = 0;
		double lon = 0;
		double lat = 0;
		int current_kv = 0;
		
		// nodes
		for (int i = 0; i < dn.id_size(); ++i) {
			osmid += dn.id(i);
			lon +=  0.000000001 * (primblock.lon_offset() + (primblock.granularity() * dn.lon(i)));
			lat +=  0.000000001 * (primblock.lat_offset() + (primblock.granularity() * dn.lat(i)));
			
			// tags
			NSMutableDictionary *tags = [NSMutableDictionary dictionary];
			while (current_kv < dn.keys_vals_size() && dn.keys_vals(current_kv) != 0) {
				uint64_t key = dn.keys_vals(current_kv);
				uint64_t val = dn.keys_vals(current_kv + 1);
				NSString *key_string = [NSString stringWithUTF8String:primblock.stringtable().s(key).c_str()];
				NSString *val_string = [NSString stringWithUTF8String:primblock.stringtable().s(val).c_str()];
				current_kv += 2;
				tags[key_string] = val_string;
			}
			++current_kv;
			
			// call delegate
			dispatch_sync(dispatch_get_main_queue(), ^{
				[_delegate reader:self didReadNode:[OSMNode nodeWithID:osmid latitude:lat longitude:lon tags:[tags copy]]];
			});
		}
	}
}

- (void)parseWaysFromPrimitiveGroup:(const OSMPBF::PrimitiveGroup &)primgroup primitiveBlock:(const OSMPBF::PrimitiveBlock &)primblock {
	for(int i = 0; i < primgroup.ways_size(); ++i) {
		OSMPBF::Way way = primgroup.ways(i);
		
		// refs
		uint64_t ref = 0;
		NSMutableArray *refs = [NSMutableArray arrayWithCapacity:way.refs_size()];
		for (int j = 0; j < way.refs_size(); ++j){
			ref += way.refs(j);
			[refs addObject:@(ref)];
		}
		
		// tags
		NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithCapacity:way.keys_size()];
		for(int j = 0; j < way.keys_size(); ++j) {
			uint64_t key = way.keys(j);
			uint64_t val = way.vals(j);
			NSString *key_string = [NSString stringWithUTF8String:primblock.stringtable().s(key).c_str()];
			NSString *val_string = [NSString stringWithUTF8String:primblock.stringtable().s(val).c_str()];
			tags[key_string] = val_string;
		}
		
		// call delegate
		dispatch_sync(dispatch_get_main_queue(), ^{
			[_delegate reader:self didReadWay:[OSMWay wayWithID:way.id() refs:[refs copy] tags:[tags copy]]];
		});
	}
}

- (void)parseRelationsFromPrimitiveGroup:(const OSMPBF::PrimitiveGroup &)primgroup primitiveBlock:(const OSMPBF::PrimitiveBlock &)primblock {
	for (int i=0; i < primgroup.relations_size(); ++i) {
		OSMPBF::Relation rel = primgroup.relations(i);
		
		// refs
		uint64_t memid = 0;
		NSMutableArray *refs = [NSMutableArray arrayWithCapacity:rel.memids_size()];
		for(int j = 0; j < rel.memids_size(); ++j) {
			memid += rel.memids(j);
			NSString *role = [NSString stringWithUTF8String:primblock.stringtable().s(rel.roles_sid(j)).c_str()];
			[refs addObject:[OSMRelationReference referenceWithID:memid type:(OSMRelationReferenceType)rel.types(j) role:role]];
		}
		
		// tags
		NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithCapacity:rel.keys_size()];
		for(int j = 0; j < rel.keys_size(); ++j) {
			uint64_t key = rel.keys(j);
			uint64_t val = rel.vals(j);
			NSString *key_string = [NSString stringWithUTF8String:primblock.stringtable().s(key).c_str()];
			NSString *val_string = [NSString stringWithUTF8String:primblock.stringtable().s(val).c_str()];
			tags[key_string] = val_string;
		}
		
		// call delegate
		dispatch_sync(dispatch_get_main_queue(), ^{
			[_delegate reader:self didReadRelation:[OSMRelation relationWithID:rel.id() refs:[refs copy] tags:[tags copy]]];
		});
	}
}

- (void)parseOSMData:(uint32_t)size {
	// parse the PrimitiveBlock from the blob
	OSMPBF::PrimitiveBlock primblock;
	if (primblock.ParseFromArray(_unpackBuffer.mutableBytes, size)) {
		// iterate over all PrimitiveGroups
		for (int i = 0, l = primblock.primitivegroup_size(); i < l; i++) {
			// one PrimitiveGroup from the the Block
			OSMPBF::PrimitiveGroup primgroup = primblock.primitivegroup(i);
			// nodes
			[self parseNodesFromPrimitiveGroup:primgroup primitiveBlock:primblock];
			// dense nodes
			[self parseDenseNodesFromPrimitiveGroup:primgroup primitiveBlock:primblock];
			// ways
			[self parseWaysFromPrimitiveGroup:primgroup primitiveBlock:primblock];
			// relations
			[self parseRelationsFromPrimitiveGroup:primgroup primitiveBlock:primblock];
		}
	}
	else {
		[self updateErrorStatusWithCode:-1 message:@"Unable to parse primitive block"];
	}
}

#pragma mark -
#pragma mark Error handling

- (void)updateErrorStatusWithCode:(NSInteger)code message:(NSString *)message {
	// set error code
	_error = [self errorWithCode:code message:message];

	// call delegate
	dispatch_sync(dispatch_get_main_queue(), ^{
		[_delegate reader:self didFailWithError:_error];
	});
}

- (NSError *)errorWithCode:(NSInteger)code message:(NSString *)message {
	return [NSError errorWithDomain:@"com.itlekt.osmobjc"
							   code:code
						   userInfo:@{ NSLocalizedDescriptionKey: message }];
}

@end
