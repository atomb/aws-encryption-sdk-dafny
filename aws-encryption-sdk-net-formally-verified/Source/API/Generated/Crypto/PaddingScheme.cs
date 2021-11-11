// Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
//
// Generated at 2021-11-03T00:21:59.652135

using System;
using Aws.Crypto;
using
    Aws.Crypto
    ;

namespace Aws.Crypto
{
    using Amazon.Runtime;

    public class PaddingScheme : ConstantClass
    {
        public static readonly PaddingScheme PKCS1 = new PaddingScheme("PKCS1");

        public static readonly PaddingScheme OAEP_SHA1_MGF1 = new PaddingScheme("OAEP_SHA1_MGF1");

        public static readonly PaddingScheme OAEP_SHA256_MGF1 = new PaddingScheme("OAEP_SHA256_MGF1");

        public static readonly PaddingScheme OAEP_SHA384_MGF1 = new PaddingScheme("OAEP_SHA384_MGF1");

        public static readonly PaddingScheme OAEP_SHA512_MGF1 = new PaddingScheme("OAEP_SHA512_MGF1");

        public static readonly PaddingScheme[] Values =
        {
            OAEP_SHA1_MGF1, OAEP_SHA256_MGF1, OAEP_SHA384_MGF1, OAEP_SHA512_MGF1, PKCS1
        };

        public PaddingScheme(string value) : base(value)
        {
        }
    }
}