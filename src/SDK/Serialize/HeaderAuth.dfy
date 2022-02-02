// Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

include "../../../libraries/src/Collections/Sequences/Seq.dfy"
include "../../Generated/AwsCryptographicMaterialProviders.dfy"
include "../../AwsCryptographicMaterialProviders/Client.dfy"
include "../../StandardLibrary/StandardLibrary.dfy"
include "../../Util/UTF8.dfy"
include "./SerializableTypes.dfy"
include "SerializeFunctions.dfy"
include "HeaderTypes.dfy"
include "EncryptionContext.dfy"
include "EncryptedDataKeys.dfy"

module HeaderAuth {
  import Aws.Crypto
  import Seq
  import HeaderTypes
  import MaterialProviders.Client
  import opened EncryptedDataKeys
  import opened EncryptionContext
  import opened SerializableTypes
  import opened StandardLibrary.UInt
  import opened Wrappers
  import opened UTF8
  import opened SerializeFunctions

  type AESMac = a: HeaderTypes.HeaderAuth
  | a.AESMac?
  witness *

  function method WriteAESMac(
    headerAuth: AESMac
  )
    :(ret: seq<uint8>)
  {
    Write(headerAuth.headerIv) + Write(headerAuth.headerAuthTag)
  }

  function method ReadAESMac(
    buffer: ReadableBuffer,
    suite: Client.AlgorithmSuites.AlgorithmSuite
  )
    :(res: ReadCorrect<AESMac>)
    ensures CorrectlyRead(buffer, res, WriteAESMac)
    ensures res.Success?
    ==>
      && |res.value.data.headerIv| == suite.encrypt.ivLength as nat
      && |res.value.data.headerAuthTag| == suite.encrypt.tagLength as nat
  {
    var headerIv :- Read(buffer, suite.encrypt.ivLength as nat);
    var headerAuthTag :- Read(headerIv.tail, suite.encrypt.tagLength as nat);

    var auth: AESMac := HeaderTypes.HeaderAuth.AESMac(
      headerIv := headerIv.data,
      headerAuthTag := headerAuthTag.data
    );

    Success(SuccessfulRead(auth, headerAuthTag.tail))
  }

}