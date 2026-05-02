//
//  PageFetcherSnapshot.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/26.
//

import Foundation
import Combine
import SwiftUI

// TODO input값이 사용되지 않고 있음
internal class PageFetcherSnapshot<Key: Equatable, Value: Any> {
    internal let initialKey: Key?
    
    internal let pagingSource: PagingSource<Key, Value>
    
    private let config: PagingConfig

    private let retryPublisher: AnyPublisher<Void, Never>

    private let triggerRemoteRefresh: Bool

    let remoteMediatorConnection: (any RemoteMediatorConnection)?

    private let previousPagingState: PagingState<Key, Value>?

    private let invalidate: () -> Void
    
    private let hintHandler = HintHandler()
    
    private var pageEvent = CurrentValueSubject<PageEvent<Value>, Never>(PageEvent<Value>.StaticList(data: []))
    
    private let stateHolder: PageFetcherSnapshotState<Key, Value>.Holder<Key, Value>
    
    let pageEventSubject: CurrentValueSubject<PageEvent<Value>, Never>
    
    var subscriptions = Set<AnyCancellable>()
    
    func accessHint(_ viewportHint: ViewportHint) {
        hintHandler.processHint(viewportHint)
    }
    
    func close() {
        // TODO
    }
    
    func currentPagingState() -> PagingState<Key, Value> {
        return stateHolder.withLock { state in
            state.currentPagingState(viewportHint: hintHandler.lastAccessHint)
        }
    }
    
    private func startConsumingHints() {
        if config.jumpThreshold != Int.min {
            [.append, .prepend]
                .forEach { loadType in
                    self.hintHandler.hintFor(loadType)
                        .filter { hint in
                            hint.presentedItemsBefore * -1 > self.config.jumpThreshold || hint.presentedItemsAfter * -1 > self.config.jumpThreshold
                        }.sink { _ in
                            self.invalidate()
                        }.store(in: &self.subscriptions)
                }
        }
        self.collectAsGenerationalViewportHints(
            self.stateHolder.withLock { state in state.consumePrependGenerationIdAsPublisher() },
            .prepend
        )
        self.collectAsGenerationalViewportHints(
            self.stateHolder.withLock { state in state.consumeAppendGenerationIdAsPublisher() },
            .append
        )
    }
    
    private func collectAsGenerationalViewportHints(_ publisher: AnyPublisher<Int, Never>, _ loadType: LoadType) {
        return publisher.flatMapLatest { generstionId -> AnyPublisher<GenerationalViewportHint, Never> in
            self.stateHolder.withLock { state in
                //print("state: \(state)")
                if state.sourceLoadStates.get(loadType) === LoadState.NotLoading(true) {
                    
                } else if !(state.sourceLoadStates.get(loadType) is LoadState.Error) {
                    state.sourceLoadStates.set(loadType, LoadState.NotLoading(false))
                }
            }
            return self.hintHandler.hintFor(loadType)
                .dropFirst(generstionId == 0 ? 0 : 1)
                .map { hint in GenerationalViewportHint(generationId: generstionId, hint: hint) }
                .eraseToAnyPublisher()
        }.runningReduce { previous, next in
            next.shouldPrioritizeOver(previous, loadType) ? next : previous
        }.sink { generationalHint in
            // TODO collectLatest로 변경하고 Task 어떻게 할건지
            Task {
                await self.doLoad(loadType, generationalHint)
            }
        }.store(in: &subscriptions)
    }
    
    private func loadParams(_ loadType: LoadType, _ key: Key?) -> PagingSource<Key, Value>.LoadParams<Key> {
        return PagingSource<Key, Value>.LoadParams<Key>.create(
            loadType,
            key,
            loadType == .refresh ? config.initialLoadSize : config.pageSize,
            config.enablePlaceholders
        )
    }
    
    private func doInitialLoad() async {
        stateHolder.withLock { state in state.setLoading(.refresh, pageEvent) }
        
        let params = loadParams(.refresh, initialKey)
        
        switch await pagingSource.load(params: params) {
        case let result as PagingSource<Key, Value>.LoadResult<Key, Value>.Page<Key, Value>:
            let insertApplied = stateHolder.withLock { state -> Bool in
                state.sourceLoadStates.set(.refresh, .NotLoading(false))
                if result.prevKey == nil {
                    state.sourceLoadStates.set(.prepend, .NotLoading(true))
                }
                if result.nextKey == nil {
                    state.sourceLoadStates.set(.append, .NotLoading(true))
                }
                return state.insert(0, .refresh, page: result)
            }
            
            if insertApplied {
                stateHolder.withLock { state in
                    pageEvent.value = state.toPageEvent(.refresh, result)
                }
            }
        case let result as PagingSource<Key, Value>.LoadResult<Key, Value>.Error<Key, Value>:
            stateHolder.withLock { state in
                let loadState = LoadState.Error(result.error)
                
                state.setError(.refresh, loadState, pageEvent)
            }
        case _ as PagingSource<Key, Value>.LoadResult<Key, Value>.Invalid<Key, Value>:
            onInvalidLoad()
        default:
            fatalError()
        }
    }
    
