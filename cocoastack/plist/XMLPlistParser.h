/*
 Copyright (c) 2009-2014, Stefan Reitshamer http://www.haystacksoftware.com
 
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 * Neither the names of PhotoMinds LLC or Haystack Software, nor the names of
 their contributors may be used to endorse or promote products derived from
 this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


@protocol XMLPlistParserDelegate;

@interface XMLPlistParser : NSObject <NSXMLParserDelegate> {
    NSString *path;
    id <XMLPlistParserDelegate> delegate;
    NSXMLParser *parser;
    NSMutableArray *keyNames;
    NSMutableArray *containerNames;
    NSMutableString *currentStringValue;
}
- (id)initWithContentsOfPath:(NSString *)thePath;
- (void)setDelegate:(id <XMLPlistParserDelegate>)theDelegate;
- (void)parse;
@end

@protocol XMLPlistParserDelegate <NSObject> 
- (void)parser:(XMLPlistParser *)parser didStartArray:(NSString *)key;
- (void)parser:(XMLPlistParser *)parser didEndArray:(NSString *)key;
- (void)parser:(XMLPlistParser *)parser didStartDict:(NSString *)key;
- (void)parser:(XMLPlistParser *)parser didEndDict:(NSString *)key;
- (void)parser:(XMLPlistParser *)parser foundString:(NSString *)value key:(NSString *)key;
- (void)parser:(XMLPlistParser *)parser foundInteger:(long long)value key:(NSString *)key;
- (void)parser:(XMLPlistParser *)parser foundBoolean:(BOOL)value key:(NSString *)key;
- (void)parser:(XMLPlistParser *)parser foundReal:(double)value key:(NSString *)key;

- (void)parser:(XMLPlistParser *)parser didStartArrayInArray:(NSString *)arrayName;
- (void)parser:(XMLPlistParser *)parser didEndArrayInArray:(NSString *)arrayName;
- (void)parser:(XMLPlistParser *)parser didStartDictInArray:(NSString *)arrayName;
- (void)parser:(XMLPlistParser *)parser didEndDictInArray:(NSString *)arrayName;
- (void)parser:(XMLPlistParser *)parser foundString:(NSString *)value inArray:(NSString *)arrayName;
- (void)parser:(XMLPlistParser *)parser foundInteger:(long long)value inArray:(NSString *)arrayName;
- (void)parser:(XMLPlistParser *)parser foundBoolean:(BOOL)value inArray:(NSString *)arrayName;
- (void)parser:(XMLPlistParser *)parser foundReal:(double)value inArray:(NSString *)arrayName;
- (void)parser:(XMLPlistParser *)parser parseErrorOccurred:(NSError *)parseError lineNumber:(NSInteger)theLineNumber columnNumber:(NSInteger)theColumnNumber;
- (void)parserDidEndPlist:(XMLPlistParser *)parser;
@end
