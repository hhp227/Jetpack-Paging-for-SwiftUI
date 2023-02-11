//
//  MutableLoadStateCollection.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/28.
//

internal class MutableLoadStateCollection {
    var refresh: LoadState = .NotLoading(false)
    var prepend: LoadState = .NotLoading(false)
    var append: LoadState = .NotLoading(false)
    
    func snapshot() -> LoadStates { LoadStates(refresh, prepend, append) }
    
    func get(_ loadType: LoadType) -> LoadState {
        switch loadType {
        case .REFRESH:
            return refresh
        case .APPEND:
            return append
        case .PREPEND:
            return prepend
        }
    }
    
    func set(_ type: LoadType, _ state: LoadState) {
        switch type {
        case .REFRESH:
            refresh = state
        case .APPEND:
            append = state
        case .PREPEND:
            prepend = state
        }
    }
    
    func set(_ states: LoadStates) {
        refresh = states.refresh
        append = states.append
        prepend = states.prepend
    }
}
