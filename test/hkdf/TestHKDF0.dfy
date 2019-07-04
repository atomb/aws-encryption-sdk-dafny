// RUN: %dafny /out:./Output/TestHKDF0.exe "./TestHKDF0.dfy" "../../src/Crypto/HKDF/HKDF-extern.cs" "../../src/Util/Arrays-extern.cs" "../../lib/BouncyCastle.1.8.5/lib/BouncyCastle.Crypto.dll" /noVerify /compile:2
// RUN: cp "../../lib/BouncyCastle.1.8.5/lib/BouncyCastle.Crypto.dll" "./Output/"
// RUN: %mono ./Output/TestHKDF0.exe > "%t" && rm ./Output/TestHKDF0.exe
// RUN: %diff "%s.expect" "%t"

include "../../src/Util/StandardLibrary.dfy"
include "../../src/Crypto/HKDF/HKDF.dfy"
include "../../src/Crypto/HKDF/HKDFSpec.dfy"

module TestHKDF0 {
  
  import opened StandardLibrary
  import opened HKDF
  import opened Digests

  method Main() {
    // Test vector 0: Basic test case with SHA-256
    var tv_ikm  := new [][ 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b,
                             0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b ];

    var tv_salt := new [][ 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c ];

    var tv_info := new [][ 0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9 ];

    var tv_okm_desired  := new [][ 0x3c, 0xb2, 0x5f, 0x25, 0xfa, 0xac, 0xd5, 0x7a, 0x90, 0x43, 0x4f,
                                   0x64, 0xd0, 0x36, 0x2f, 0x2a, 0x2d, 0x2d, 0x0a, 0x90, 0xcf, 0x1a,
                                   0x5a, 0x4c, 0x5d, 0xb0, 0x2d, 0x56, 0xec, 0xc4, 0xc5, 0xbf, 0x34,
                                   0x00, 0x72, 0x08, 0xd5, 0xb8, 0x87, 0x18, 0x58, 0x65 ];

    var okm := hkdf(HmacSHA256, tv_salt, tv_ikm, tv_info, 42);
    if okm[..] == tv_okm_desired[..] {
      print "EQUAL\n";
    } else {
      print "NOT EQUAL\n";
    }
  }
}