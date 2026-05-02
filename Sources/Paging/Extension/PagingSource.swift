//
//  PagingSource.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/26.
//

import Accessibility

open class PagingSource<Key: Any, Value: Any> {
    private let invalidateCallbackTracker = InvalidateCallbackTracker(
        callbackInvoker: { $0() }
    )
    
    internal var invalidateCallbackCount: Int {
        return invalidateCallbackTracker.callbackCount()
    }
    
    open class LoadParams<Key: Any> {
        let loadSize: Int
        
        let placeholdersEnabled: Bool
        
        class Refresh<Key: Any>: LoadParams<Key> {
            private var key: Key?
            
            override func getKey() -> Key? {
                return key
            }
            
            init(_ key: Key?, _ loadSize: Int, _ placeholdersEnabled: Bool) {
                super.init(loadSize, placeholdersEnabled)
                self.key = key
            }
        }
        
        class Append<Key: Any>: LoadParams<Key> {
            private var key: Key?
            
            override func getKey() -> Key? {
                return key
            }
            
            init(_ key: Key, _ loadSize: Int, _ placeholdersEnabled: Bool) {
                super.init(loadSize, placeholdersEnabled)
                self.key = key
            }
        }
        
        class Prepend<Key: Any>: LoadParams<Key> {
            private var key: Key?
            
            override func getKey() -> Key? {
                return key
            }
            
            init(_ key: Key, _ loadSize: Int, _ placeholdersEnabled: Bool) {
                super.init(loadSize, placeholdersEnabled)
                self.key = key
            }
        }
        
        public func getKey() -> Key? {
            abort()
        }
        
        static func create(_ loadType: LoadType, _ key: Key?, _ loadSize: Int, _ placeholdersEnabled: Bool) -> LoadParams<Key> {
            switch loadType {
            case .refresh:
                return Refresh(key, loadSize, placeholdersEnabled)
            case .prepend:
                return Prepend(key!, loadSize, placeholdersEnabled)
            case .append:
                return Append(key!, loadSize, placeholdersEnabled)
            }
        }
        
        init(_ loadSize: Int, _ placeholdersEnabled: Bool) {
            self.loadSize = loadSize
            self.placeholdersEnabled = placeholdersEnabled
        }
    }
    
    open class LoadResult<Key: Any, Value: Any> {
        public class Error<Key: Any, Value: Any>: LoadResult<Key, Value> {
            var error: Swift.Error
            
            public init(error: Swift.Error) {
                self.error = error
            }
        }
        
        class Invalid<Key: Any, Value: Any>: LoadResult<Key, Value> {}
        
        public class Page<Key: Any, Value: Any>: LoadResult<Key, Value> {
            let data: [Value]
            
            public let prevKey: Key?
            
            public let nextKey: Key?
            
            let itemsBefore: Int = Int.min
            
            let itemsAfter: Int = Int.min
            
            public init(data: [Value], prevKey: Key?, nextKey: Key?) {
                self.data = data
                self.prevKey = prevKey
                self.nextKey = nextKey
            }
        }
    }
    
    open var jumpingSupported: Bool {
        return false
    }
    
    open var keyReuseSupported: Bool {
        return false
    }
    
    var invalid: Bool {
        return invalidateCallbackTracker.invalid
    }
    
    func invalidate() {
        invalidateCallbackTracker.invalidate()
    }
    
    func registerInvalidatedCallback(_ onInvalidatedCallback: @escaping () -> Void) {
        invalidateCallbackTracker.registerInvalidatedCallback(callback: onInvalidatedCallback)
    }
    
    func unregisterInvalidatedCallback(_ onInvalidatedCallback: () -> Void) {
        invalidateCallbackTracker.unregisterInvalidatedCallback(callback: onInvalidatedCallback)
    }
    
    open func load(params: LoadParams<Key>) async -> LoadResult<Key, Value> {
        abort()
    }
    
    open func getRefreshKey(state: PagingState<Key, Value>) -> Key? {
        abort()
    }
    
    public init() {}
}
