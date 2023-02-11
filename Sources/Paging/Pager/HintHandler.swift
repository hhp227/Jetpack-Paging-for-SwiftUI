//
//  HintHandler.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/26.
//

import Foundation
import Combine

// 애매하지만 완료
internal class HintHandler {
    private let state = State()
    
    var lastAccessHint: ViewportHint.Access? {
        return state.lastAccessHint
    }

    func hintFor(_ loadType: LoadType) -> AnyPublisher<ViewportHint, Never> {
        switch loadType {
        case .PREPEND:
            return state.prependPublisher
        case .APPEND:
            return state.appendPublisher
        default:
            fatalError("invalid load type for hints")
        }
    }
    
    func forceSetHint(_ loadType: LoadType, _ viewPortHint: ViewportHint) {
        guard loadType == .PREPEND || loadType == .APPEND else {
            fatalError("invalid load type for reset: \(loadType)")
        }
        state.modify(nil) { prependHint, appendHint in
            if loadType == .PREPEND {
                prependHint.value = viewPortHint
            } else {
                appendHint.value = viewPortHint
            }
        }
    }
    
    func processHint(_ viewportHint: ViewportHint) {
        state.modify(viewportHint as? ViewportHint.Access) { prependHint, appendHint in
            if viewportHint.shouldPrioritizeOver(
                previous: prependHint.value,
                loadType: .PREPEND
            ) {
                prependHint.value = viewportHint
            }
            if viewportHint.shouldPrioritizeOver(
                previous: appendHint.value,
                loadType: .APPEND
            ) {
                appendHint.value = viewportHint
            }
        }
    }
    
    private class State {
        private let prepend = CurrentValueSubject<ViewportHint, Never>(
            ViewportHint.Initial(
                presentedItemsBefore: 0,
                presentedItemsAfter: 0,
                originalPageOffsetFirst: 0,
                originalPageOffsetLast: 0
            )
        )
        
        private let append = CurrentValueSubject<ViewportHint, Never>(
            ViewportHint.Initial(
                presentedItemsBefore: 0,
                presentedItemsAfter: 0,
                originalPageOffsetFirst: 0,
                originalPageOffsetLast: 0
            )
        )
        
        private(set) var lastAccessHint: ViewportHint.Access? = nil
        
        var prependPublisher: AnyPublisher<ViewportHint, Never> {
            return prepend.eraseToAnyPublisher()
        }
        
        var appendPublisher: AnyPublisher<ViewportHint, Never> {
            return append.eraseToAnyPublisher()
        }
        
        private let lock: NSLock = NSLock()
        
        func modify(
            _ accessHint: ViewportHint.Access?,
            _ block: (_ prepend: CurrentValueSubject<ViewportHint, Never>, _ append: CurrentValueSubject<ViewportHint, Never>) -> Void
        ) {
            lock.withLock {
                if accessHint != nil {
                    lastAccessHint = accessHint
                }
                block(prepend, append)
            }
        }
    }
}

extension ViewportHint {
    internal func shouldPrioritizeOver(previous: ViewportHint?, loadType: LoadType) -> Bool {
        if previous == nil {
            return true
        } else if previous is ViewportHint.Initial && self is ViewportHint.Access {
            return true
        } else if self is ViewportHint.Initial && previous is ViewportHint.Access {
            return false
        } else if self.originalPageOffsetFirst != previous!.originalPageOffsetFirst {
            return true
        } else if self.originalPageOffsetLast != previous!.originalPageOffsetLast {
            return true
        } else if previous!.presentedItemsBeyondAnchor(loadType) <= presentedItemsBeyondAnchor(loadType) {
            return false
        } else {
            return true
        }
    }
}
