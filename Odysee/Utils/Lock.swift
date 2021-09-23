//
//  Lock.swift
//  Odysee
//
//  Created by Adlai Holler on 6/6/21.
//

import Foundation

final class Lock {
    private var lock = os_unfair_lock()

    @inline(__always) func withLock<T>(_ f: () throws -> T) rethrows -> T {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return try f()
    }

    @inline(__always) func withLockIfAvailable<T>(_ f: () throws -> T) rethrows -> T? {
        guard os_unfair_lock_trylock(&lock) else {
            return nil
        }

        defer { os_unfair_lock_unlock(&lock) }
        return try f()
    }

    @inline(__always) func assertOwner() { os_unfair_lock_assert_owner(&lock) }
    @inline(__always) func assertNotOwner() { os_unfair_lock_assert_not_owner(&lock) }
}
