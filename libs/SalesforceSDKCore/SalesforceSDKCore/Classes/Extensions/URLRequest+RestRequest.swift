//
//  URLRequest+RestRequest.swift
//  SalesforceSDKCore
//
//  Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
// 
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
// 
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation

extension URLRequest {
    
    /// Converts a URLRequest to an SFRestRequest
    /// - Returns: A new SFRestRequest instance populated with the URLRequest's properties
    public func toRestRequest(_ networkServiceType: RestRequest.NetWorkServiceType = RestRequest.NetWorkServiceType.SFNetworkServiceTypeDefault,
                              _ requiresAuthentication: Bool = true) -> RestRequest? {
        guard let url = self.url else { return nil }
        
        let path = url.path
        var queryParams: [String: Any] = [:]
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                queryParams[item.name] = item.value
            }
        }
        
        let method = RestRequest.sfRestMethod(fromHTTPMethod: httpMethod ?? "GET")
        
        let baseURL = "\(url.scheme ?? "https")://\(url.host ?? "")"
        let request = RestRequest(method: method, baseURL: baseURL, path: path, queryParams: queryParams)
        
        if let headers = allHTTPHeaderFields {
            for (key, value) in headers {
                request.setHeaderValue(value, forHeaderName: key)
            }
        }
        
        request.timeoutInterval = timeoutInterval
        
        if let body = httpBody {
            let contentType = allHTTPHeaderFields?["Content-Type"] ?? "application/octet-stream"
            request.setCustomRequestBodyData(body, contentType: contentType)
        }
        
        request.endpoint = url.path
        request.networkServiceType = networkServiceType
        request.requiresAuthentication = requiresAuthentication
        return request
    }
}
