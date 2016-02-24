//
//  HNetworkDAO.m
//  TestDemoCocoaPod
//
//  Created by jeremyLyu on 14-9-17.
//  Copyright (c) 2014年 jeremyLyu. All rights reserved.
//

#import "HNetworkDAO.h"
#import "HEntity.h"
#import <HFileCache.h>
#import <HCommon.h>

/**
 *  property desc
 */
@interface HNetworkDAOPropertyExt : NSObject
@property (nonatomic) BOOL isHead;
@property (nonatomic) NSString *keyMapto;
@property (nonatomic) BOOL isIgnore;
@end

@implementation HNetworkDAOPropertyExt
- (instancetype)initWithObjs:(id)objs
{
    self = [super init];
    if (self) {
        if ([objs isKindOfClass:[NSArray class]])
        {
            for (id obj in (NSArray *)objs)
            {
                [self setWithObj:obj];
            }
        }
    }
    return self;
}
- (void)setWithObj:(id)obj
{
    if ([obj isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *dict = obj;
        NSString *mapTo = dict[@"mapto"];
        if (mapTo)
        {
            self.keyMapto = mapTo;
            return;
        }
    }
    else if ([obj isEqualToString:HPHeader])
    {
        self.isHead = YES;
    }
    else if ([obj isEqualToString:HPIgnore])
    {
        self.isIgnore = YES;
    }
}
@end

@implementation HNetworkMultiDataObj

- (id)init
{
    self = [super init];
    if(self)
    {
        self.filePath = nil;
        self.fileName = @"file.jpg";
        self.mimeType = @"image/jpg";
        self.data = nil;
        self.datas = nil;
    }
    return self;
}

@end


@interface HNetworkDAO()
{
    NSOperation* _operation;
    HNetworkDAO* _holdSelf;
}
@property (nonatomic) NSString *fileDownloadPath;
@end

@implementation HNetworkDAO

- (id)init
{
    self = [super init];
    if(self)
    {
        _queueName = nil;
        self.baseURL = nil;
        self.pathURL = nil;
        
        _failedBlock = nil;
        _holdSelf = nil;
        self.method = @"GET";
    }
    return self;
}


#pragma mark - request

- (NSString *)fullurl
{
    //combine
    NSURL* baseUrl = [NSURL URLWithString:self.baseURL];
    NSString* urlString = self.baseURL;
    if (self.pathURL) urlString =[[NSURL URLWithString:self.pathURL relativeToURL:baseUrl] absoluteString];
    return urlString;
}


- (void)startWithQueueName:(NSString*)queueName
{
    _queueName = queueName;
    
    

    NSString* urlString = [self fullurl];

    //prepare file download path
    if (self.isFileDownload)
    {
        self.fileDownloadPath = [self createTempFilePath:urlString];
    }
    else self.fileDownloadPath = nil;
    
    
    //if is file access url
    if ([urlString hasPrefix:@"file://"])
    {
        [self doLocalFileRequest:urlString];
    }
    
    
    
    
    //if is bundle access url
    else if ([urlString hasPrefix:@"bundle://"])
    {
        NSString *path = [urlString substringFromIndex:[@"bundle://" length]];
        path = [[NSBundle mainBundle] URLForResource:path withExtension:nil].absoluteString;
        [self doLocalFileRequest:path];
    }
    
    
    
    
    //network
    else
    {
        //set http headers
        NSMutableDictionary *headers = [NSMutableDictionary new];
        [self setupHeader:headers];
        //set params
        NSMutableDictionary *params = [NSMutableDictionary new];
        [self setupParams:params];
        [self didSetupParams:params];
        //request
        __weak HNetworkDAO* weakSelf = self;
        _holdSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [HNetworkDAOManager instance].timeoutInterval = self.timeoutInterval;
            [HNetworkDAOManager instance].shouldContinueInBack = self.shouldContinueInBack;
            [HNetworkDAOManager instance].fileDownloadPath = self.fileDownloadPath;
            [HNetworkDAOManager instance].headParameters = headers;
            _operation = [[HNetworkDAOManager instance]
                          requestWithURLString:urlString
                          parameters:params
                          queueName:queueName
                          mode:self.method
                          sucess:^(AFHTTPRequestOperation* operation, id responseObject){
                              
                              NSLog(@" ");
                              NSLog(@"#### revc response");
                              NSLog(@"#### %@", [weakSelf fullurl]);
                              NSLog(@" ");
                              if (!weakSelf.fileDownloadPath)
                              {
                                  weakSelf.responseData = operation.responseData;
                                  [weakSelf requestFinishedSucessWithInfo:responseObject];
                              }
                              else
                              {
                                  HDownloadFileInfo *info = [HDownloadFileInfo new];
                                  info.filePath = weakSelf.fileDownloadPath;
                                  info.MIMEType = [operation.response MIMEType];
                                  info.length = [operation.response expectedContentLength];
                                  info.suggestedFilename = [operation.response suggestedFilename];
                                  //delete after 1 min
                                  [[HFileCache shareCache] setExpire:[NSDate dateWithTimeIntervalSinceNow:60] forFilePath:info.filePath];
                                  [weakSelf downloadFinished:info];
                              }
                              
                              
                          }
                          failure:^(AFHTTPRequestOperation* operation, NSError* error){
                              
                              [weakSelf requestFinishedFailureWithError:[NSError errorWithDomain:@"Network" code:error.code description:error.localizedDescription]];
                              
                              
                          }
                          progressBlock:weakSelf.progressBlock
                          ];
        });
    }
}

