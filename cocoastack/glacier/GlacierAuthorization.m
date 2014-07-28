//
//  GlacierAuthorization.m
//
//  Created by Stefan Reitshamer on 9/8/12.
//
//

#import "GlacierAuthorization.h"
#import "HTTPConnection.h"
#import "GlacierSigner.h"
#import "AWSRegion.h"
#import "ISO8601Date.h"
#import "SHA256Hash.h"
#import "NSString_extra.h"


@implementation GlacierAuthorization
- (id)initWithAWSRegion:(AWSRegion *)theAWSRegion connection:(id <HTTPConnection>)theConn requestBody:(NSData *)theRequestBody accessKey:(NSString *)theAccessKey signer:(id <GlacierSigner>)theSigner {
    if (self = [super init]) {
        awsRegion = [theAWSRegion retain];
        conn = [theConn retain];
        requestBody = [theRequestBody retain];
        accessKey = [theAccessKey retain];
        signer = [theSigner retain];
    }
    return self;
}
- (void)dealloc {
    [awsRegion release];
    [conn release];
    [requestBody release];
    [accessKey release];
    [signer release];
    [super dealloc];
}


#pragma mark NSObject
- (NSString *)description {
    NSMutableString *canonicalRequest = [[[NSMutableString alloc] init] autorelease];
    [canonicalRequest appendString:[conn requestMethod]];
    [canonicalRequest appendString:@"\n"];
    
    [canonicalRequest appendString:[conn requestPathInfo]];
    [canonicalRequest appendString:@"\n"];
    
    if ([conn requestQueryString] != nil) {
        NSString *query = [(NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                               (CFStringRef)[conn requestQueryString],
                                                                               (CFStringRef)@"=",
                                                                               (CFStringRef)@"!*'();:@&+$,/?%#[]",
                                                                               kCFStringEncodingUTF8) autorelease];
        
        [canonicalRequest appendString:query];
    }
    [canonicalRequest appendString:@"\n"];
    
    // Add sorted canonical headers:
    NSMutableArray *theHeaders = [NSMutableArray array];
    for (NSString *headerName in [conn requestHeaderKeys]) {
        NSString *lower = [headerName lowercaseString];
        [theHeaders addObject:[NSString stringWithFormat:@"%@:%@\n", lower, [conn requestHeaderForKey:headerName]]];
    }
    [theHeaders sortUsingSelector:@selector(compare:)];
    for (NSString *hdr in theHeaders) {
        [canonicalRequest appendString:hdr];
    }
    
    // Add a newline:
    [canonicalRequest appendString:@"\n"];
    
    NSMutableArray *theSortedLowercaseHeaderNames = [NSMutableArray array];
    for (NSString *headerName in [conn requestHeaderKeys]) {
        [theSortedLowercaseHeaderNames addObject:[headerName lowercaseString]];
    }
    [theSortedLowercaseHeaderNames sortUsingSelector:@selector(compare:)];
    
    // Create list of names of the signed headers:
    NSMutableString *namesOfSignedHeaders = [NSMutableString string];
    NSString *separator = @"";
    for (NSString *name in theSortedLowercaseHeaderNames) {
        [namesOfSignedHeaders appendString:separator];
        separator = @";";
        [namesOfSignedHeaders appendString:name];
    }
    
    // Add list of signed headers (header names):
    [canonicalRequest appendString:namesOfSignedHeaders];
    [canonicalRequest appendString:@"\n"];
    
    // Add hash of payload:
    NSData *payload = requestBody;
    if (payload == nil) {
        payload = [NSData data];
    }
    [canonicalRequest appendString:[NSString hexStringWithData:[SHA256Hash hashData:payload]]];


    NSString *dateStamp = [ISO8601Date basicDateStringFromDate:[conn date]];
    NSString *dateTime = [ISO8601Date basicDateTimeStringFromDate:[conn date]];
    
    NSString *scope = [NSString stringWithFormat:@"%@/%@/glacier/aws4_request", dateStamp, [awsRegion regionName]];
    NSString *signingCredentials = [NSString stringWithFormat:@"%@/%@", accessKey, scope];
    
    HSLogTrace(@"canonical string = %@", canonicalRequest);
    
    NSData *canonicalRequestData = [canonicalRequest dataUsingEncoding:NSUTF8StringEncoding];
    NSString *canonicalRequestHashHex = [NSString hexStringWithData:[SHA256Hash hashData:canonicalRequestData]];
    
    NSString *stringToSign = [NSString stringWithFormat:@"AWS4-HMAC-SHA256\n%@\n%@\n%@", dateTime, scope, canonicalRequestHashHex];
    
    HSLogTrace(@"stringToSign = %@", stringToSign);
    
    //FIXME: Extract the service name from the hostname (see AwsHostNameUtils.parseServiceName() method in Java AWS SDK).
    NSString *signature = [signer signString:stringToSign withDateStamp:dateStamp regionName:[awsRegion regionName] serviceName:@"glacier"];
    
    NSString *ret = [[[NSString alloc] initWithFormat:@"AWS4-HMAC-SHA256 Credential=%@, SignedHeaders=%@, Signature=%@", signingCredentials, namesOfSignedHeaders, signature] autorelease];
    return ret;
}
@end
