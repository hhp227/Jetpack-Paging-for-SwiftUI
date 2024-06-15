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
    
    open func initialize() -> InitializeAction { .LAUNCH_INITIAL_REFRESH }
    
    public enum MediatorResult {
        case Error(Error)
        case Success(endOfPaginationReached: Bool)
    }
    
    public enum InitializeAction {
        case LAUNCH_INITIAL_REFRESH
        case SKIP_INITIAL_REFRESH
    }
}
