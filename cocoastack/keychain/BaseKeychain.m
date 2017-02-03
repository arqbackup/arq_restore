/*
 Copyright (c) 2009-2017, Haystack Software LLC https://www.arqbackup.com
 
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


#import "BaseKeychain.h"
#import "KeychainItem.h"


@implementation BaseKeychain
- (NSString *)errorDomain {
    return @"KeychainErrorDomain";
}
- (NSArray *)existingAccountNamesWithLabel:(NSString *)theLabel error:(NSError **)error {
    NSMutableDictionary *query = [[[NSMutableDictionary alloc] init] autorelease];
    [query setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    [query setObject:theLabel forKey:(id)kSecAttrLabel];
    [query setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];
    [query setObject:(id)kSecMatchLimitAll forKey:(id)kSecMatchLimit];
    CFArrayRef arrayRef;
    OSStatus oss = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&arrayRef);
    if (oss != errSecSuccess) {
        if (oss == errSecItemNotFound) {
            return [NSArray array];
        }
        SETNSERROR([self errorDomain], oss, @"failed to query for keychain items: %@", [self descriptionForOSStatus:oss]);
        return nil;
    }
    NSMutableArray *ret = [NSMutableArray array];
    for (NSDictionary *attrs in (NSArray *)arrayRef) {
        NSString *acct = [attrs objectForKey:(id)kSecAttrAccount];
        if (acct != nil) {
            [ret addObject:acct];
        }
    }
    CFRelease(arrayRef);
    return ret;
}
- (KeychainItem *)existingItemWithLabel:(NSString *)theLabel account:(NSString *)theAccount error:(NSError **)error {
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    [query setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    [query setObject:theLabel forKey:(id)kSecAttrLabel];
    [query setObject:theAccount forKey:(id)kSecAttrAccount];
    
    [query setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];
    [query setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
    
    CFTypeRef result = NULL;
    OSStatus oss = SecItemCopyMatching((CFDictionaryRef)query, &result);
    if (oss != errSecSuccess) {
        if (oss == errSecItemNotFound) {
            SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"No keychain item found with label %@ account %@", theLabel, theAccount);
        } else {
            SETNSERROR([self errorDomain], oss, @"Error reading keychain item with label=%@ account=%@: %@", theLabel, theAccount, [self descriptionForOSStatus:oss]);
        }
        return nil;
    }
    NSData *thePasswordData = (NSData *)result;
    KeychainItem *ret = [[[KeychainItem alloc] initWithLabel:theLabel account:theAccount passwordData:thePasswordData] autorelease];
    CFRelease(result);
    return ret;
}
- (KeychainItem *)createOrUpdateItemWithLabel:(NSString *)theLabel account:(NSString *)theAccount password:(NSString *)thePassword error:(NSError **)error {
    return [self createOrUpdateItemWithLabel:theLabel account:theAccount passwordData:[thePassword dataUsingEncoding:NSUTF8StringEncoding] error:error];
}
- (KeychainItem *)createOrUpdateItemWithLabel:(NSString *)theLabel account:(NSString *)theAccount passwordData:(NSData *)thePasswordData error:(NSError **)error {
    return [self createOrUpdateItemWithLabel:theLabel account:theAccount passwordData:thePasswordData trustedAppPaths:nil error:error];
}
- (KeychainItem *)createOrUpdateItemWithLabel:(NSString *)theLabel account:(NSString *)theAccount passwordData:(NSData *)thePasswordData trustedAppPaths:(NSArray *)paths error:(NSError **)error {
    if (thePasswordData == nil) {
        SETNSERROR([self errorDomain], -1, @"password for keychain item may not be nil");
        return nil;
    }
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    [query setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    [query setObject:theLabel forKey:(id)kSecAttrLabel];
    [query setObject:theAccount forKey:(id)kSecAttrAccount];
    [query setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];
    CFTypeRef result = NULL;
    OSStatus oss = SecItemCopyMatching((CFDictionaryRef)query, &result);
    if (oss == errSecSuccess) {
        CFRelease(result);
        [query removeObjectForKey:(id)kSecMatchLimit];
        NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObject:thePasswordData forKey:(id)kSecValueData];
//        if (paths != nil) {
//            SecAccessRef access = [self createAccessForAppPaths:paths error:error];
//            if (access == NULL) {
//                return nil;
//            }
//            [attributes setObject:(id)access forKey:kSecAttrAccess];
//            CFRelease(access);
//        }
        HSLogDebug(@"updating keychain item: label=%@ account=%@", theLabel, theAccount);
        oss = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)attributes);
        if (oss != errSecSuccess) {
            HSLogError(@"failed to update keychain item: label=%@ account=%@ error=%d %@", theLabel, theAccount, oss, [self descriptionForOSStatus:oss]);
        }
    } else {
        NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
        [attrs setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
        [attrs setObject:theLabel forKey:(id)kSecAttrLabel];
        [attrs setObject:theLabel forKey:(id)kSecAttrService];
        [attrs setObject:theAccount forKey:(id)kSecAttrAccount];
        [attrs setObject:thePasswordData forKey:(id)kSecValueData];
        if (paths != nil) {
            SecAccessRef access = [self createAccessForAppPaths:paths error:error];
            if (access == NULL) {
                return nil;
            }
            [attrs setObject:(id)access forKey:(NSString *)kSecAttrAccess];
            CFRelease(access);
        }
        
        HSLogDebug(@"adding keychain item: label=%@ account=%@", theLabel, theAccount);
        oss = SecItemAdd((CFDictionaryRef)attrs, NULL);
        if (oss != errSecSuccess) {
            HSLogError(@"failed to add keychain item: label=%@ account=%@ error=%d %@", theLabel, theAccount, oss, [self descriptionForOSStatus:oss]);
        }
    }
    
    if (oss != errSecSuccess) {
        SETNSERROR([self errorDomain], oss, @"%@", [self descriptionForOSStatus:oss]);
        return nil;
    }
    return [[[KeychainItem alloc] initWithLabel:theLabel account:theAccount passwordData:thePasswordData] autorelease];
}
- (BOOL)destroyItemForLabel:(NSString *)theLabel account:(NSString *)theAccount error:(NSError **)error {
    if ([theLabel length] == 0) {
        SETNSERROR([self errorDomain], -1, @"label may not be empty");
        return NO;
    }
    if ([theAccount length] == 0) {
        SETNSERROR([self errorDomain], -1, @"account may not be empty");
        return NO;
    }
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    [query setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    [query setObject:theLabel forKey:(id)kSecAttrLabel];
    [query setObject:theAccount forKey:(id)kSecAttrAccount];
    
    HSLogDebug(@"destroying keychain item: label=%@ account=%@", theLabel, theAccount);
    
    OSStatus oss = SecItemDelete((CFDictionaryRef)query);
    if (oss != errSecSuccess && oss != errSecItemNotFound) {
        SETNSERROR([self errorDomain], oss, @"%@", [self descriptionForOSStatus:oss]);
        return NO;
    }
    return YES;
}


- (SecAccessRef)createAccessForAppPaths:(NSArray *)theAppPaths error:(NSError **)error {
    NSMutableArray *trustedApps = [NSMutableArray array];
    for (NSString *appPath in theAppPaths) {
        SecTrustedApplicationRef appRef = NULL;
        OSStatus oss = SecTrustedApplicationCreateFromPath([appPath fileSystemRepresentation], &appRef);
        if (oss) {
            NSString *msg = [(NSString *)SecCopyErrorMessageString(oss, NULL) autorelease];
            SETNSERROR([self errorDomain], oss, @"SecTrustedApplicationCreateFromPath(%@): %@", appPath, msg);
            return nil;
        }
        [trustedApps addObject:(id)appRef];
    }
    SecAccessRef access = NULL;
    OSStatus oss = SecAccessCreate((CFStringRef)@"arq_restore", (CFArrayRef)trustedApps, &access);
    if (oss) {
        NSString *msg = [(NSString *)SecCopyErrorMessageString(oss, NULL) autorelease];
        SETNSERROR([self errorDomain], oss, @"SecAccessCreate: %@", msg);
        return nil;
    }
    return access;
}

- (NSString *)descriptionForOSStatus:(OSStatus)oss {
    switch (oss) {
        case errSecSuccess:
            return @"No error.";
        case errSecUnimplemented:
            return @"Function or operation not implemented.";
        case errSecParam:
            return @"One or more parameters passed to a function were not valid.";
        case errSecAllocate:
            return @"Failed to allocate memory.";
        case errSecNotAvailable:
            return @"No keychain is available. You may need to restart your computer.";
        case errSecAuthFailed:
            return @"The user name or passphrase you entered is not correct.";
        case errSecDuplicateItem:
            return @"The specified item already exists in the keychain.";
        case errSecItemNotFound:
            return @"The specified item could not be found in the keychain.";
        case errSecInteractionNotAllowed:
            return @"User interaction is not allowed.";
        case errSecDecode:
            return @"Unable to decode the provided data.";
#if !TARGET_OS_IPHONE
        case errSecReadOnly:
            return @"This keychain cannot be modified.";
        case errSecNoSuchKeychain:
            return @"The specified keychain could not be found.";
        case errSecInvalidKeychain:
            return @"The specified keychain is not a valid keychain file.";
        case errSecDuplicateKeychain:
            return @"A keychain with the same name already exists.";
        case errSecDuplicateCallback:
            return @"The specified callback function is already installed.";
        case errSecInvalidCallback:
            return @"The specified callback function is not valid.";
        case errSecBufferTooSmall:
            return @"There is not enough memory available to use the specified item.";
        case errSecDataTooLarge:
            return @"This item contains information which is too large or in a format that cannot be displayed.";
        case errSecNoSuchAttr:
            return @"The specified attribute does not exist.";
        case errSecInvalidItemRef:
            return @"The specified item is no longer valid. It may have been deleted from the keychain.";
        case errSecInvalidSearchRef:
            return @"Unable to search the current keychain.";
        case errSecNoSuchClass:
            return @"The specified item does not appear to be a valid keychain item.";
        case errSecNoDefaultKeychain:
            return @"A default keychain could not be found.";
        case errSecReadOnlyAttr:
            return @"The specified attribute could not be modified.";
        case errSecWrongSecVersion:
            return @"This keychain was created by a different version of the system software and cannot be opened.";
        case errSecKeySizeNotAllowed:
            return @"This item specifies a key size which is too large.";
        case errSecNoStorageModule:
            return @"A required component (data storage module) could not be loaded. You may need to restart your computer.";
        case errSecNoCertificateModule:
            return @"A required component (certificate module) could not be loaded. You may need to restart your computer.";
        case errSecNoPolicyModule:
            return @"A required component (policy module) could not be loaded. You may need to restart your computer.";
        case errSecInteractionRequired:
            return @"User interaction is required, but is currently not allowed.";
        case errSecDataNotAvailable:
            return @"The contents of this item cannot be retrieved.";
        case errSecDataNotModifiable:
            return @"The contents of this item cannot be modified.";
        case errSecCreateChainFailed:
            return @"One or more certificates required to validate this certificate cannot be found.";
        case errSecInvalidPrefsDomain:
            return @"The specified preferences domain is not valid.";
        case errSecInDarkWake:
            return @"In dark wake, no UI possible";
        case errSecACLNotSimple:
            return @"The specified access control list is not in standard (simple) form.";
        case errSecPolicyNotFound:
            return @"The specified policy cannot be found.";
        case errSecInvalidTrustSetting:
            return @"The specified trust setting is invalid.";
        case errSecNoAccessForItem:
            return @"The specified item has no access control.";
        case errSecInvalidOwnerEdit:
            return @"Invalid attempt to change the owner of this item.";
        case errSecTrustNotAvailable:
            return @"No trust results are available.";
        case errSecUnsupportedFormat:
            return @"Import/Export format unsupported.";
        case errSecUnknownFormat:
            return @"Unknown format in import.";
        case errSecKeyIsSensitive:
            return @"Key material must be wrapped for export.";
        case errSecMultiplePrivKeys:
            return @"An attempt was made to import multiple private keys.";
        case errSecPassphraseRequired:
            return @"Passphrase is required for import/export.";
        case errSecInvalidPasswordRef:
            return @"The password reference was invalid.";
        case errSecInvalidTrustSettings:
            return @"The Trust Settings Record was corrupted.";
        case errSecNoTrustSettings:
            return @"No Trust Settings were found.";
        case errSecPkcs12VerifyFailure:
            return @"MAC verification failed during PKCS12 import (wrong password?)";
        case errSecNotSigner:
            return @"A certificate was not signed by its proposed parent.";
        case errSecServiceNotAvailable:
            return @"The required service is not available.";
        case errSecInsufficientClientID:
            return @"The client ID is not correct.";
        case errSecDeviceReset:
            return @"A device reset has occurred.";
        case errSecDeviceFailed:
            return @"A device failure has occurred.";
        case errSecAppleAddAppACLSubject:
            return @"Adding an application ACL subject failed.";
        case errSecApplePublicKeyIncomplete:
            return @"The public key is incomplete.";
        case errSecAppleSignatureMismatch:
            return @"A signature mismatch has occurred.";
        case errSecAppleInvalidKeyStartDate:
            return @"The specified key has an invalid start date.";
        case errSecAppleInvalidKeyEndDate:
            return @"The specified key has an invalid end date.";
        case errSecConversionError:
            return @"A conversion error has occurred.";
        case errSecAppleSSLv2Rollback:
            return @"A SSLv2 rollback error has occurred.";
        case errSecDiskFull:
            return @"The disk is full.";
        case errSecQuotaExceeded:
            return @"The quota was exceeded.";
        case errSecFileTooBig:
            return @"The file is too big.";
        case errSecInvalidDatabaseBlob:
            return @"The specified database has an invalid blob.";
        case errSecInvalidKeyBlob:
            return @"The specified database has an invalid key blob.";
        case errSecIncompatibleDatabaseBlob:
            return @"The specified database has an incompatible blob.";
        case errSecIncompatibleKeyBlob:
            return @"The specified database has an incompatible key blob.";
        case errSecHostNameMismatch:
            return @"A host name mismatch has occurred.";
        case errSecUnknownCriticalExtensionFlag:
            return @"There is an unknown critical extension flag.";
        case errSecNoBasicConstraints:
            return @"No basic constraints were found.";
        case errSecNoBasicConstraintsCA:
            return @"No basic CA constraints were found.";
        case errSecInvalidAuthorityKeyID:
            return @"The authority key ID is not valid.";
        case errSecInvalidSubjectKeyID:
            return @"The subject key ID is not valid.";
        case errSecInvalidKeyUsageForPolicy:
            return @"The key usage is not valid for the specified policy.";
        case errSecInvalidExtendedKeyUsage:
            return @"The extended key usage is not valid.";
        case errSecInvalidIDLinkage:
            return @"The ID linkage is not valid.";
        case errSecPathLengthConstraintExceeded:
            return @"The path length constraint was exceeded.";
        case errSecInvalidRoot:
            return @"The root or anchor certificate is not valid.";
        case errSecCRLExpired:
            return @"The CRL has expired.";
        case errSecCRLNotValidYet:
            return @"The CRL is not yet valid.";
        case errSecCRLNotFound:
            return @"The CRL was not found.";
        case errSecCRLServerDown:
            return @"The CRL server is down.";
        case errSecCRLBadURI:
            return @"The CRL has a bad Uniform Resource Identifier.";
        case errSecUnknownCertExtension:
            return @"An unknown certificate extension was encountered.";
        case errSecUnknownCRLExtension:
            return @"An unknown CRL extension was encountered.";
        case errSecCRLNotTrusted:
            return @"The CRL is not trusted.";
        case errSecCRLPolicyFailed:
            return @"The CRL policy failed.";
        case errSecIDPFailure:
            return @"The issuing distribution point was not valid.";
        case errSecSMIMEEmailAddressesNotFound:
            return @"An email address mismatch was encountered.";
        case errSecSMIMEBadExtendedKeyUsage:
            return @"The appropriate extended key usage for SMIME was not found.";
        case errSecSMIMEBadKeyUsage:
            return @"The key usage is not compatible with SMIME.";
        case errSecSMIMEKeyUsageNotCritical:
            return @"The key usage extension is not marked as critical.";
        case errSecSMIMENoEmailAddress:
            return @"No email address was found in the certificate.";
        case errSecSMIMESubjAltNameNotCritical:
            return @"The subject alternative name extension is not marked as critical.";
        case errSecSSLBadExtendedKeyUsage:
            return @"The appropriate extended key usage for SSL was not found.";
        case errSecOCSPBadResponse:
            return @"The OCSP response was incorrect or could not be parsed.";
        case errSecOCSPBadRequest:
            return @"The OCSP request was incorrect or could not be parsed.";
        case errSecOCSPUnavailable:
            return @"OCSP service is unavailable.";
        case errSecOCSPStatusUnrecognized:
            return @"The OCSP server did not recognize this certificate.";
        case errSecEndOfData:
            return @"An end-of-data was detected.";
        case errSecIncompleteCertRevocationCheck:
            return @"An incomplete certificate revocation check occurred.";
        case errSecNetworkFailure:
            return @"A network failure occurred.";
        case errSecOCSPNotTrustedToAnchor:
            return @"The OCSP response was not trusted to a root or anchor certificate.";
        case errSecRecordModified:
            return @"The record was modified.";
        case errSecOCSPSignatureError:
            return @"The OCSP response had an invalid signature.";
        case errSecOCSPNoSigner:
            return @"The OCSP response had no signer.";
        case errSecOCSPResponderMalformedReq:
            return @"The OCSP responder was given a malformed request.";
        case errSecOCSPResponderInternalError:
            return @"The OCSP responder encountered an internal error.";
        case errSecOCSPResponderTryLater:
            return @"The OCSP responder is busy, try again later.";
        case errSecOCSPResponderSignatureRequired:
            return @"The OCSP responder requires a signature.";
        case errSecOCSPResponderUnauthorized:
            return @"The OCSP responder rejected this request as unauthorized.";
        case errSecOCSPResponseNonceMismatch:
            return @"The OCSP response nonce did not match the request.";
        case errSecCodeSigningBadCertChainLength:
            return @"Code signing encountered an incorrect certificate chain length.";
        case errSecCodeSigningNoBasicConstraints:
            return @"Code signing found no basic constraints.";
        case errSecCodeSigningNoExtendedKeyUsage:
            return @"Code signing found no extended key usage.";
        case errSecCodeSigningDevelopment:
            return @"Code signing indicated use of a development-only certificate.";
        case errSecResourceSignBadCertChainLength:
            return @"Resource signing has encountered an incorrect certificate chain length.";
        case errSecResourceSignBadExtKeyUsage:
            return @"Resource signing has encountered an error in the extended key usage.";
        case errSecTrustSettingDeny:
            return @"The trust setting for this policy was set to Deny.";
        case errSecInvalidSubjectName:
            return @"An invalid certificate subject name was encountered.";
        case errSecUnknownQualifiedCertStatement:
            return @"An unknown qualified certificate statement was encountered.";
        case errSecMobileMeRequestQueued:
            return @"The MobileMe request will be sent during the next connection.";
        case errSecMobileMeRequestRedirected:
            return @"The MobileMe request was redirected.";
        case errSecMobileMeServerError:
            return @"A MobileMe server error occurred.";
        case errSecMobileMeServerNotAvailable:
            return @"The MobileMe server is not available.";
        case errSecMobileMeServerAlreadyExists:
            return @"The MobileMe server reported that the item already exists.";
        case errSecMobileMeServerServiceErr:
            return @"A MobileMe service error has occurred.";
        case errSecMobileMeRequestAlreadyPending:
            return @"A MobileMe request is already pending.";
        case errSecMobileMeNoRequestPending:
            return @"MobileMe has no request pending.";
        case errSecMobileMeCSRVerifyFailure:
            return @"A MobileMe CSR verification failure has occurred.";
        case errSecMobileMeFailedConsistencyCheck:
            return @"MobileMe has found a failed consistency check.";
        case errSecNotInitialized:
            return @"A function was called without initializing CSSM.";
        case errSecInvalidHandleUsage:
            return @"The CSSM handle does not match with the service type.";
        case errSecPVCReferentNotFound:
            return @"A reference to the calling module was not found in the list of authorized callers.";
        case errSecFunctionIntegrityFail:
            return @"A function address was not within the verified module.";
        case errSecInternalError:
            return @"An internal error has occurred.";
        case errSecMemoryError:
            return @"A memory error has occurred.";
        case errSecInvalidData:
            return @"Invalid data was encountered.";
        case errSecMDSError:
            return @"A Module Directory Service error has occurred.";
        case errSecInvalidPointer:
            return @"An invalid pointer was encountered.";
        case errSecSelfCheckFailed:
            return @"Self-check has failed.";
        case errSecFunctionFailed:
            return @"A function has failed.";
        case errSecModuleManifestVerifyFailed:
            return @"A module manifest verification failure has occurred.";
        case errSecInvalidGUID:
            return @"An invalid GUID was encountered.";
        case errSecInvalidHandle:
            return @"An invalid handle was encountered.";
        case errSecInvalidDBList:
            return @"An invalid DB list was encountered.";
        case errSecInvalidPassthroughID:
            return @"An invalid passthrough ID was encountered.";
        case errSecInvalidNetworkAddress:
            return @"An invalid network address was encountered.";
        case errSecCRLAlreadySigned:
            return @"The certificate revocation list is already signed.";
        case errSecInvalidNumberOfFields:
            return @"An invalid number of fields were encountered.";
        case errSecVerificationFailure:
            return @"A verification failure occurred.";
        case errSecUnknownTag:
            return @"An unknown tag was encountered.";
        case errSecInvalidSignature:
            return @"An invalid signature was encountered.";
        case errSecInvalidName:
            return @"An invalid name was encountered.";
        case errSecInvalidCertificateRef:
            return @"An invalid certificate reference was encountered.";
        case errSecInvalidCertificateGroup:
            return @"An invalid certificate group was encountered.";
        case errSecTagNotFound:
            return @"The specified tag was not found.";
        case errSecInvalidQuery:
            return @"The specified query was not valid.";
        case errSecInvalidValue:
            return @"An invalid value was detected.";
        case errSecCallbackFailed:
            return @"A callback has failed.";
        case errSecACLDeleteFailed:
            return @"An ACL delete operation has failed.";
        case errSecACLReplaceFailed:
            return @"An ACL replace operation has failed.";
        case errSecACLAddFailed:
            return @"An ACL add operation has failed.";
        case errSecACLChangeFailed:
            return @"An ACL change operation has failed.";
        case errSecInvalidAccessCredentials:
            return @"Invalid access credentials were encountered.";
        case errSecInvalidRecord:
            return @"An invalid record was encountered.";
        case errSecInvalidACL:
            return @"An invalid ACL was encountered.";
        case errSecInvalidSampleValue:
            return @"An invalid sample value was encountered.";
        case errSecIncompatibleVersion:
            return @"An incompatible version was encountered.";
        case errSecPrivilegeNotGranted:
            return @"The privilege was not granted.";
        case errSecInvalidScope:
            return @"An invalid scope was encountered.";
        case errSecPVCAlreadyConfigured:
            return @"The PVC is already configured.";
        case errSecInvalidPVC:
            return @"An invalid PVC was encountered.";
        case errSecEMMLoadFailed:
            return @"The EMM load has failed.";
        case errSecEMMUnloadFailed:
            return @"The EMM unload has failed.";
        case errSecAddinLoadFailed:
            return @"The add-in load operation has failed.";
        case errSecInvalidKeyRef:
            return @"An invalid key was encountered.";
        case errSecInvalidKeyHierarchy:
            return @"An invalid key hierarchy was encountered.";
        case errSecAddinUnloadFailed:
            return @"The add-in unload operation has failed.";
        case errSecLibraryReferenceNotFound:
            return @"A library reference was not found.";
        case errSecInvalidAddinFunctionTable:
            return @"An invalid add-in function table was encountered.";
        case errSecInvalidServiceMask:
            return @"An invalid service mask was encountered.";
        case errSecModuleNotLoaded:
            return @"A module was not loaded.";
        case errSecInvalidSubServiceID:
            return @"An invalid subservice ID was encountered.";
        case errSecAttributeNotInContext:
            return @"An attribute was not in the context.";
        case errSecModuleManagerInitializeFailed:
            return @"A module failed to initialize.";
        case errSecModuleManagerNotFound:
            return @"A module was not found.";
        case errSecEventNotificationCallbackNotFound:
            return @"An event notification callback was not found.";
        case errSecInputLengthError:
            return @"An input length error was encountered.";
        case errSecOutputLengthError:
            return @"An output length error was encountered.";
        case errSecPrivilegeNotSupported:
            return @"The privilege is not supported.";
        case errSecDeviceError:
            return @"A device error was encountered.";
        case errSecAttachHandleBusy:
            return @"The CSP handle was busy.";
        case errSecNotLoggedIn:
            return @"You are not logged in.";
        case errSecAlgorithmMismatch:
            return @"An algorithm mismatch was encountered.";
        case errSecKeyUsageIncorrect:
            return @"The key usage is incorrect.";
        case errSecKeyBlobTypeIncorrect:
            return @"The key blob type is incorrect.";
        case errSecKeyHeaderInconsistent:
            return @"The key header is inconsistent.";
        case errSecUnsupportedKeyFormat:
            return @"The key header format is not supported.";
        case errSecUnsupportedKeySize:
            return @"The key size is not supported.";
        case errSecInvalidKeyUsageMask:
            return @"The key usage mask is not valid.";
        case errSecUnsupportedKeyUsageMask:
            return @"The key usage mask is not supported.";
        case errSecInvalidKeyAttributeMask:
            return @"The key attribute mask is not valid.";
        case errSecUnsupportedKeyAttributeMask:
            return @"The key attribute mask is not supported.";
        case errSecInvalidKeyLabel:
            return @"The key label is not valid.";
        case errSecUnsupportedKeyLabel:
            return @"The key label is not supported.";
        case errSecInvalidKeyFormat:
            return @"The key format is not valid.";
        case errSecUnsupportedVectorOfBuffers:
            return @"The vector of buffers is not supported.";
        case errSecInvalidInputVector:
            return @"The input vector is not valid.";
        case errSecInvalidOutputVector:
            return @"The output vector is not valid.";
        case errSecInvalidContext:
            return @"An invalid context was encountered.";
        case errSecInvalidAlgorithm:
            return @"An invalid algorithm was encountered.";
        case errSecInvalidAttributeKey:
            return @"A key attribute was not valid.";
        case errSecMissingAttributeKey:
            return @"A key attribute was missing.";
        case errSecInvalidAttributeInitVector:
            return @"An init vector attribute was not valid.";
        case errSecMissingAttributeInitVector:
            return @"An init vector attribute was missing.";
        case errSecInvalidAttributeSalt:
            return @"A salt attribute was not valid.";
        case errSecMissingAttributeSalt:
            return @"A salt attribute was missing.";
        case errSecInvalidAttributePadding:
            return @"A padding attribute was not valid.";
        case errSecMissingAttributePadding:
            return @"A padding attribute was missing.";
        case errSecInvalidAttributeRandom:
            return @"A random number attribute was not valid.";
        case errSecMissingAttributeRandom:
            return @"A random number attribute was missing.";
        case errSecInvalidAttributeSeed:
            return @"A seed attribute was not valid.";
        case errSecMissingAttributeSeed:
            return @"A seed attribute was missing.";
        case errSecInvalidAttributePassphrase:
            return @"A passphrase attribute was not valid.";
        case errSecMissingAttributePassphrase:
            return @"A passphrase attribute was missing.";
        case errSecInvalidAttributeKeyLength:
            return @"A key length attribute was not valid.";
        case errSecMissingAttributeKeyLength:
            return @"A key length attribute was missing.";
        case errSecInvalidAttributeBlockSize:
            return @"A block size attribute was not valid.";
        case errSecMissingAttributeBlockSize:
            return @"A block size attribute was missing.";
        case errSecInvalidAttributeOutputSize:
            return @"An output size attribute was not valid.";
        case errSecMissingAttributeOutputSize:
            return @"An output size attribute was missing.";
        case errSecInvalidAttributeRounds:
            return @"The number of rounds attribute was not valid.";
        case errSecMissingAttributeRounds:
            return @"The number of rounds attribute was missing.";
        case errSecInvalidAlgorithmParms:
            return @"An algorithm parameters attribute was not valid.";
        case errSecMissingAlgorithmParms:
            return @"An algorithm parameters attribute was missing.";
        case errSecInvalidAttributeLabel:
            return @"A label attribute was not valid.";
        case errSecMissingAttributeLabel:
            return @"A label attribute was missing.";
        case errSecInvalidAttributeKeyType:
            return @"A key type attribute was not valid.";
        case errSecMissingAttributeKeyType:
            return @"A key type attribute was missing.";
        case errSecInvalidAttributeMode:
            return @"A mode attribute was not valid.";
        case errSecMissingAttributeMode:
            return @"A mode attribute was missing.";
        case errSecInvalidAttributeEffectiveBits:
            return @"An effective bits attribute was not valid.";
        case errSecMissingAttributeEffectiveBits:
            return @"An effective bits attribute was missing.";
        case errSecInvalidAttributeStartDate:
            return @"A start date attribute was not valid.";
        case errSecMissingAttributeStartDate:
            return @"A start date attribute was missing.";
        case errSecInvalidAttributeEndDate:
            return @"An end date attribute was not valid.";
        case errSecMissingAttributeEndDate:
            return @"An end date attribute was missing.";
        case errSecInvalidAttributeVersion:
            return @"A version attribute was not valid.";
        case errSecMissingAttributeVersion:
            return @"A version attribute was missing.";
        case errSecInvalidAttributePrime:
            return @"A prime attribute was not valid.";
        case errSecMissingAttributePrime:
            return @"A prime attribute was missing.";
        case errSecInvalidAttributeBase:
            return @"A base attribute was not valid.";
        case errSecMissingAttributeBase:
            return @"A base attribute was missing.";
        case errSecInvalidAttributeSubprime:
            return @"A subprime attribute was not valid.";
        case errSecMissingAttributeSubprime:
            return @"A subprime attribute was missing.";
        case errSecInvalidAttributeIterationCount:
            return @"An iteration count attribute was not valid.";
        case errSecMissingAttributeIterationCount:
            return @"An iteration count attribute was missing.";
        case errSecInvalidAttributeDLDBHandle:
            return @"A database handle attribute was not valid.";
        case errSecMissingAttributeDLDBHandle:
            return @"A database handle attribute was missing.";
        case errSecInvalidAttributeAccessCredentials:
            return @"An access credentials attribute was not valid.";
        case errSecMissingAttributeAccessCredentials:
            return @"An access credentials attribute was missing.";
        case errSecInvalidAttributePublicKeyFormat:
            return @"A public key format attribute was not valid.";
        case errSecMissingAttributePublicKeyFormat:
            return @"A public key format attribute was missing.";
        case errSecInvalidAttributePrivateKeyFormat:
            return @"A private key format attribute was not valid.";
        case errSecMissingAttributePrivateKeyFormat:
            return @"A private key format attribute was missing.";
        case errSecInvalidAttributeSymmetricKeyFormat:
            return @"A symmetric key format attribute was not valid.";
        case errSecMissingAttributeSymmetricKeyFormat:
            return @"A symmetric key format attribute was missing.";
        case errSecInvalidAttributeWrappedKeyFormat:
            return @"A wrapped key format attribute was not valid.";
        case errSecMissingAttributeWrappedKeyFormat:
            return @"A wrapped key format attribute was missing.";
        case errSecStagedOperationInProgress:
            return @"A staged operation is in progress.";
        case errSecStagedOperationNotStarted:
            return @"A staged operation was not started.";
        case errSecVerifyFailed:
            return @"A cryptographic verification failure has occurred.";
        case errSecQuerySizeUnknown:
            return @"The query size is unknown.";
        case errSecBlockSizeMismatch:
            return @"A block size mismatch occurred.";
        case errSecPublicKeyInconsistent:
            return @"The public key was inconsistent.";
        case errSecDeviceVerifyFailed:
            return @"A device verification failure has occurred.";
        case errSecInvalidLoginName:
            return @"An invalid login name was detected.";
        case errSecAlreadyLoggedIn:
            return @"The user is already logged in.";
        case errSecInvalidDigestAlgorithm:
            return @"An invalid digest algorithm was detected.";
        case errSecInvalidCRLGroup:
            return @"An invalid CRL group was detected.";
        case errSecCertificateCannotOperate:
            return @"The certificate cannot operate.";
        case errSecCertificateExpired:
            return @"An expired certificate was detected.";
        case errSecCertificateNotValidYet:
            return @"The certificate is not yet valid.";
        case errSecCertificateRevoked:
            return @"The certificate was revoked.";
        case errSecCertificateSuspended:
            return @"The certificate was suspended.";
        case errSecInsufficientCredentials:
            return @"Insufficient credentials were detected.";
        case errSecInvalidAction:
            return @"The action was not valid.";
        case errSecInvalidAuthority:
            return @"The authority was not valid.";
        case errSecVerifyActionFailed:
            return @"A verify action has failed.";
        case errSecInvalidCertAuthority:
            return @"The certificate authority was not valid.";
        case errSecInvaldCRLAuthority:
            return @"The CRL authority was not valid.";
        case errSecInvalidCRLEncoding:
            return @"The CRL encoding was not valid.";
        case errSecInvalidCRLType:
            return @"The CRL type was not valid.";
        case errSecInvalidCRL:
            return @"The CRL was not valid.";
        case errSecInvalidFormType:
            return @"The form type was not valid.";
        case errSecInvalidID:
            return @"The ID was not valid.";
        case errSecInvalidIdentifier:
            return @"The identifier was not valid.";
        case errSecInvalidIndex:
            return @"The index was not valid.";
        case errSecInvalidPolicyIdentifiers:
            return @"The policy identifiers are not valid.";
        case errSecInvalidTimeString:
            return @"The time specified was not valid.";
        case errSecInvalidReason:
            return @"The trust policy reason was not valid.";
        case errSecInvalidRequestInputs:
            return @"The request inputs are not valid.";
        case errSecInvalidResponseVector:
            return @"The response vector was not valid.";
        case errSecInvalidStopOnPolicy:
            return @"The stop-on policy was not valid.";
        case errSecInvalidTuple:
            return @"The tuple was not valid.";
        case errSecMultipleValuesUnsupported:
            return @"Multiple values are not supported.";
        case errSecNotTrusted:
            return @"The trust policy was not trusted.";
        case errSecNoDefaultAuthority:
            return @"No default authority was detected.";
        case errSecRejectedForm:
            return @"The trust policy had a rejected form.";
        case errSecRequestLost:
            return @"The request was lost.";
        case errSecRequestRejected:
            return @"The request was rejected.";
        case errSecUnsupportedAddressType:
            return @"The address type is not supported.";
        case errSecUnsupportedService:
            return @"The service is not supported.";
        case errSecInvalidTupleGroup:
            return @"The tuple group was not valid.";
        case errSecInvalidBaseACLs:
            return @"The base ACLs are not valid.";
        case errSecInvalidTupleCredendtials:
            return @"The tuple credentials are not valid.";
        case errSecInvalidEncoding:
            return @"The encoding was not valid.";
        case errSecInvalidValidityPeriod:
            return @"The validity period was not valid.";
        case errSecInvalidRequestor:
            return @"The requestor was not valid.";
        case errSecRequestDescriptor:
            return @"The request descriptor was not valid.";
        case errSecInvalidBundleInfo:
            return @"The bundle information was not valid.";
        case errSecInvalidCRLIndex:
            return @"The CRL index was not valid.";
        case errSecNoFieldValues:
            return @"No field values were detected.";
        case errSecUnsupportedFieldFormat:
            return @"The field format is not supported.";
        case errSecUnsupportedIndexInfo:
            return @"The index information is not supported.";
        case errSecUnsupportedLocality:
            return @"The locality is not supported.";
        case errSecUnsupportedNumAttributes:
            return @"The number of attributes is not supported.";
        case errSecUnsupportedNumIndexes:
            return @"The number of indexes is not supported.";
        case errSecUnsupportedNumRecordTypes:
            return @"The number of record types is not supported.";
        case errSecFieldSpecifiedMultiple:
            return @"Too many fields were specified.";
        case errSecIncompatibleFieldFormat:
            return @"The field format was incompatible.";
        case errSecInvalidParsingModule:
            return @"The parsing module was not valid.";
        case errSecDatabaseLocked:
            return @"The database is locked.";
        case errSecDatastoreIsOpen:
            return @"The data store is open.";
        case errSecMissingValue:
            return @"A missing value was detected.";
        case errSecUnsupportedQueryLimits:
            return @"The query limits are not supported.";
        case errSecUnsupportedNumSelectionPreds:
            return @"The number of selection predicates is not supported.";
        case errSecUnsupportedOperator:
            return @"The operator is not supported.";
        case errSecInvalidDBLocation:
            return @"The database location is not valid.";
        case errSecInvalidAccessRequest:
            return @"The access request is not valid.";
        case errSecInvalidIndexInfo:
            return @"The index information is not valid.";
        case errSecInvalidNewOwner:
            return @"The new owner is not valid.";
        case errSecInvalidModifyMode:
            return @"The modify mode is not valid.";
#ifdef __MAC_10_8
        case errSecMissingRequiredExtension:
            return @"A required certificate extension is missing.";
        case errSecExtendedKeyUsageNotCritical:
            return @"The extended key usage extension was not marked critical.";
        case errSecTimestampMissing:
            return @"A timestamp was expected but was not found.";
        case errSecTimestampInvalid:
            return @"The timestamp was not valid.";
        case errSecTimestampNotTrusted:
            return @"The timestamp was not trusted.";
        case errSecTimestampServiceNotAvailable:
            return @"The timestamp service is not available.";
        case errSecTimestampBadAlg:
            return @"An unrecognized or unsupported Algorithm Identifier in timestamp.";
        case errSecTimestampBadRequest:
            return @"The timestamp transaction is not permitted or supported.";
        case errSecTimestampBadDataFormat:
            return @"The timestamp data submitted has the wrong format.";
        case errSecTimestampTimeNotAvailable:
            return @"The time source for the Timestamp Authority is not available.";
        case errSecTimestampUnacceptedPolicy:
            return @"The requested policy is not supported by the Timestamp Authority.";
        case errSecTimestampUnacceptedExtension:
            return @"The requested extension is not supported by the Timestamp Authority.";
        case errSecTimestampAddInfoNotAvailable:
            return @"The additional information requested is not available.";
        case errSecTimestampSystemFailure:
            return @"The timestamp request cannot be handled due to system failure .";
        case errSecSigningTimeMissing:
            return @"A signing time was expected but was not found.";
        case errSecTimestampRejection:
            return @"A timestamp transaction was rejected.";
        case errSecTimestampWaiting:
            return @"A timestamp transaction is waiting.";
        case errSecTimestampRevocationWarning:
            return @"A timestamp authority revocation warning was issued.";
        case errSecTimestampRevocationNotification:
            return @"A timestamp authority revocation notification was issued.";
#endif
#endif
        default:
            return [NSString stringWithFormat:@"error %ld", (unsigned long)oss];
    }
}
@end
