//
//  CombinedLoadStates.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/19.
//

struct CombinedLoadStates: Equatable {
    public let refresh: LoadState
    
    public let prepend: LoadState
    
    public let append: LoadState

    public let source: LoadStates

    public var mediator: LoadStates? = nil

    static func == (lhs: CombinedLoadStates, rhs: CombinedLoadStates) -> Bool {
        return lhs.refresh == rhs.refresh &&
        lhs.prepend == rhs.prepend &&
        lhs.append == rhs.append &&
        lhs.source == rhs.source &&
        lhs.mediator == rhs.mediator
    }

    func forEach(op: (LoadType, Bool, LoadState) -> Void) {
        source.forEach { type, state in
            op(type, false, state)
        }
        mediator?.forEach { type, state in
            op(type, true, state)
        }
    }
}
