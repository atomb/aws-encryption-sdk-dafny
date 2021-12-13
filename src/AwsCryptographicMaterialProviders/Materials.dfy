// Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

include "../StandardLibrary/StandardLibrary.dfy"
include "../Generated/AwsCryptographicMaterialProviders.dfy" 
include "AlgorithmSuites.dfy"

module 
  {:extern "Dafny.Aws.Crypto.MaterialProviders.Materials"}
  MaterialProviders.Materials
{
import opened StandardLibrary
  import opened Wrappers
  import opened UInt = StandardLibrary.UInt
  import UTF8
  import Aws.Crypto
  import AlgorithmSuites

  // UTF-8 encoded "aws-crypto-public-key"
  const EC_PUBLIC_KEY_FIELD: UTF8.ValidUTF8Bytes :=
    var s :=
      [0x61, 0x77, 0x73, 0x2D, 0x63, 0x72, 0x79, 0x70, 0x74, 0x6F, 0x2D, 0x70,
      0x75, 0x62, 0x6C, 0x69, 0x63, 0x2D, 0x6B, 0x65, 0x79];
    assert UTF8.ValidUTF8Range(s, 0, 21);
    s
  const RESERVED_KEY_VALUES := { EC_PUBLIC_KEY_FIELD }


  // Encryption Materials

  /* The goal of EncryptionMaterialsTransitionIsValid is to aproxomate
   * _some_ mutability in an otherwise immutable structure.
   * Encryption Materials should allow for the addition
   * of the plaintext data key and encrypted data keys.
   * Once a plaintext data key is added,
   * it can never be removed or altered.
   * Simmilarly encrypted data keys can be added,
   * but none can be removed.
   * This lets keyrings/CMM handle immutalbe data,
   * and easily assert these invariants.
   */
  predicate method EncryptionMaterialsTransitionIsValid(
    oldMat: Crypto.EncryptionMaterials,
    newMat: Crypto.EncryptionMaterials
  ) {
    && newMat.algorithmSuiteId == oldMat.algorithmSuiteId
    && newMat.encryptionContext == oldMat.encryptionContext
    && newMat.signingKey == oldMat.signingKey
    && (
      || (oldMat.plaintextDataKey.None? && newMat.plaintextDataKey.Some?)
      || oldMat.plaintextDataKey == newMat.plaintextDataKey)
    && |newMat.encryptedDataKeys| >= |oldMat.encryptedDataKeys|
    && multiset(oldMat.encryptedDataKeys) <= multiset(newMat.encryptedDataKeys)
    && ValidEncryptionMaterials(oldMat)
    && ValidEncryptionMaterials(newMat)
  }

  // Chain of custody is important.
  // Being given valid materials
  // means that you MUST always have valid materials.
  lemma TransitionImplyValidEncryptionMaterials(
    oldMat: Crypto.EncryptionMaterials,
    newMat: Crypto.EncryptionMaterials
  )
    // You can not transition from invalid materials
    ensures !ValidEncryptionMaterials(oldMat)
    ==> !EncryptionMaterialsTransitionIsValid(oldMat, newMat)

    // You can not transition to invalid materials
    ensures !ValidEncryptionMaterials(newMat)
    ==> !EncryptionMaterialsTransitionIsValid(oldMat, newMat)
  {}

  predicate method ValidEncryptionMaterials(encryptionMaterials: Crypto.EncryptionMaterials) {
    && var suite := AlgorithmSuites.GetSuite(encryptionMaterials.algorithmSuiteId);
    && (suite.signature.None? <==> encryptionMaterials.signingKey.None?)
    && (encryptionMaterials.plaintextDataKey.Some? ==> suite.encrypt.keyLength as int == |encryptionMaterials.plaintextDataKey.value|)
    && (encryptionMaterials.plaintextDataKey.None? ==> |encryptionMaterials.encryptedDataKeys| == 0)
  }

  predicate method EncryptionMaterialsWithPlaintextDataKey(encryptionMaterials: Crypto.EncryptionMaterials) {
    && encryptionMaterials.plaintextDataKey.Some?
    && |encryptionMaterials.encryptedDataKeys| > 0
    && ValidEncryptionMaterials(encryptionMaterials)
  }

  function method EncryptionMaterialAddEncryptedDataKeys(
    encryptionMaterials: Crypto.EncryptionMaterials,
    encryptedDataKeysToAdd: Crypto.EncryptedDataKeyList
  )
    :(res: Result<Crypto.EncryptionMaterials, string>)
    requires |encryptedDataKeysToAdd| > 0
    ensures res.Success?
    ==>
      && EncryptionMaterialsWithPlaintextDataKey(res.value)
      && EncryptionMaterialsTransitionIsValid(encryptionMaterials, res.value)
  {
    :- Need(ValidEncryptionMaterials(encryptionMaterials), "Attempt to modify invalid encryption material.");
    :- Need(encryptionMaterials.plaintextDataKey.Some?, "Adding encrypted data keys without a plaintext data key is not allowed.");
    Success(Crypto.EncryptionMaterials(
      plaintextDataKey := encryptionMaterials.plaintextDataKey,
      encryptedDataKeys := encryptionMaterials.encryptedDataKeys + encryptedDataKeysToAdd,
      algorithmSuiteId := encryptionMaterials.algorithmSuiteId,
      encryptionContext := encryptionMaterials.encryptionContext,
      signingKey := encryptionMaterials.signingKey
    ))
  }

  function method EncryptionMaterialAddDataKey(
    encryptionMaterials: Crypto.EncryptionMaterials,
    plaintextDataKey: seq<uint8>,
    encryptedDataKeysToAdd: Crypto.EncryptedDataKeyList
  )
    :(res: Result<Crypto.EncryptionMaterials, string>)
    requires |encryptedDataKeysToAdd| > 0
    ensures res.Success?
    ==>
      && EncryptionMaterialsWithPlaintextDataKey(res.value)
      && EncryptionMaterialsTransitionIsValid(encryptionMaterials, res.value)
  {
    var suite := AlgorithmSuites.GetSuite(encryptionMaterials.algorithmSuiteId);
    :- Need(ValidEncryptionMaterials(encryptionMaterials), "Attempt to modify invalid encryption material.");
    :- Need(encryptionMaterials.plaintextDataKey.None?, "Attempt to modify plaintextDataKey.");
    :- Need(suite.encrypt.keyLength as int == |plaintextDataKey|, "plaintextDataKey does not match Algorithm Suite specification.");

    Success(Crypto.EncryptionMaterials(
      plaintextDataKey := Some(plaintextDataKey),
      encryptedDataKeys := encryptionMaterials.encryptedDataKeys + encryptedDataKeysToAdd,
      algorithmSuiteId := encryptionMaterials.algorithmSuiteId,
      encryptionContext := encryptionMaterials.encryptionContext,
      signingKey := encryptionMaterials.signingKey
    ))
  }

  // Decryption Materials
  /* The goal of DecryptionMaterialsTransitionIsValid is to approximate
   * _some_ mutability in an otherwise immutable structure.
   * Decryption Materials allow for the addition
   * of a plaintext data key.
   * Once a plaintext data key is added,
   * it can never be removed or altered.
   * This lets keyrings/CMM handle immutable data,
   * and easily assert these invariants.
   */
  predicate method DecryptionMaterialsTransitionIsValid(
    oldMat: Crypto.DecryptionMaterials,
    newMat: Crypto.DecryptionMaterials
  ) {
    && newMat.algorithmSuiteId == oldMat.algorithmSuiteId
    && newMat.encryptionContext == oldMat.encryptionContext
    && newMat.verificationKey == oldMat.verificationKey
    && oldMat.plaintextDataKey.None?
    && newMat.plaintextDataKey.Some?
    && ValidDecryptionMaterials(oldMat)
    && ValidDecryptionMaterials(newMat)
  }

  // Chain of custody is important.
  // Being given valid materials
  // means that you MUST always have valid materials.
  lemma TransitionImplyValidDecryptionMaterials(
    oldMat: Crypto.DecryptionMaterials,
    newMat: Crypto.DecryptionMaterials
  )
    // You can not transition from invalid materials
    ensures !ValidDecryptionMaterials(oldMat)
    ==> !DecryptionMaterialsTransitionIsValid(oldMat, newMat)

    // You can not transition to invalid materials
    ensures !ValidDecryptionMaterials(newMat)
    ==> !DecryptionMaterialsTransitionIsValid(oldMat, newMat)
  {}

  predicate method ValidDecryptionMaterials(decryptionMaterials: Crypto.DecryptionMaterials) {
    && var suite := AlgorithmSuites.GetSuite(decryptionMaterials.algorithmSuiteId);
    && (decryptionMaterials.plaintextDataKey.Some? ==> suite.encrypt.keyLength as int == |decryptionMaterials.plaintextDataKey.value|)
    && (suite.signature.ECDSA? <==> decryptionMaterials.verificationKey.Some?)
  }

  function method DecryptionMaterialsAddDataKey(
    decryptionMaterials: Crypto.DecryptionMaterials,
    plaintextDataKey: seq<uint8>
  )
    :(res: Result<Crypto.DecryptionMaterials, string>)
    ensures res.Success?
    ==>
      && DecryptionMaterialsWithPlaintextDataKey(res.value)
      && DecryptionMaterialsTransitionIsValid(decryptionMaterials, res.value)
  {
    var suite := AlgorithmSuites.GetSuite(decryptionMaterials.algorithmSuiteId);
    :- Need(ValidDecryptionMaterials(decryptionMaterials), "Attempt to modify invalid decryption material.");
    :- Need(decryptionMaterials.plaintextDataKey.None?, "Attempt to modify plaintextDataKey.");
    :- Need(suite.encrypt.keyLength as int == |plaintextDataKey|, "plaintextDataKey does not match Algorithm Suite specification.");

    Success(Crypto.DecryptionMaterials(
      plaintextDataKey := Some(plaintextDataKey),
      algorithmSuiteId := decryptionMaterials.algorithmSuiteId,
      encryptionContext := decryptionMaterials.encryptionContext,
      verificationKey := decryptionMaterials.verificationKey
    ))
  }

  predicate method DecryptionMaterialsWithoutPlaintextDataKey(decryptionMaterials: Crypto.DecryptionMaterials) {
    && decryptionMaterials.plaintextDataKey.None?
    && ValidDecryptionMaterials(decryptionMaterials)
  }

  predicate method DecryptionMaterialsWithPlaintextDataKey(decryptionMaterials: Crypto.DecryptionMaterials) {
    && decryptionMaterials.plaintextDataKey.Some?
    && ValidDecryptionMaterials(decryptionMaterials)
  }

  // The distinction between DecryptionMaterials with and without a PlaintextDataKey
  // is relevant to DecryptionMaterials in a way that it is not for EncryptionMaterials.
  // To avoid ambiguity a keyring that receives DecryptionMaterials with a PlaintextDataKey MUST fail.
  // Given the failure mode of the MultiKeyring,
  // or any other rational combinator.
  type DecryptionMaterialsPendingPlaintextDataKey = d: Crypto.DecryptionMaterials
    | DecryptionMaterialsWithoutPlaintextDataKey(d)
    witness *

  type SealedDecryptionMaterials = d: Crypto.DecryptionMaterials
    | DecryptionMaterialsWithPlaintextDataKey(d)
    witness *

}