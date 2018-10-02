//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Actors open source project
//
// Copyright (c) 2018-2019 Apple Inc. and the Swift Distributed Actors project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.md for the list of Swift Distributed Actors project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Atomics


// Implementation note:
// Note that we are not strictly following Base64; we start with lower case letters and replace the `/` with `~`
// TODO: To be honest it might be nicer to avoid the + and ~ as well; we'd differ from Akka but that does not matter really.
//
// Rationale:
// This is consistent with Akka, where the choice was made such as it is "natural" for small numbers of actors
// when learning the toolkit, and predictable for high numbers of them (where how it looks like stops to matter).
fileprivate let charsTable: [UnicodeScalar] = [
  "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
  "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
  "u", "v", "w", "x", "y", "z",
  "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
  "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
  "U", "V", "W", "X", "Y", "Z",
  // TODO contemplate skipping those 0...~ completely for nicer names
  "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" , "+", "~"
]
fileprivate let charsTableMaxIndex = charsTable.indices.last!

// TODO is this proper style?
// TODO is such inheritance expensive?
class AnonymousNamesGenerator {
  private let prefix: String

  init(prefix: String) {
    self.prefix = prefix
  }

  /// Implement by providing appropriate next actor number generation
  /// to seed the name generation. Atomic and non-atomic implementations
  /// exist, for use for top-level or protected within an actor execution/reduction naming.
  ///
  /// Note that no guarantees about names of anonymous actors are made;
  /// and developers should not expect those names never to change.
  fileprivate func nextId() -> Int {
    return undefined()
  }

  func nextName() -> String {
    let n = nextId()
    return mkName(prefix: prefix, n: n)
  }

  /// Based on Base64, though simplified
  func mkName(prefix: String, n: Int) -> String { // TODO work on Int64?
    var outputString: String = prefix

    var next = n
    repeat {
      let c = charsTable[Int(next & charsTableMaxIndex)]
      outputString.unicodeScalars.append(c)
      next &>>= 6
    } while next > 0

    return outputString
  }

}

/// Generate sequential names for actors
// TODO can be abstracted ofc, not doing so for now; keeping internal
class AtomicAnonymousNamesGenerator: AnonymousNamesGenerator {
  private var ids = AtomicUInt() // FIXME should be UInt64, since there's no reason to limit child actors only since the name won't fit them ;-)

  override init(prefix: String) {
    self.ids.initialize(0)
    super.init(prefix: prefix)
  }

  override func nextId() -> Int {
    return Int(ids.increment())
  }
}

// TODO pick better name for non sychronized ones
class NonSynchronizedAnonymousNamesGenerator: AnonymousNamesGenerator {
  private var ids: Int // FIXME should be UInt64, since there's no reason to limit child actors only since the name won't fit them ;-)

  override init(prefix: String) {
    self.ids = 0
    super.init(prefix: prefix)
  }

  override func nextId() -> Int {
    defer { ids += 1 }
    return ids
  }
}