/**
 * Module      : SHA256.mo
 * Description : Cryptographic hash function.
 * Copyright   : 2020 DFINITY Stiftung
 * License     : Apache 2.0 with LLVM Exception
 * Maintainer  : Enzo Haussecker <enzo@dfinity.org>
 * Stability   : Stable
 */

import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Prim "mo:prim";

module {

  private let K : [Word32] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  private let S : [Word32] = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ];

  // Calculate a SHA256 hash.
  public func sha256(data : [Word8]) : [Word8] {
    let digest = Digest();
    digest.write(data);
    return digest.sum();
  };

  public class Digest() {

    private let s = Array.thaw<Word32>(S);

    private let x = Array.init<Word8>(64, 0);

    private var nx = 0;

    private var len : Word64 = 0;

    public func reset() {
      for (i in Iter.range(0, 7)) {
        s[i] := S[i];
      };
      nx := 0;
      len := 0;
    };

    public func write(data : [Word8]) {
      var p = data;
      len +%= Prim.natToWord64(p.size());
      if (nx > 0) {
        let n = min(p.size(), 64 - nx);
        for (i in Iter.range(0, n - 1)) {
          x[nx + i] := p[i];
        };
        nx += n;
        if (nx == 64) {
          let buf = Array.freeze<Word8>(x);
          block(buf);
          nx := 0;
        };
        p := Array.tabulate<Word8>(p.size() - n, func (i) {
          return p[n + i];
        });
      };
      if (p.size() >= 64) {
        let n = Prim.word64ToNat(Prim.natToWord64(p.size()) & (^ 63));
        let buf = Array.tabulate<Word8>(n, func (i) {
          return p[i];
        });
        block(buf);
        p := Array.tabulate<Word8>(p.size() - n, func (i) {
          return p[n + i];
        });
      };
      if (p.size() > 0) {
        for (i in Iter.range(0, p.size() - 1)) {
          x[i] := p[i];
        };
        nx := p.size();
      };
    };

    public func sum() : [Word8] {
      var m = 0;
      var n = len;
      var t = Prim.word64ToNat(n) % 64;
      var buf : [var Word8] = [var];
      if (56 > t) {
        m := 56 - t;
      } else {
        m := 120 - t;
      };
      n := n << 3;
      buf := Array.init<Word8>(m, 0);
      if (m > 0) {
        buf[0] := 0x80;
      };
      write(Array.freeze<Word8>(buf));
      buf := Array.init<Word8>(8, 0);
      for (i in Iter.range(0, 7)) {
        let j : Word64 = 56 -% 8 *% Prim.natToWord64(i);
        buf[i] := Prim.natToWord8(Prim.word64ToNat(n >> j));
      };
      write(Array.freeze<Word8>(buf));
      let hash = Array.init<Word8>(32, 0);
      for (i in Iter.range(0, 7)) {
        for (j in Iter.range(0, 3)) {
          let k : Word32 = 24 -% 8 *% Prim.natToWord32(j);
          hash[4 * i + j] := Prim.natToWord8(Prim.word32ToNat(s[i] >> k));
        };
      };
      return Array.freeze<Word8>(hash);
    };

    private func block(data : [Word8]) {
      var p = data;
      var w = Array.init<Word32>(64, 0);
      while (p.size() >= 64) {
        var j = 0;
        for (i in Iter.range(0, 15)) {
          j := i * 4;
          w[i] :=
            Prim.natToWord32(Prim.word8ToNat(p[j + 0])) << 24 |
            Prim.natToWord32(Prim.word8ToNat(p[j + 1])) << 16 |
            Prim.natToWord32(Prim.word8ToNat(p[j + 2])) << 08 |
            Prim.natToWord32(Prim.word8ToNat(p[j + 3])) << 00;
        };
        var v1 : Word32 = 0;
        var v2 : Word32 = 0;
        var t1 : Word32 = 0;
        var t2 : Word32 = 0;
        for (i in Iter.range(16, 63)) {
          v1 := w[i - 02];
          v2 := w[i - 15];
          t1 := rot(v1, 17) ^ rot(v1, 19) ^ (v1 >> 10);
          t2 := rot(v2, 07) ^ rot(v2, 18) ^ (v2 >> 03);
          w[i] :=
              t1 +% w[i - 07] +%
              t2 +% w[i - 16];
        };
        var a = s[0];
        var b = s[1];
        var c = s[2];
        var d = s[3];
        var e = s[4];
        var f = s[5];
        var g = s[6];
        var h = s[7];
        for (i in Iter.range(0, 63)) {
          t1 := rot(e, 06) ^ rot(e, 11) ^ rot(e, 25);
          t1 +%= (e & f) ^ (^ e & g) +% h +% K[i] +% w[i];
          t2 := rot(a, 02) ^ rot(a, 13) ^ rot(a, 22);
          t2 +%= (a & b) ^ (a & c) ^ (b & c);
          h := g;
          g := f;
          f := e;
          e := d +% t1;
          d := c;
          c := b;
          b := a;
          a := t1 +% t2;
        };
        s[0] +%= a;
        s[1] +%= b;
        s[2] +%= c;
        s[3] +%= d;
        s[4] +%= e;
        s[5] +%= f;
        s[6] +%= g;
        s[7] +%= h;
        p := Array.tabulate<Word8>(p.size() - 64, func (i) {
          return p[i + 64];
        });
      };
    };
  };

  private func min(a : Nat, b : Nat) : Nat {
    if (a < b) {
      return a;
    } else {
      return b;
    };
  };

  private func rot(n : Word32, i : Word32) : Word32 {
    let j : Word32 = i % 32;
    let k : Word32 = 32 -% j;
    return n >> j | n << k;
  };
};
