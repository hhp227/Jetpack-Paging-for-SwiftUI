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
        //return lhs.endOfPaginationReached == rhs.endOfPaginationReached
        switch (lhs, rhs) {
        case let (l as NotLoading, r as NotLoading):
            return l.endOfPaginationReached == r.endOfPaginationReached
        case (_ as Loading, _ as Loading):
            return true
        case let (l as Error, r as Error):
            let ln = l.error as NSError
            let rn = r.error as NSError
            return ln.domain == rn.domain && ln.code == rn.code && ln.localizedDescription == rn.localizedDescription
        default:
            return false
        }
    }
    
    public class NotLoading: LoadState {
        override init(_ endOfPaginationReached: Bool) {
            super.init(endOfPaginationReached)
        }
    }
    
    public class Loading: LoadState {
        static let instance = Loading()
        
        private init() {
            super.init(false)
        }
    }
    
    public class Error: LoadState {
        let error: Swift.Error
        
        init(_ error: Swift.Error) {
            self.error = error
            super.init(false)
        }
    }
    
    public init(_ endOfPaginationReached: Bool) {
        self.endOfPaginationReached = endOfPaginationReached
    }
}
