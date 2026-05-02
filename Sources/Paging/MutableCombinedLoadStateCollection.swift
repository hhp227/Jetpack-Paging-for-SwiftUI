//
//  MutableCombinedLoadStateCollection.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/19.
//

import Foundation
import Combine

class MutableCombinedLoadStateCollection {
    private var listeners = [(CombinedLoadStates) -> Void]()
    
    private var stateSubject: CurrentValueSubject<CombinedLoadStates?, Never> = CurrentValueSubject(nil)
    
    var publisher: CurrentValueSubject<CombinedLoadStates?, Never> {
        get {
            stateSubject
        }
    }
    
    func set(_ sourceLoadStates: LoadStates, _ remoteLoadStates: LoadStates?) {
        return dispatchNewState { currState in
            self.computeNewState(
                previousState: currState,
                newSource: sourceLoadStates,
                newRemote: remoteLoadStates
            )
        }
    }
    
    func set(_ type: LoadType, _ remote: Bool, _ state: LoadState) {
        return dispatchNewState { currState in
            var source = currState?.source ?? LoadStates.IDLE
            var mediator = currState?.mediator ?? LoadStates.IDLE
            
            if remote {
                mediator = mediator.modifyState(type, state)
            } else {
                source = source.modifyState(type, state)
            }
            return self.computeNewState(
                previousState: currState,
                newSource: source,
                newRemote: mediator
            )
        }
    }
    
    func get(_ type: LoadType, _ remote: Bool) -> LoadState? {
        let state = stateSubject.value
        return (remote ? state?.mediator : state?.source)?.get(type)
    }
    
    func addListener(_ listener: @escaping (CombinedLoadStates) -> Void) {
        self.listeners.append(listener)
        if let state = stateSubject.value {
            listener(state)
        }
    }
    
    func removeListener(_ listener: @escaping (CombinedLoadStates) -> Void) {
        if let index = listeners.firstIndex(where: { $0 as AnyObject === listener as AnyObject }) {
            listeners.remove(at: index)
        }
    }
    
    private func dispatchNewState(
        computeNewState: @escaping (_ currState: CombinedLoadStates?) -> CombinedLoadStates
    ) {
        var newState: CombinedLoadStates? = nil
        let currState = stateSubject.value
        let computed = computeNewState(currState)
        if currState != computed {
            newState = computed
            DispatchQueue.main.async {
                self.stateSubject.send(computed)
            }
        } else {
            return
        }
        if let newState = newState {
            listeners.forEach { $0(newState) }
        }
    }
    
    private func computeNewState(
        previousState: CombinedLoadStates?,
        newSource: LoadStates,
        newRemote: LoadStates?
    ) -> CombinedLoadStates {
        let refresh = computeHelperState(
            previousState?.refresh ?? .NotLoading(false),
            newSource.refresh,
            newSource.refresh,
            newRemote?.refresh
        )
        let prepend = computeHelperState(
            previousState?.prepend ?? .NotLoading(false),
            newSource.refresh,
            newSource.prepend,
            newRemote?.prepend
        )
        let append = computeHelperState(
            previousState?.append ?? .NotLoading(false),
            newSource.refresh,
            newSource.append,
            newRemote?.append
        )
        return CombinedLoadStates(
            refresh: refresh,
            prepend: prepend,
            append: append,
            source: newSource,
            mediator: newRemote
        )
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

/*class MutableCombinedLoadStateCollection {
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
            return mediator != lastMediator
        }() : {
            let lastSource = source
            source = source.modifyState(type, state)
            return source != lastSource
        }()
        
        updateHelperStatesAndDispatch()
        return didChange
    }
    
    func get(_ type: LoadType, _ remote: Bool) -> LoadState? {
        return (remote ? mediator : source)?.get(type)
    }
    
    // MODIFIED
    func addListener(_ listener: @escaping (CombinedLoadStates) -> Void) {
        self.listeners.append(listener)
        if let snapshot = snapshot() {
            listener(snapshot)
        }
    }
    
    // MODIFIED
    func removeListener(_ listener: @escaping (CombinedLoadStates) -> Void) {
        if let index = listeners.firstIndex(where: { $0 as AnyObject === listener as AnyObject }) {
            listeners.remove(at: index)
        }
    }
    
    private func snapshot() -> CombinedLoadStates? {
        if !isInitialized {
            return nil
        } else {
            return CombinedLoadStates(
                refresh: refresh,
                prepend: prepend,
                append: append,
                source: source,
                mediator: mediator
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
*/
