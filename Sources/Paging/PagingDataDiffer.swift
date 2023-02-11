//
//  PagingDataDiffer.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/19.
//

import Foundation
import Combine

// TODO
class PagingDataDiffer<T: Any>: ProcessPageEventCallback {
    private let differCallback: DifferCallback
    
    private let updateItemSnapshotList: () -> Void
    
    private var presenter: PagePresenter<T> = PagePresenter<T>.initial()
    
    private var receiver: UiReceiver? = nil
    
    private let combinedLoadStatesCollection = MutableCombinedLoadStateCollection()
    
    private var onPagesUpdatedListeners = [() -> Void]()
    
    private var lastAccessedIndexUnfulfilled: Bool = false
    
    private var lastAccessedIndex: Int = 0
    
    private var subscriptions = Set<AnyCancellable>()
    
    private func dispatchLoadStates(_ source: LoadStates, mediator: LoadStates?) {
        if combinedLoadStatesCollection.source === source && combinedLoadStatesCollection.mediator === mediator {
            return
        }
        combinedLoadStatesCollection.set(source, mediator)
    }
    
    private func presentNewList(
        previousList: any NullPaddedList,
        newList: any NullPaddedList,
        lastAccessedIndex: Int,
        onListPresentable: () -> Void
    ) -> Int? {
        onListPresentable()
        updateItemSnapshotList()
        return nil
    }
    
    func collectFrom(_ pagingData: PagingData<T>) {
        receiver = pagingData.receiver
        
        pagingData.currentValueSubject.sink { event in
            DispatchQueue.main.async {
                print("event: \(event)")
                if let event = event as? PageEvent<T>.Insert<T>, event.loadType == LoadType.REFRESH {
                    self.presentNewList(
                        pages: event.pages,
                        placeholdersBefore: event.placeholdersBefore,
                        placeholdersAfter: event.placeholdersAfter,
                        dispatchLoadStates: true,
                        sourceLoadStates: event.sourceLoadStates,
                        mediatorLoadStates: event.mediatorLoadStates
                    )
                } else if let event = event as? PageEvent<T>.StaticList<T> {
                    self.presentNewList(
                        pages: [TransformablePage(originalPageOffset: 0, data: event.data)],
                        placeholdersBefore: 0,
                        placeholdersAfter: 0,
                        dispatchLoadStates: event.sourceLoadStates != nil || event.mediatorLoadStates != nil,
                        sourceLoadStates: event.sourceLoadStates,
                        mediatorLoadStates: event.mediatorLoadStates
                    )
                } else {
                    self.presenter.processEvent(event, self)
                    if event is PageEvent<T>.Drop<T> {
                        self.lastAccessedIndexUnfulfilled = false
                    }
                    if let event = event as? PageEvent<T>.Insert<T> {
                        let prependDone = self.combinedLoadStatesCollection.source.prepend.endOfPaginationReached
                        let appendDone = self.combinedLoadStatesCollection.source.append.endOfPaginationReached
                        let canContinueLoading = !(event.loadType == .PREPEND && prependDone) && !(event.loadType == .APPEND && appendDone)
                        let emptyInsert = event.pages.all(predicate: { $0.data.isEmpty })
                        
                        if !canContinueLoading {
                            self.lastAccessedIndexUnfulfilled = false
                        } else if self.lastAccessedIndexUnfulfilled || emptyInsert {
                            let shouldResendHint = emptyInsert || self.lastAccessedIndex < self.presenter.placeholdersBefore || self.lastAccessedIndex > self.presenter.placeholdersBefore + self.presenter.storageCount
                            
                            if shouldResendHint {
                                self.receiver?.accessHint(
                                    viewportHint: self.presenter.accessHintForPresenterIndex(self.lastAccessedIndex)
                                )
                            } else {
                                self.lastAccessedIndexUnfulfilled = false
                            }
                        }
                    }
                }
                if event is PageEvent<T>.Insert<T> || event is PageEvent<T>.StaticList<T> {
                    self.onPagesUpdatedListeners.forEach { $0() }
                }
            }
        }.store(in: &subscriptions)
    }
    
