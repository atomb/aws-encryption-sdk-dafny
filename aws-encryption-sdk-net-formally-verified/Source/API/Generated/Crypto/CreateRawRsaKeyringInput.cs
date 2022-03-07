// Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

using System;
using Aws.Crypto;
using
    Aws.Crypto
    ;

namespace Aws.Crypto
{
    public class CreateRawRsaKeyringInput
    {
        private string _keyNamespace;
        private string _keyName;
        private Aws.Crypto.PaddingScheme _paddingScheme;
        private System.IO.MemoryStream _publicKey;
        private System.IO.MemoryStream _privateKey;

        public string KeyNamespace
        {
            get { return this._keyNamespace; }
            set { this._keyNamespace = value; }
        }

        internal bool IsSetKeyNamespace()
        {
            return this._keyNamespace != null;
        }

        public string KeyName
        {
            get { return this._keyName; }
            set { this._keyName = value; }
        }

        internal bool IsSetKeyName()
        {
            return this._keyName != null;
        }

        public Aws.Crypto.PaddingScheme PaddingScheme
        {
            get { return this._paddingScheme; }
            set { this._paddingScheme = value; }
        }

        internal bool IsSetPaddingScheme()
        {
            return this._paddingScheme != null;
        }

        public System.IO.MemoryStream PublicKey
        {
            get { return this._publicKey; }
            set { this._publicKey = value; }
        }

        internal bool IsSetPublicKey()
        {
            return this._publicKey != null;
        }

        public System.IO.MemoryStream PrivateKey
        {
            get { return this._privateKey; }
            set { this._privateKey = value; }
        }

        internal bool IsSetPrivateKey()
        {
            return this._privateKey != null;
        }

        public void Validate()
        {
        }
    }
}
