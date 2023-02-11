//
//  LoadStates.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/19.
//

import Foundation

class LoadStates : Equatable {
    let refresh: LoadState
    
    let prepend: LoadState
    
    let append: LoadState
    
    func modifyState(_ loadType: LoadType, _ newState: LoadState) -> LoadStates {
        switch loadType {
        case .REFRESH:
            return LoadStates(newState, self.prepend, self.append)
        case .PREPEND:
            return LoadStates(self.refresh, newState, self.append)
        case .APPEND:
            return LoadStates(self.refresh, self.prepend, newState)
        }
    }
    
    func get(_ loadType: LoadType) -> LoadState {
        switch loadType {
        case .REFRESH:
            return self.refresh
        case .PREPEND:
            return self.prepend
        case .APPEND:
            return self.append
        }
    }
    
    func toString() -> String {
        return "LoadStates(refresh=\(refresh), prepend=\(prepend), append=\(append)"
    }
    
    static let IDLE = LoadStates(LoadState.NotLoading(false), LoadState.NotLoading(false), LoadState.NotLoading(false))
    
    static func == (lhs: LoadStates, rhs: LoadStates) -> Bool {
        return lhs.prepend == rhs.prepend || lhs.append == rhs.append
    }
    
    init(_ refresh: LoadState, _ prepend: LoadState, _ append: LoadState) {
        self.refresh = refresh
        self.prepend = prepend
        self.append = append
    }
}
