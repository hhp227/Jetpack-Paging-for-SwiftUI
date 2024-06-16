//
//  RemoteMediatorAccessor.swift
//  Paging
//
//  Created by hhp227 on 2023/01/26.
//

import Combine
import Foundation

internal protocol RemoteMediatorConnection {
    associatedtype Key
    associatedtype Value
    
    func requestLoad(_ loadType: LoadType, _ pagingState: PagingState<Key, Value>)
    
    func retryFailed(_ pagingState: PagingState<Key, Value>)
}

internal protocol RemoteMediatorAccessor: RemoteMediatorConnection {
    var state: AnyPublisher<LoadStates, Never> { get }

    func initialize() -> RemoteMediator<Key, Value>.InitializeAction
}

func remoteMediatorAccessor<Key: Any, Value: Any>(
    delegate: RemoteMediator<Key, Value>
) -> some RemoteMediatorAccessor {
    return RemoteMediatorAccessImpl(delegate: delegate)
}

private class AccessorStateHolder<Key, Value> {
    private let lock = NSLock()
    private var _loadStates = CurrentValueSubject<LoadStates, Never>(.IDLE)
    var loadStates: AnyPublisher<LoadStates, Never> {
        return _loadStates.eraseToAnyPublisher()
    }
    private var internalState = AccessorState<Key, Value>()

    func use<R>(_ block: (AccessorState<Key, Value>) -> R) -> R {
        return lock.withLock {
            let result = block(internalState)
            _loadStates.send(internalState.computeLoadStates())
            return result
        }
    }
}

private class AccessorState<Key, Value> {
    private var blockStates = Array(repeating: BlockState.unblocked, count: LoadType.allCases.count)
    private var errors = Array<LoadState.Error?>(repeating: nil, count: LoadType.allCases.count)
    private var pendingRequests = [PendingRequest<Key, Value>]()

    func computeLoadStates() -> LoadStates {
        return LoadStates(
            computeLoadTypeState(loadType: .refresh),
            computeLoadTypeState(loadType: .append),
            computeLoadTypeState(loadType: .prepend)
        )
    }

    private func computeLoadTypeState(loadType: LoadType) -> LoadState {
        let blockState = blockStates[loadType.ordinal]
        let hasPending = pendingRequests.contains { $0.loadType == loadType }
        
        if hasPending && blockState != .requiresRefresh {
            return .Loading.instance
        }
        if let error = errors[loadType.ordinal] {
            return error
        }
        switch blockState {
        case .completed:
            return loadType == .refresh ? .NotLoading(false) : .NotLoading(true)
        case .requiresRefresh, .unblocked:
            return .NotLoading(false)
        }
    }

    func append(loadType: LoadType, pagingState: PagingState<Key, Value>) -> Bool {
        if let existing = pendingRequests.first(where: { $0.loadType == loadType }) {
            existing.pagingState = pagingState
            return false
        }

        let blockState = blockStates[loadType.ordinal]
        if blockState == .requiresRefresh && loadType != .refresh {
            pendingRequests.append(PendingRequest(loadType: loadType, pagingState: pagingState))
            return false
        }
        if blockState != .unblocked && loadType != .refresh {
            return false
        }
        if loadType == .refresh {
            setError(loadType: .refresh, errorState: nil)
        }
        return errors[loadType.ordinal] == nil && pendingRequests.append(PendingRequest(loadType: loadType, pagingState: pagingState)) != nil
    }

    func setBlockState(loadType: LoadType, state: BlockState) {
        blockStates[loadType.ordinal] = state
    }

    func getPendingRefresh() -> PagingState<Key, Value>? {
        return pendingRequests.first { $0.loadType == .refresh }?.pagingState
    }

    func getPendingBoundary() -> (LoadType, PagingState<Key, Value>)? {
        guard let request = pendingRequests.first(where: { $0.loadType != .refresh && blockStates[$0.loadType.ordinal] == .unblocked }) else {
            return nil
        }
        return (request.loadType, request.pagingState)
    }

    func clearPendingRequests() {
        pendingRequests.removeAll()
    }

    func clearPendingRequest(loadType: LoadType) {
        pendingRequests.removeAll { $0.loadType == loadType }
    }

    func clearErrors() {
        for i in errors.indices {
            errors[i] = nil
        }
    }

    func setError(loadType: LoadType, errorState: LoadState.Error?) {
        errors[loadType.ordinal] = errorState
    }

    class PendingRequest<Key: Any, Value: Any> {
        let loadType: LoadType
        var pagingState: PagingState<Key, Value>