    private func doLoad(_ loadType: LoadType, _ generationalHint: GenerationalViewportHint) async {
        guard loadType != .refresh else {
            fatalError("Use doInitalLoad for LoadType == REFRESH")
        }
        var itemsLoaded = 0
        
        stateHolder.withLock { state in
            switch loadType {
            case .prepend:
                var firstPageIndex = state.initialPageIndex + generationalHint.hint.originalPageOffsetFirst - 1
                
                if firstPageIndex > state.pages.endIndex - 1 {
                    itemsLoaded += config.pageSize * (firstPageIndex - state.pages.endIndex - 1)
                    firstPageIndex = state.pages.endIndex - 1
                }
                if firstPageIndex > 0 {
                    for pageIndex in 0...firstPageIndex {
                        itemsLoaded += state.pages[pageIndex].data.count
                    }
                }
            case .append:
                var lastPageIndex = state.initialPageIndex + generationalHint.hint.originalPageOffsetLast + 1
                
                if lastPageIndex < 0 {
                    itemsLoaded += config.pageSize * -lastPageIndex
                    lastPageIndex = 0
                }
                if state.pages.endIndex - 1 > lastPageIndex {
                    for pageIndex in lastPageIndex...state.pages.endIndex - 1 {
                        itemsLoaded += state.pages[pageIndex].data.count
                    }
                }
            case .refresh:
                fatalError("Use doInitialLoad for LoadType == REFRESH")
            }
        }
        
        var loadKey: Key? = stateHolder.withLock { state in
            if let key = state.nextLoadKeyOrNil(
                loadType,
                generationalHint.generationId,
                generationalHint.hint.presentedItemsBeyondAnchor(loadType) + itemsLoaded,
                config
            ) {
                state.setLoading(loadType, pageEvent)
                return key
            } else {
                return nil
            }
        }
        var endOfPaginationReached = false
        func loop() async {
            while loadKey != nil {
                let params = loadParams(loadType, loadKey)
                let result: PagingSource<Key, Value>.LoadResult<Key, Value> = await pagingSource.load(params: params)
                
                if currentPagingState().pages.flatMap({ $0.data }).count - params.loadSize != generationalHint.hint.presentedItemsBefore {
                    break
                }
                switch result {
                case let result as PagingSource<Key, Value>.LoadResult<Key, Value>.Page<Key, Value>:
                    let nextKey: Key?
                    
                    switch loadType {
                    case .refresh:
                        fatalError()
                    case .prepend:
                        nextKey = result.prevKey
                    case .append:
                        nextKey = result.nextKey
                    }
                    
                    guard pagingSource.keyReuseSupported || nextKey != loadKey else {
                        let keyFieldName = loadType == .prepend ? "prevKey" : "nextKey"
                        fatalError(
                            "The same value, \(String(describing: loadKey)), was passed as the \(keyFieldName) in two | sequential Pages loaded from a PagingSource. Re-using load keys in | PagingSource is often an error, and must be explicitly enabled by | overriding PagingSource.keyReuseSupported."
                        )
                    }
                    
                    let insertApplied = stateHolder.withLock { state in
                        state.insert(generationalHint.generationId, loadType, page: result)
                    }
                    
                    if !insertApplied {
                        return
                    }
                    
                    itemsLoaded += result.data.count
                    
                    if (loadType == .prepend && result.prevKey == nil) || (loadType == .append && result.nextKey == nil) {
                        endOfPaginationReached = true
                    }
                case let result as PagingSource<Key, Value>.LoadResult<Key, Value>.Error<Key, Value>:
                    stateHolder.withLock { state in
                        let loadState = LoadState.Error(result.error)
                        state.setError(loadType, loadState, pageEvent)
                        
                        state.failedHintsByLoadType[loadType] = generationalHint.hint
                    }
                    return
                case _ as PagingSource<Key, Value>.LoadResult<Key, Value>.Invalid<Key, Value>:
                    onInvalidLoad()
                    return
                default:
                    fatalError()
                }
                stateHolder.withLock { state in
                    loadKey = state.nextLoadKeyOrNil(
                        loadType,
                        generationalHint.generationId,
                        generationalHint.hint.presentedItemsBeyondAnchor(loadType) + itemsLoaded,
                        config
                    )
                    if loadKey == nil && !(state.sourceLoadStates.get(loadType) is LoadState.Error) {
                        state.sourceLoadStates.set(
                            loadType,
                            endOfPaginationReached ? .NotLoading(true) : .NotLoading(false)
                        )
                    }
                    let pageEvent = state.toPageEvent(loadType, result as! PagingSource<Key, Value>.LoadResult<Key, Value>.Page<Key, Value>)
                    
                    self.pageEvent.value = pageEvent
                }
            }
        }
        
        //print("doLoad, loadKey: \(loadKey), \(currentPagingState().pages.endIndex - 1)")
        await loop()
    }
    