- (void)startWithQueueName:(NSString *)queueName
                    sucess:(void (^)(id, id))sucess
                   failure:(void (^)(id, NSError *))failure
{
    _sucessBlock = sucess;
    _failedBlock = failure;
    [self cacheLogic:queueName];

}
- (void)startWithQueueName:(NSString *)queueName
                    finish:(void(^)(id sender, id data, NSError *error))finish
{
    _sucessBlock = ^(id sender, id data){
        if (finish) finish(sender, data, nil);
    };
    _failedBlock = ^(id sender, NSError *error){
        if (finish) finish(sender, nil, error);
    };
    [self cacheLogic:queueName];
}

- (void)cancel
{
    [_operation cancel];
}

- (void)setupHeader:(NSMutableDictionary *)headers
{
    NSArray *pplist = [self ppList];
    for (NSString *key in pplist)
    {
        NSArray *exts = [[self class] annotations:key];
        HNetworkDAOPropertyExt *extsObj = [[HNetworkDAOPropertyExt alloc] initWithObjs:exts];
        if (extsObj.isHead)
        {
            [headers setValue:[self valueForKey:key] forKey:extsObj.keyMapto?:key];
        }
    }
}
- (void)setupParams:(NSMutableDictionary *)params
{
    if (self.class == [HNetworkDAO class]) return;
    NSArray* pplist = [self ppList];

    for(NSString* key in pplist)
    {
        NSArray *exts = [[self class] annotations:key];
        HNetworkDAOPropertyExt *extsObj = [[HNetworkDAOPropertyExt alloc] initWithObjs:exts];
        if (extsObj.isHead)
        {
            continue;
        }
        if (extsObj.isIgnore)
        {
            continue;
        }
        id value = [self valueForKey:key];
        if (!value) continue;
        
        [params setValue:value forKey:extsObj.keyMapto?:key];
    }
}
- (void)didSetupParams:(NSMutableDictionary *)params
{

}
//output
- (id)getOutputEntiy:(id)responseObject
{
    id rudeData = responseObject;
    if (self.deserializeKeyPath)
    {
        rudeData = [rudeData valueForKeyPath:self.deserializeKeyPath];
        if (!rudeData)
        {
            return herr(kDataFormatErrorCode, ([NSString stringWithFormat:@"target path is not exist%@",self.deserializeKeyPath]));
        }
    }
    if (self.deserializer)
    {
        return [self.deserializer deserialization:rudeData];
    }
    else return rudeData;
}

//local request
- (void)doLocalFileRequest:(NSString *)urlString
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSData *fileData = [NSData dataWithContentsOfURL:[NSURL URLWithString:urlString]];
        if (!fileData)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self requestFinishedFailureWithError:[NSError errorWithDomain:@"Network" code:kNetWorkErrorCode description:[NSString stringWithFormat:@"%@ file not exsit", urlString]]];
            });
            return ;
        }
        if (!self.isFileDownload)
        {
            id jsonValue = [fileData JSONValue];
            if (!jsonValue)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self requestFinishedFailureWithError:[NSError errorWithDomain:@"Network" code:kDataFormatErrorCode description:[NSString stringWithFormat:@"%@Json decode error", urlString]]];
                });
                return;
            }
            NSLog(@"revc response %@/%@", self.baseURL, self.pathURL);
            self.responseData = fileData;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self requestFinishedSucessWithInfo:jsonValue];
            });
        }
        else
        {
            [fileData writeToFile:self.fileDownloadPath atomically:YES];
            
            HDownloadFileInfo *info = [HDownloadFileInfo new];
            info.filePath = self.fileDownloadPath;
            info.MIMEType = @"unkown";
            info.length = fileData.length;
            info.suggestedFilename = [urlString lastPathComponent];
            //设置为1小时后删除
            [[HFileCache shareCache] setExpire:[NSDate dateWithTimeIntervalSinceNow:3600] forFilePath:info.filePath];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self downloadFinished:info];
            });
        }
    });
}
#pragma mark - about cache

