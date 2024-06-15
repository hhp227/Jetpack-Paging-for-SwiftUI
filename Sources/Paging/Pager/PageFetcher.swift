//
//  PageFetcher.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/26.
//

import Combine

internal class PageFetcher<Key: Equatable, Value: Any> {
    private let pagingSourceFactory: () -> PagingSource<Key, Value>
    
    private let initialKey: Key?
    
    private let config: PagingConfig

    private let remoteMediator: RemoteMediator<Key, Value>?

    private let refreshEvents = ConflatedEventBus<Bool>()

    private let retryEvents = ConflatedEventBus<Void>()

    var publisher: AnyPublisher<PagingData<Value>, Never> {
        get {
            let remoteMediatorAccessor = remoteMediator != nil ? remoteMediatorAccessor(delegate: remoteMediator!) : nil
            let initialValue: GenerationInfo<Key, Value>? = nil
            return refreshEvents.publisher
                .prepend(remoteMediatorAccessor?.initialize() == .LAUNCH_INITIAL_REFRESH)
                .scan(initialValue) { previousGeneration, triggerRemoteRefresh in
                    let pagingSource = self.generateNewPagingSource(previousGeneration?.snapshot.pagingSource)
                    var previousPagingState = previousGeneration?.snapshot.currentPagingState()
                
                    if previousPagingState?.pages.isEmpty == true && !(previousGeneration?.state?.pages.isEmpty)! { // 애매함
                        previousPagingState = previousGeneration!.state
                    }
                    if previousPagingState?.anchorPosition == nil && previousGeneration?.state?.anchorPosition != nil {
                        previousPagingState = previousGeneration!.state
                    }
                    
                    let initialKey: Key? = previousPagingState == nil ? self.initialKey : pagingSource.getRefreshKey(state: previousPagingState!)
                    
                    previousGeneration?.snapshot.close()
                    return GenerationInfo(
                        snapshot: PageFetcherSnapshot(
                            initialKey: initialKey,
                            pagingSource: pagingSource,
                            config: self.config,
                            retryPublisher: self.retryEvents.publisher,
                            triggerRemoteRefresh: triggerRemoteRefresh,
                            remoteMediatorConnection: remoteMediatorAccessor,
                            previousPagingState: previousPagingState,
                            invalidate: self.refresh
                        ),
                        state: previousPagingState
                    )
                }
                .filter { $0 != nil }
                .map { generation in
                    PagingData<Value>(
                        generation!.snapshot.pageEventSubject.eraseToAnyPublisher(),
                        PagerUiReceiver<Key, Value>(generation!.snapshot, self.retryEvents)
                    )
                }
                .eraseToAnyPublisher()
        }
    }
    
    func refresh() {
        refreshEvents.send(data: true)
    }
    
    private func invalidate() {
        refreshEvents.send(data: false)
    }
    
    private func generateNewPagingSource(_ previousPagingSource: PagingSource<Key, Value>?) -> PagingSource<Key, Value> {
        let pagingSource = pagingSourceFactory()
        guard pagingSource !== previousPagingSource else {
            fatalError("An instance of PagingSource was re-used when Pager expected to create a new instance. Ensure that the pagingSourceFactory passed to Pager always returns a new instance of PagingSource")
        }
        
        pagingSource.registerInvalidatedCallback(invalidate)
        previousPagingSource?.unregisterInvalidatedCallback(invalidate)
        previousPagingSource?.invalidate()
        return pagingSource
    }
    
    init(
        _ pagingSourceFactory: @escaping () -> PagingSource<Key, Value>,
        _ initialKey: Key?,
        _ config: PagingConfig,
        _ remoteMediator: RemoteMediator<Key, Value>? = nil
    ) {
        self.pagingSourceFactory = pagingSourceFactory
        self.initialKey = initialKey
        self.config = config
        self.remoteMediator = remoteMediator
    }
    
    class PagerUiReceiver<Key: Equatable, Value: Any>: UiReceiver {
        private let pageFetcherSnapshot: PageFetcherSnapshot<Key, Value>

        private let retryEventBus: ConflatedEventBus<Void>

        func accessHint(viewportHint: ViewportHint) {
            pageFetcherSnapshot.accessHint(viewportHint)
        }

        func retry() {
            retryEventBus.send(data: ())
        }

        func refresh() {

        }

        init(_ pageFetcherSnapshot: PageFetcherSnapshot<Key, Value>, _ retryEventBus: ConflatedEventBus<Void>) {
            self.pageFetcherSnapshot = pageFetcherSnapshot
            self.retryEventBus = retryEventBus
        }
    }

    private struct GenerationInfo<Key: Equatable, Value: Any> {
        let snapshot: PageFetcherSnapshot<Key, Value>
        
        let state: PagingState<Key, Value>?
    }
}
