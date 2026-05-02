//
//  LoadState.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/19.
//

import Foundation

/*public enum LoadState: Equatable {
    case NotLoading(Bool)
    case Loading
    case Error(Error?)
    
    public static func == (lhs: LoadState, rhs: LoadState) -> Bool {
        return lhs.endOfPaginationReached == rhs.endOfPaginationReached
    }
    
    var endOfPaginationReached: Bool {
        set {}
        get { false }
    }
}*/
open class LoadState: Equatable {
    let endOfPaginationReached: Bool
    
    public static func == (lhs: LoadState, rhs: LoadState) -> Bool {
        return lhs.endOfPaginationReached == rhs.endOfPaginationReached
    }
    
    class NotLoading: LoadState {
        override init(_ endOfPaginationReached: Bool) {
            super.init(endOfPaginationReached)
        }
    }
    
    final class Loading: LoadState {
        static let instance = Loading()
        
        private init() {
            super.init(false)
        }
    }
    
    class Error: LoadState {
        let error: Swift.Error
        
        init(_ error: Swift.Error) {
            self.error = error
            super.init(false)
        }
    }
    
    init(_ endOfPaginationReached: Bool) {
        self.endOfPaginationReached = endOfPaginationReached
    }
}