- (NSString *)cacheKey
{
    return [NSString stringWithFormat:@"%@%@",self.baseURL, self.pathURL];
}
- (BOOL)isCacheUseable
{
    return [self isCacheUseable:[self cacheKey]];
}
- (BOOL)isCacheUseable:(NSString *)cacheKey
{
    BOOL cacheUsable = NO;
    if (self.cacheDuration > 0)
    {
        NSString *cachePath = [[HFileCache shareCache] cachePathForKey:cacheKey];
        if (cachePath)
        {
            NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:cachePath error:nil];
            if (fileAttributes)
            {
                NSDate *createDate = fileAttributes[NSFileCreationDate];
                long interval = [[NSDate date] timeIntervalSinceDate:createDate];
                if (interval < self.cacheDuration)
                {
                    cacheUsable = YES;
                }
            }
        }
    }
    return cacheUsable;
}
//get cache
- (void)loadCache:(NSString *)cacheKey
{
    NSData *data = [[HFileCache shareCache] dataForKey:cacheKey];
    if (data)
    {
        id jsonData = [data JSONValue];
        id responseEntity = [self getOutputEntiy:jsonData];
        if (!responseEntity)
        {
            NSString *errorStr = [NSString stringWithFormat:@"内部错误:%@.getOutputEntiy返回了空", NSStringFromClass(self.class)];
            NSAssert(NO, errorStr);
            if(_failedBlock) _failedBlock(self,  herr(kInnerErrorCode, errorStr));
        }
        else if ([responseEntity isKindOfClass:[NSError class]])
        {
            NSAssert(NO, [responseEntity description]);
            if (_failedBlock) _failedBlock(self, responseEntity);
        }
        else if(_sucessBlock) _sucessBlock(nil, responseEntity);
    }
}

- (void)cacheLogic:(NSString *)queueName
{
    NSString *cacheKey = [self cacheKey];
    switch (self.cacheType) {
        case HFileCacheTypeNone:
        {
            [self startWithQueueName:queueName];
            break;
        }
        case HFileCacheTypeBoth:
        {
            if([self isCacheUseable:cacheKey])
            {
                [self loadCache:cacheKey];
            }
            else
            {
                [self loadCache:cacheKey];
                [self startWithQueueName:queueName];
            }
            break;
        }
        case HFileCacheTypeExclusive:
        {
            if (![self isCacheUseable:cacheKey])
            {
                [self startWithQueueName:queueName];
            }
            else
            {
                [self loadCache:cacheKey];
                //解除保持
                _failedBlock = nil;
                _sucessBlock = nil;
                _holdSelf = nil;
            }
            break;
        }
        case HFileCacheTypeForceRefresh:
        {
            [self startWithQueueName:queueName];
            break;
        }
        default:
            break;
    }
}

#pragma mark - queue
+ (void)initQueueWithName:(NSString *)queueName maxMaxConcurrent:(NSInteger)maxMaxConcurrent
{
    [HNetworkDAOManager initQueueWithName:queueName maxMaxConcurrent:maxMaxConcurrent];
}

+ (BOOL)cancelQueueWithName:(NSString*)queueName
{
    if(queueName)
    {
        [[HNetworkDAOManager instance] destoryOperationQueueWithName:queueName];
        return YES;
    }
    return NO;
}
#pragma mark - netWorking finished

- (void)requestFinishedSucessWithInfo:(id)responInfo
{
    id responseEntity = [self getOutputEntiy:responInfo];
    if (!responseEntity)
    {
        NSString *errorStr = [NSString stringWithFormat:@"inner error:%@.getOutputEntiy return nil", NSStringFromClass(self.class)];
        [self requestFinishedFailureWithError:herr(kInnerErrorCode,  errorStr)];
        return;
    }
    if ([responseEntity isKindOfClass:[NSError class]])
    {
        [self requestFinishedFailureWithError:responseEntity];
        return;
    }

    //record
    if (self.cacheType != HFileCacheTypeNone)
    {
        NSData *orignalData = self.responseData;
        [[HFileCache shareCache] setData:orignalData forKey:[self cacheKey]
                               expire:[NSDate dateWithTimeInterval:self.cacheDuration sinceDate:[NSDate date]]];
    }


    if(_sucessBlock)
        _sucessBlock(self, responseEntity);
    
    //clear
    _failedBlock = nil;
    _sucessBlock = nil;
    _holdSelf = nil;
}


