//
//  InvalidateCallbackTracker.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/19.
//

import Foundation

typealias T = () -> Void

class InvalidateCallbackTracker {
    private let callbackInvoker: (T) -> Void
    
    private let invalidGetter: (() -> Bool)?
    
    private let lock = NSLock()
    
    private var callbacks = [T]()
    
    private(set) internal var invalid = false
    
    internal func callbackCount() -> Int { callbacks.count }
    
    internal func registerInvalidatedCallback(callback: @escaping T) {
        if invalidGetter?() == true {
            invalidate()
        }
        if invalid {
            callbackInvoker(callback)
            return
        }
        
        var callImmediately = false
        
        lock.withLock {
            if invalid {
                callImmediately = true
            } else {
                callbacks.append(callback)
            }
        }
        if callImmediately {
            callbackInvoker(callback)
        }
    }
    
    internal func unregisterInvalidatedCallback(callback: T) {
        lock.withLock {
            if let index = callbacks.firstIndex(where: { $0() == callback() }) {
                callbacks.remove(at: index)
            }
        }
    }
    
    internal func invalidate() {
        if invalid {
            return
        }
        
        var callbacksToInvoke: [T]?
        
        lock.withLock {
            if invalid {
                return
            }
            invalid = true
            callbacksToInvoke = callbacks
            
            callbacks.removeAll()
        }
        callbacksToInvoke?.forEach(callbackInvoker)
    }
    
    init(callbackInvoker: @escaping (T) -> Void, _ invalidGetter: (() -> Bool)? = nil) {
        self.callbackInvoker = callbackInvoker
        self.invalidGetter = invalidGetter
    }
}

extension NSLock {
    func withLock<T>(action: () -> T) -> T {
        lock()
        let action = action()
        defer {
            unlock()
        }
        return action
    }
}
