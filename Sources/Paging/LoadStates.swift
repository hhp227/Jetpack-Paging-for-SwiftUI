//
//  LoadStates.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/19.
//

import Foundation

struct LoadStates: Equatable {
    let refresh: LoadState
    
    let prepend: LoadState
    
    let append: LoadState

    func forEach(_ op: (LoadType, LoadState) -> Void) {
        op(.refresh, refresh)
        op(.prepend, prepend)
        op(.append, append)
    }

    func modifyState(_ loadType: LoadType, _ newState: LoadState) -> LoadStates {
        switch loadType {
        case .append:
            return LoadStates(
                refresh: self.refresh,
                prepend: self.prepend,
                append: newState
            )
        case .prepend:
            return LoadStates(
                refresh: self.refresh,
                prepend: newState,
                append: self.append
            )
        case .refresh:
            return LoadStates(
                refresh: newState,
                prepend: self.prepend,
                append: self.append
            )
        }
    }
    
    func get(_ loadType: LoadType) -> LoadState {
        switch loadType {
        case .refresh:
            return self.refresh
        case .append:
            return self.append
        case .prepend:
            return self.prepend
        }
    }
    
    func toString() -> String {
        return "LoadStates(refresh=\(refresh), prepend=\(prepend), append=\(append)"
    }
    
    static let IDLE = LoadStates(
        refresh: LoadState.NotLoading(false),
        prepend: LoadState.NotLoading(false),
        append: LoadState.NotLoading(false)
    )
}