- (void)requestFinishedFailureWithError:(NSError*)error
{
    NSLog(@"error:%li,%@,%@ url = %@/%@", (long)error.code,error.domain,error.localizedDescription, self.baseURL, self.pathURL);
    
    if(_failedBlock)
        _failedBlock(self,  error);
    
    //clear
    _failedBlock = nil;
    _sucessBlock = nil;
    _holdSelf = nil;
}

- (void)downloadFinished:(HDownloadFileInfo *)info
{
    if(_sucessBlock)
        _sucessBlock(self, info);
    
    //clear
    _failedBlock = nil;
    _sucessBlock = nil;
    _holdSelf = nil;
}



#pragma mark - downdload

- (NSString *)createTempFilePath:(NSString *)url
{
    NSDate *date = [NSDate new];
    return [[HFileCache shareCache] cachePathForKey:[NSString stringWithFormat:@"%.3f|%@", [date timeIntervalSince1970], url]];
}

#pragma mark - other
- (void)holdNetwork
{
    _holdSelf = self;
}
- (void)unHoldNetwork
{
    _holdSelf = nil;
}
@end


#pragma mark - deserialize

@interface HNEntityDeserializer ()
@property (nonatomic) Class entityClass;
@end

@implementation HNEntityDeserializer

+ (instancetype)deserializerWithClass:(Class)aClass
{
    HNEntityDeserializer *obj = [self new];
    obj.entityClass = aClass;
    return obj;
}
- (id)deserialization:(id)rudeData
{
    if(self.entityClass == NULL)
    {
        NSString *errorMsg = [NSString stringWithFormat:@"%s,无法获取到对应entity类名的类，未能将返回结果处理成entity", __FUNCTION__];
        return herr(kDataFormatErrorCode, errorMsg);
    }
    //create entity

    HEntity *entity = (HEntity *)[[self.entityClass alloc]init];
    if (![entity isKindOfClass:[HEntity class]])
    {

        NSString *errorMsg = [NSString stringWithFormat:@"%s, 不是Hentity的子类，未能将返回结果处理成entity", __FUNCTION__];
        return herr(kDataFormatErrorCode, errorMsg);
    }
    [entity setWithDictionary:rudeData];
    if (entity.format_error)
    {
        return herr(kDataFormatErrorCode, entity.format_error);
    }
    else return entity;

}
@end






@interface HNArrayDeserializer ()
@property (nonatomic) Class objClass;
@end

@implementation HNArrayDeserializer

+ (instancetype)deserializerWithClass:(Class)aClass
{
    HNArrayDeserializer *obj = [self new];
    obj.objClass = aClass;
    return obj;
}
- (Class)classForItem:(NSDictionary *)dict
{
    return self.objClass;
}
- (id)deserialization:(id)rudeData
{
    if (![rudeData isKindOfClass:[NSArray class]])
    {
        NSString *errInfo = [NSString stringWithFormat:@"%@:%@", NSStringFromClass(self.class), @"expect a NSArray"];
        return herr(kDataFormatErrorCode, errInfo);
    }
    NSArray *dataArray = rudeData;
    NSMutableArray *res = [NSMutableArray new];
    for (NSDictionary *dict in dataArray)
    {
        Class targetClass = [self classForItem:dict];
        if(targetClass == NULL)
        {
            NSString *errorMsg = [NSString stringWithFormat:@"%@: cannot get entity class", NSStringFromClass(self.class)];
            return herr(kDataFormatErrorCode, errorMsg);
        }
        
        if (![targetClass isSubclassOfClass:[HEntity class]])
        {
            NSString *errorMsg = [NSString stringWithFormat:@"%@: is not subclass of HEntity", NSStringFromClass(self.class)];
            return herr(kDataFormatErrorCode, errorMsg);
        }
        
        HEntity *entity = (HEntity *)[[targetClass alloc]init];
        [entity setWithDictionary:dict];
        if (entity.format_error)
        {
            NSString *errInfo = [NSString stringWithFormat:@"%@:%@", NSStringFromClass(self.class), entity.format_error];
            return herr(kDataFormatErrorCode, errInfo);
        }
        [res addObject:entity];
    }
    return res;
}

@end

@interface HNManualDeserializer ()
@property (nonatomic, copy) DeserializeBlock block;
@end

@implementation HNManualDeserializer

+ (instancetype)deserializerWithBlock:(DeserializeBlock)block
{
    HNManualDeserializer *obj = [self new];
    obj.block = block;
    return obj;
}
- (id)deserialization:(id)rudeData
{
    if (self.block) return self.block(rudeData);
    else return nil;
}
@end


@implementation HDownloadFileInfo
@end