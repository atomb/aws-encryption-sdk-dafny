include "../StandardLibrary/StandardLibrary.dfy"
include "../StandardLibrary/UInt.dfy"
include "MessageHeader.dfy"
include "AlgorithmSuite.dfy"
include "../Crypto/AESEncryption.dfy"

module MessageBody {
  export
    provides EncryptMessageBody, Encrypt
    provides StandardLibrary, UInt, Msg, AlgorithmSuite

  import opened StandardLibrary
  import opened UInt = StandardLibrary.UInt
  import AlgorithmSuite
  import Msg = MessageHeader
  import AESEncryption

  method EncryptMessageBody(plaintext: seq<uint8>, frameLength: int, messageID: Msg.MessageID, key: seq<uint8>, algorithmSuiteID: AlgorithmSuite.ID) returns (res: Result<seq<uint8>>)
    requires |key| == algorithmSuiteID.KeyLength()
    requires 0 < frameLength < UINT32_LIMIT
  {
    var body := [];
    var n, sequenceNumber := 0, 1;
    while n + frameLength <= |plaintext|
      invariant 0 <= n <= |plaintext|
      invariant sequenceNumber <= ENDFRAME_SEQUENCE_NUMBER
    {
      if sequenceNumber == ENDFRAME_SEQUENCE_NUMBER {
        return Failure("too many frames");
      }
      var plaintextFrame := plaintext[n..n + frameLength];
      var regularFrame :- EncryptFrame(algorithmSuiteID, key, frameLength, messageID, plaintextFrame, sequenceNumber, false);
      body := body + regularFrame;
      n, sequenceNumber := n + frameLength, sequenceNumber + 1;
    }
    var finalFrame :- EncryptFrame(algorithmSuiteID, key, frameLength, messageID, plaintext[n..], sequenceNumber, true);
    body := body + finalFrame;
    return Success(body);
  }

  method EncryptFrame(algorithmSuiteID: AlgorithmSuite.ID, key: seq<uint8>, frameLength: int, messageID: Msg.MessageID,
                      plaintext: seq<uint8>, sequenceNumber: uint32, final: bool)
      returns (res: Result<seq<uint8>>)
    requires |key| == algorithmSuiteID.KeyLength()
    requires 0 < frameLength && 0 < sequenceNumber <= ENDFRAME_SEQUENCE_NUMBER
    requires |plaintext| < UINT32_LIMIT
    requires !final ==> |plaintext| == frameLength && sequenceNumber != ENDFRAME_SEQUENCE_NUMBER
    requires final ==> |plaintext| < frameLength
    requires 4 <= algorithmSuiteID.IVLength()
  {
    var unauthenticatedFrame := if final then UInt32ToSeq(ENDFRAME_SEQUENCE_NUMBER) else [];
    var seqNumSeq := UInt32ToSeq(sequenceNumber as uint32);
    unauthenticatedFrame := unauthenticatedFrame + seqNumSeq;

    var iv: seq<uint8> := seq(algorithmSuiteID.IVLength() - 4, _ => 0) + UInt32ToSeq(sequenceNumber as uint32);
    assert |iv| == algorithmSuiteID.IVLength();
    unauthenticatedFrame := unauthenticatedFrame + iv;

    if final {
      unauthenticatedFrame := unauthenticatedFrame + UInt32ToSeq(|plaintext| as uint32);
    }

    var contentAAD := if final then BODY_AAD_CONTENT_FINAL_FRAME else BODY_AAD_CONTENT_REGULAR_FRAME;
    var aad := messageID + contentAAD + seqNumSeq + UInt64ToSeq(|plaintext| as uint64);

    var pair :- Encrypt(algorithmSuiteID, iv, key, plaintext, aad);
    var (encryptedContents, authTag) := pair;
    unauthenticatedFrame := unauthenticatedFrame + encryptedContents + authTag;

    return Success(unauthenticatedFrame);
  }

  const BODY_AAD_CONTENT_REGULAR_FRAME := StringToByteSeq("AWSKMSEncryptionClient Frame");
  const BODY_AAD_CONTENT_FINAL_FRAME := StringToByteSeq("AWSKMSEncryptionClient Final Frame");

  const ENDFRAME_SEQUENCE_NUMBER: uint32 := 0xFFFF_FFFF

  method Encrypt(algorithmSuiteID: AlgorithmSuite.ID, iv: seq<uint8>, key: seq<uint8>, plaintext: seq<uint8>, aad: seq<uint8>) returns (res: Result<(seq<uint8>,seq<uint8>)>)
    requires |iv| == algorithmSuiteID.IVLength()
    requires |key| == algorithmSuiteID.KeyLength()
    ensures match res
      case Success((ciphertext, authTag)) =>
        |ciphertext| == |plaintext| &&
        |authTag| == algorithmSuiteID.TagLength()
      case Failure(_) => true
  {
    var cipher := AlgorithmSuite.Suite[algorithmSuiteID].params;
    var bytes :- AESEncryption.AES.aes_encrypt(cipher, iv, key, plaintext, aad);
    var n := |plaintext|;
    if |bytes| != n + algorithmSuiteID.TagLength() {
      return Failure("unexpected AES encryption result");
    }
    return Success((bytes[..n], bytes[n..]));
  }
}