    func get(index: Int) -> T? {
        self.lastAccessedIndexUnfulfilled = true
        self.lastAccessedIndex = index
        
        self.receiver?.accessHint(
            viewportHint: presenter.accessHintForPresenterIndex(index)
        )
        return presenter.get(index)
    }
    
    func peek(index: Int) -> T? {
        return presenter.get(index)
    }
    
    func snapshot() -> ItemSnapshotList<T> {
        return presenter.snapshot()
    }
    
    func retry() {
        receiver?.retry()
    }
    
    func refresh() {
        receiver?.refresh()
    }
    
    var size: Int {
        get { presenter.size }
    }
    
    var loadStatePublisher: AnyPublisher<CombinedLoadStates, Never> {
        get { combinedLoadStatesCollection.publisher }
    }
    
    func addOnPagesUpdatedListener(_ listener: @escaping () -> Void) {
        onPagesUpdatedListeners.append(listener)
    }
    
    func removeOnPagesUpdatedListener(_ listener: @escaping () -> Void) {
        onPagesUpdatedListeners.remove(at: onPagesUpdatedListeners.lastIndex(where: { $0() == listener() })!)
    }
    
    func addLoadStateListener(_ listener: @escaping (CombinedLoadStates) -> Void) {
        combinedLoadStatesCollection.addListener(listener)
    }
    
    func removeLoadStateListener(_ listener: @escaping (CombinedLoadStates) -> Void) {
        combinedLoadStatesCollection.removeListener(listener)
    }
    
    private func presentNewList(
        pages: [TransformablePage<T>],
        placeholdersBefore: Int,
        placeholdersAfter: Int,
        dispatchLoadStates: Bool,
        sourceLoadStates: LoadStates?,
        mediatorLoadStates: LoadStates?
    ) {
        guard !dispatchLoadStates || sourceLoadStates != nil else {
            fatalError("Cannot dispatch LoadStates in PagingDataDiffer without source LoadStates set.")
        }
        self.lastAccessedIndexUnfulfilled = false
        let newPresenter = PagePresenter(
            pages: pages,
            placeholdersBefore: placeholdersBefore,
            placeholdersAfter: placeholdersAfter
        )
        var onListPresentableCalled = false
        let transformedLastAccessedIndex = presentNewList(
            previousList: self.presenter,
            newList: newPresenter,
            lastAccessedIndex: lastAccessedIndex,
            onListPresentable: {
                self.presenter = newPresenter
                onListPresentableCalled = true
            }
        )
        guard onListPresentableCalled else {
            fatalError()
        }
        
        if dispatchLoadStates {
            self.dispatchLoadStates(sourceLoadStates!, mediator: mediatorLoadStates)
        }
        if transformedLastAccessedIndex == nil {
            receiver?.accessHint(viewportHint: newPresenter.initializeHint())
        } else {
            self.lastAccessedIndex = transformedLastAccessedIndex!
            receiver?.accessHint(
                viewportHint: newPresenter.accessHintForPresenterIndex(transformedLastAccessedIndex!)
            )
        }
    }
    
    func onChanged(position: Int, count: Int) {
        differCallback.onChanged(position, count)
    }
    
    func onInserted(position: Int, count: Int) {
        differCallback.onInserted(position, count)
    }
    
    func onRemoved(position: Int, count: Int) {
        differCallback.onRemoved(position, count)
    }
    
    func onStateUpdate(source: LoadStates, mediator: LoadStates?) {
        dispatchLoadStates(source, mediator: mediator)
    }
    
    func onStateUpdate(loadType: LoadType, fromMediator: Bool, loadState: LoadState) {
        let currentLoadState = combinedLoadStatesCollection.get(loadType, fromMediator)
        
        if currentLoadState === loadState {
            return
        }
        combinedLoadStatesCollection.set(loadType, fromMediator, loadState)
    }
    
    init(differCallback: DifferCallback, updateItemSnapshotList: @escaping () -> Void) {
        self.differCallback = differCallback
        self.updateItemSnapshotList = updateItemSnapshotList
    }
}

protocol DifferCallback {
    func onChanged(_ position: Int, _ count: Int)
    
    func onInserted(_ position: Int, _ count: Int)
    
    func onRemoved(_ position: Int, _ count: Int)
}
