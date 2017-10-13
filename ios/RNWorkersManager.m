//XXX support CodePush
//XXX prevent yellow/redbox messages from routing to worker

#import "RNWorkersManager.h"
#import "RNWorkersDevSettings.h"
#import "RNWorkersInstanceManager.h"
#import "RNWorkersBridge.h"
#import <React/RCTAssert.h>
#import <React/RCTBundleURLProvider.h>
#import <React/RCTLog.h>

@implementation RNWorkersInstanceData
@end

@implementation RNWorkersManager
{
  NSMutableDictionary *_bridges;
  NSMutableDictionary *_workers;
  NSMutableSet *_ports;
}

RCT_EXPORT_MODULE(WorkersManager);

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"message"];
}

- (instancetype)init
{
  if (self = [super init]) {
    _bridges = [NSMutableDictionary dictionary];
    _workers = [NSMutableDictionary dictionary];
    _ports = [NSMutableSet set];
  }
  return self;
}

- (void)invalidate {
  for (NSNumber *key in _bridges) {
    RCTBridge *bridge = _bridges[key];
    [bridge invalidate];
  }
  [_bridges removeAllObjects];
  [_workers removeAllObjects];
}

- (void)setWorker:(RNWorkersInstanceManager *)worker
           forKey:(NSNumber *)key
{
  [_workers[key] invalidate];
  [_workers setObject:worker forKey:key];
}

RCT_EXPORT_METHOD(startWorker:(nonnull NSNumber *)key
                   bundleRoot:(NSString *)root
               bundleResource:(NSString *)resource
                  bundlerPort:(nonnull NSNumber *)port
                     resolver:(RCTPromiseResolveBlock)resolve
                     rejecter:(RCTPromiseRejectBlock)reject)
{
  RCTAssert(!_workers[key], @"Key already in use");

  // Resolve worker URL using the bundle root and resource, and the bundler port.

  BOOL uniquePort = NO;
  NSURL *workerURL = [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:root fallbackResource:resource];

  if (port > 0) {
    NSURLComponents *components = [NSURLComponents componentsWithURL:workerURL resolvingAgainstBaseURL:NO];
    if (components.port.unsignedIntegerValue == kRCTBundleURLProviderDefaultPort) {
      if ([_ports containsObject:port]) {
        RCTLogError(@"Bundler port %@ is already in use by another worker.", port);
      } else {
        uniquePort = YES;
        components.port = port;
        [_ports addObject:port];
        workerURL = components.URL;
      }
    }
  }

  // Instantiate the worker bridge with a provider that initializes worker instance managers.
  // The provider will be invoked every time the bridge restarts, which happens if the bridge
  // transitions from on-device execution to remote debugging.

  __block RNWorkersInstanceData *workerData = [[RNWorkersInstanceData alloc] init];
  workerData.key = key;
  workerData.bundleRoot = root;
  workerData.bundlerPort = uniquePort ? port : nil;
  workerData.startedBlock = resolve;
  workerData.parentManager = self;

  RCTBridgeModuleListProvider workerModuleProvider = ^NSArray<id<RCTBridgeModule>> *{
    RNWorkersInstanceManager *worker = [[RNWorkersInstanceManager alloc] initWithData:workerData];
    RNWorkersDevSettings *devSettings = [[RNWorkersDevSettings alloc] initWithData:workerData];
    [workerData.parentManager setWorker:worker forKey:workerData.key];
    return @[worker, devSettings];
  };

  RNWorkersBridge *workerBridge = [[RNWorkersBridge alloc] initWithBundleURL:workerURL moduleProvider:workerModuleProvider launchOptions:nil];
  [_bridges setObject:workerBridge forKey:key];
}

RCT_EXPORT_METHOD(stopWorker:(nonnull NSNumber *)key)
{
  RNWorkersBridge *bridge = _bridges[key];
  RCTAssert(bridge, @"Expected bridge for key");
  [bridge invalidate];

  [_bridges removeObjectForKey:key];
  [_workers removeObjectForKey:key];
}

RCT_EXPORT_METHOD(postMessage:(nonnull NSNumber *)key
                      message:(nonnull NSString *)message)
{
  RNWorkersInstanceManager *worker = _workers[key];
  RCTAssert(worker, @"Expected worker for key");
  NSDictionary *body = @{@"key": key, @"message": message};
  [worker sendEventWithName:@"message" body:body];
}

@end
