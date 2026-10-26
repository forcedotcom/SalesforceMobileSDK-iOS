//
//  SFSDKDPoPURL.swift
//  SalesforceSDKCore
//
//  Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.
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

enum DPoPURL {
    /// Produces the `htu` value per RFC 9449 §4.2: the request URL with no
    /// query and no fragment. Used both in the DPoP proof JWT payload
    /// (`SFSDKDPoPProofBuilder`) and as part of the nonce cache key
    /// (`SFSDKDPoPNonceCache`); both sites must agree on the canonical form.
    ///
    /// WORKAROUND (W-24564590): server-side DPoP `htu` validation bug.
    /// Experience Cloud sites with a URL path prefix (e.g. "/site") return an internal
    /// community URL ("/sitevforcesite"). The server validates `htu` against the public
    /// path and rejects the internal one with `invalid_dpop_proof` (token, refresh) or
    /// `INVALID_AUTH_HEADER` (REST), so the internal suffix is dropped from the first path segment.
    /// TODO: Remove the `vforcesite` rewrite below once W-24564590 is fixed.
    static func htu(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        // WORKAROUND (W-24564590): map the internal "/<site>vforcesite" path to the public "/<site>" path.
        if let path = components?.percentEncodedPath,
           let range = path.range(of: "^/[^/]+vforcesite(?=/|$)", options: [.regularExpression, .caseInsensitive]) {
            let segment = path[range]
            components?.percentEncodedPath = path.replacingCharacters(in: range, with: segment.dropLast("vforcesite".count))
        }
        return components?.url?.absoluteString ?? url.absoluteString
    }
}
