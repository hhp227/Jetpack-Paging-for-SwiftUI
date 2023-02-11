//
//  MutableCombinedLoadStateCollection.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/19.
//

import Foundation
import Combine

class MutableCombinedLoadStateCollection {
    private var isInitialized: Bool = false
    
    private var listeners = [(CombinedLoadStates) -> Void]()
    
    private var refresh: LoadState = LoadState.NotLoading(false)
    
    private var prepend: LoadState = LoadState.NotLoading(false)
    
    private var append: LoadState = LoadState.NotLoading(false)
    
    private(set) var source: LoadStates = LoadStates.IDLE
    
    private(set) var mediator: LoadStates? = nil
    
    private var stateSubject: CurrentValueSubject<CombinedLoadStates?, Never> = CurrentValueSubject(nil)
    
    var publisher: AnyPublisher<CombinedLoadStates, Never> {
        get {
            stateSubject.compactMap { $0 }.eraseToAnyPublisher()
        }
    }
    
    func set(_ sourceLoadStates: LoadStates, _ remoteLoadStates: LoadStates?) {
        isInitialized = true
        source = sourceLoadStates
        mediator = remoteLoadStates
        
        updateHelperStatesAndDispatch()
    }
    
    func set(_ type: LoadType, _ remote: Bool, _ state: LoadState) -> Bool {
        isInitialized = true
        let didChange = remote ? { () -> Bool in
            let lastMediator = mediator
            mediator = (mediator ?? LoadStates.IDLE).modifyState(type, state)
            return mediator !== lastMediator
        }() : {
            let lastSource = source
            source = source.modifyState(type, state)
            return source !== lastSource
        }()
        
        updateHelperStatesAndDispatch()
        return didChange
    }
    
    func get(_ type: LoadType, _ remote: Bool) -> LoadState? {
        return (remote ? mediator : source)?.get(type)
    }
    
    func addListener(_ listener: @escaping (CombinedLoadStates) -> Void) {
        self.listeners.append(listener)
        if let combinedLoadStates = self.snapshot() {
            listener(combinedLoadStates)
        }
    }
    
    func removeListener(_ listener: @escaping (CombinedLoadStates) -> Void) {
        if let combinedLoadStates = self.snapshot() {
            self.listeners.remove(at: self.listeners.lastIndex(where: { $0(combinedLoadStates) == listener(combinedLoadStates) }) ?? 0)
        }
    }
    
    private func snapshot() -> CombinedLoadStates? {
        if !isInitialized {
            return nil
        } else {
            return CombinedLoadStates(
                refresh: refresh,
                prepend: prepend,
                append: append
            )
        }
    }
    
    private func updateHelperStatesAndDispatch() {
        refresh = computeHelperState(refresh, source.refresh, source.refresh, mediator?.refresh)
        prepend = computeHelperState(prepend, source.refresh, source.prepend, mediator?.prepend)
        append = computeHelperState(append, source.refresh, source.append, mediator?.append)
        
        if let snapshot = snapshot() {
            stateSubject.value = snapshot
            listeners.forEach { $0(snapshot) }
        }
    }

    private func computeHelperState(
        _ previousState: LoadState,
        _ sourceRefreshState: LoadState,
        _ sourceState: LoadState,
        _ remoteState: LoadState?
    ) -> LoadState {
        if remoteState == nil {
            return sourceState
        }
        switch previousState {
        case is LoadState.Loading:
            if sourceRefreshState is LoadState.NotLoading && remoteState is LoadState.NotLoading {
                return remoteState!
            } else if remoteState is LoadState.Error {
                return remoteState!
            } else {
                return previousState
            }
        default:
            return remoteState!
        }
    }
}