    private func onInvalidLoad() {
        close()
        pagingSource.invalidate()
    }
    
    init(
        initialKey: Key?,
        pagingSource: PagingSource<Key, Value>,
        config: PagingConfig,
        retryPublisher: AnyPublisher<Void, Never>,
        triggerRemoteRefresh: Bool = false,
        remoteMediatorConnection: (some RemoteMediatorConnection)? = nil,
        previousPagingState: PagingState<Key, Value>? = nil,
        invalidate: @escaping () -> Void = {}
    ) {
        self.initialKey = initialKey
        self.pagingSource = pagingSource
        self.config = config
        self.retryPublisher = retryPublisher
        self.triggerRemoteRefresh = triggerRemoteRefresh
        self.remoteMediatorConnection = remoteMediatorConnection
        self.previousPagingState = previousPagingState
        self.invalidate = invalidate
        self.stateHolder = PageFetcherSnapshotState<Key, Value>.Holder<Key, Value>(config: self.config)
        self.pageEventSubject = CurrentValueSubject<PageEvent<Value>, Never>(pageEvent.value)
        
        self.pageEventSubject.send(PageEvent<Value>.LoadStateUpdate(source: self.stateHolder.withLock { $0.sourceLoadStates.snapshot() }))
        self.pageEvent.sink {
            if !($0 is PageEvent<Value>.StaticList<Value>) {
                self.pageEventSubject.send($0)
            }
        }.store(in: &self.subscriptions)
        Task {
            await self.doInitialLoad()
            if !(self.stateHolder.withLock(block: { state in state.sourceLoadStates.get(.refresh) }) is LoadState.Error) { // TODO 여기가 이상함
                self.startConsumingHints()
            }
        }
    }
}

private extension PageFetcherSnapshotState {
    func setLoading(_ loadType: LoadType, _ pageEvent: CurrentValueSubject<PageEvent<Value>, Never>) {
        if sourceLoadStates.get(loadType) !== LoadState.Loading.instance {
            sourceLoadStates.set(loadType, LoadState.Loading.instance)
            pageEvent.value = PageEvent<Value>.LoadStateUpdate(source: sourceLoadStates.snapshot(), mediator: nil)
        }
    }
    
    func setError(_ loadType: LoadType, _ error: LoadState, _ pageEvent: CurrentValueSubject<PageEvent<Value>, Never>) {
        if sourceLoadStates.get(loadType) !== error {
            sourceLoadStates.set(loadType, error)
            pageEvent.value = PageEvent<Value>.LoadStateUpdate(source: sourceLoadStates.snapshot(), mediator: nil)
        }
    }
    
    func nextLoadKeyOrNil(
        _ loadType: LoadType,
        _ generationId: Int,
        _ presentedItemsBeyondAnchor: Int,
        _ config: PagingConfig
    ) -> Key? {
        if generationId != self.generationId(loadType) {
            return nil
        }
        if sourceLoadStates.get(loadType) is LoadState.Error {
            return nil
        }
        if presentedItemsBeyondAnchor >= config.prefetchDistance {
            return nil
        }
        return loadType == .prepend ? pages.first?.prevKey : pages.last?.nextKey
    }
}

internal struct GenerationalViewportHint {
    let generationId: Int
    
    let hint: ViewportHint
}

internal extension GenerationalViewportHint {
    func shouldPrioritizeOver(
        _ previous: GenerationalViewportHint,
        _ loadType: LoadType
    ) -> Bool {
        if generationId > previous.generationId {
            return true
        } else if generationId < previous.generationId {
            return false
        } else {
            return hint.shouldPrioritizeOver(previous: previous.hint, loadType: loadType)
        }
    }
}


extension Publisher {
    func flatMapLatest<T: Publisher>(_ transform: @escaping (Self.Output) -> T) -> Publishers.SwitchToLatest<T, Publishers.Map<Self, T>> where T.Failure == Self.Failure {
        map(transform).switchToLatest()
    }
    
    public func runningReduce<T>(_ operation: @escaping (T, Self.Output) -> T) -> Publishers.Map<Self, T> {
        var acc: Any? = nil
        return map { value -> T in
            acc = acc == nil ? value : operation(acc as! T, value)
            return acc as! T
        }
    }
}