        init(loadType: LoadType, pagingState: PagingState<Key, Value>) {
            self.loadType = loadType
            self.pagingState = pagingState
        }
    }

    enum BlockState {
        case unblocked
        case completed
        case requiresRefresh
    }
}

private class RemoteMediatorAccessImpl<Key: Any, Value: Any>: RemoteMediatorAccessor {
    private let remoteMediator: RemoteMediator<Key, Value>

    var state: AnyPublisher<LoadStates, Never> {
        return accessorState.loadStates
    }

    private let accessorState = AccessorStateHolder<Key, Value>()

    func requestLoad(_ loadType: LoadType, _ pagingState: PagingState<Key, Value>) {
        let newRequest = accessorState.use { $0.append(loadType: loadType, pagingState: pagingState) }
        if newRequest {
            if loadType == .refresh {
                launchRefresh()
            } else {
                launchBoundary()
            }
        }
    }

    private func launchRefresh() {
        var launchAppendPrepend = false

        let pendingPagingState = accessorState.use {
            $0.getPendingRefresh()
        }
        if let pendingPagingState = pendingPagingState {
            let loadResult = remoteMediator.load(loadType: .refresh, state: pendingPagingState)

            switch (loadResult) {
            case .success(let endOfPaginationReached):
                accessorState.use {
                    $0.clearPendingRequest(loadType: .refresh)
                    if endOfPaginationReached {
                        $0.setBlockState(loadType: .refresh, state: .completed)
                        $0.setBlockState(loadType: .prepend, state: .completed)
                        $0.setBlockState(loadType: .append, state: .completed)
                        $0.clearPendingRequests()
                    } else {
                        $0.setBlockState(loadType: .prepend, state: .unblocked)
                        $0.setBlockState(loadType: .append, state: .unblocked)
                    }
                    $0.setError(loadType: .prepend, errorState: nil)
                    $0.setError(loadType: .append, errorState: nil)
                    return $0.getPendingBoundary() != nil
                }
                break
            case .error(let e):
                accessorState.use {
                    $0.clearPendingRequest(loadType: .refresh)
                    $0.setError(loadType: .refresh, errorState: LoadState.Error(e))
                    return $0.getPendingBoundary() != nil
                }
                break
            }
        }
        if launchAppendPrepend {
            launchBoundary()
        }
    }

    private func launchBoundary() {
        while true {
            guard let (loadType, pendingPagingState) = accessorState.use ({
                $0.getPendingBoundary()
            }) else {
                break
            }
            switch remoteMediator.load(loadType: loadType, state: pendingPagingState) {
            case .success(endOfPaginationReached: let endOfPaginationReached):
                accessorState.use {
                    $0.clearPendingRequest(loadType: loadType)
                    if endOfPaginationReached {
                        $0.setBlockState(loadType: loadType, state: .completed)
                    }
                }
                break
            case .error(let e):
                accessorState.use {
                    $0.clearPendingRequest(loadType: loadType)
                    $0.setError(loadType: loadType, errorState: LoadState.Error(e))
                }
                break
            }
        }
    }

    func retryFailed(_ pagingState: PagingState<Key, Value>) {
        var toBeStarted = [LoadType]()

        accessorState.use {
            let loadStates = $0.computeLoadStates()
            let willTriggerRefresh = loadStates.refresh is LoadState.Error

            $0.clearErrors()
            if willTriggerRefresh {
                toBeStarted.append(.refresh)
                $0.setBlockState(loadType: .refresh, state: .unblocked)
            }
            if loadStates.append is LoadState.Error {
                if !willTriggerRefresh {
                    toBeStarted.append(.append)
                }
                $0.clearPendingRequest(loadType: .append)
            }
            if loadStates.prepend is LoadState.Error {
                if !willTriggerRefresh {
                    toBeStarted.append(.prepend)
                }
                $0.clearPendingRequest(loadType: .prepend)
            }
        }
        toBeStarted.forEach {
            requestLoad($0, pagingState)
        }
    }

    func initialize() -> RemoteMediator<Key, Value>.InitializeAction {
        let action = remoteMediator.initialize()

        if action == RemoteMediator.InitializeAction.launchInitialRefresh {
            accessorState.use {
                $0.setBlockState(loadType: .append, state: .requiresRefresh)
                $0.setBlockState(loadType: .prepend, state: .requiresRefresh)
            }
        }
        return action
    }

    init(delegate: RemoteMediator<Key, Value>) {
        self.remoteMediator = delegate
    }
}
