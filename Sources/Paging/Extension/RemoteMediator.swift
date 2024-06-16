//
//  RemoteMediator.swift
//  Paging
//
//  Created by hhp227 on 2023/01/26.
//

import Foundation

open class RemoteMediator<Key: Any, Value: Any> {
    open func load(loadType: LoadType, state: PagingState<Key, Value>) -> MediatorResult {
        abort()
    }
    
    open func initialize() -> InitializeAction { .launchInitialRefresh }
    
    public enum MediatorResult {
        case error(Error)
        case success(endOfPaginationReached: Bool)
    }
    
    public enum InitializeAction {
        case launchInitialRefresh
        case skipInitialRefresh
    }
}
