//
//  PagePresenter.swift
//  Paging
//
//  Created by 홍희표 on 2023/01/04.
//

import Foundation

internal class PagePresenter<T: Any>: NullPaddedList {
    private var pages: [TransformablePage<T>]
    
    var storageCount: Int
    
    private var originalPageOffsetFirst: Int {
        (pages.first?.originalPageOffsets.min())!
    }
    
    private var originalPageOffsetLast: Int {
        (pages.last?.originalPageOffsets.max())!
    }
    
    var placeholdersBefore: Int
    
    var placeholdersAfter: Int
    
    private func checkIndex(_ index: Int) {
        if index < 0 || index >= size {
            fatalError("Index: \(index), Size: \(size)")
        }
    }
    
    func toString() -> String {
        let items = Array(repeating: { self.getFromStorage($0) }, count: storageCount).map { "\(String(describing: $0))" }.joined()
        return "[(\(placeholdersBefore) placeholders), \(items), (\(placeholdersAfter) placeholders)]"
    }
    
    func get(_ index: Int) -> T? {
        checkIndex(index)
        
        let localIndex = index - placeholdersBefore
        
        if localIndex < 0 || localIndex >= storageCount {
            return nil
        }
        return getFromStorage(localIndex)
    }
    
    func snapshot() -> ItemSnapshotList<T> {
        return ItemSnapshotList(
            placeholdersBefore,
            placeholdersAfter,
            pages.flatMap { $0.data }
        )
    }
    
    func getFromStorage(_ localIndex: Int) -> T {
        var pageIndex = 0
        var indexInPage = localIndex
        let localPageCount = pages.count
        
        while pageIndex < localPageCount {
            let pageCount = pages[pageIndex].data.count
            
            if pageCount > indexInPage {
                break
            }
            indexInPage -= pageCount
            pageIndex += 1
        }
        return pages[pageIndex].data[indexInPage]
    }
    
    var size: Int {
        return self.placeholdersBefore + self.storageCount + self.placeholdersAfter
    }
    
    func processEvent(_ pageEvent: PageEvent<T>, _ callback: ProcessPageEventCallback) {
        switch pageEvent {
        case let event as PageEvent<T>.Insert<T>:
            self.insertPage(event, callback)
        case let event as PageEvent<T>.Drop<T>:
            self.dropPage(event, callback)
        case let event as PageEvent<T>.LoadStateUpdate<T>:
            callback.onStateUpdate(source: event.source, mediator: event.mediator)
        default:
            fatalError()
        }
    }
    
    func initializeHint() -> ViewportHint.Initial {
        let presentedItems = storageCount
        return ViewportHint.Initial(
            presentedItemsBefore: presentedItems / 2,
            presentedItemsAfter: presentedItems / 2,
            originalPageOffsetFirst: originalPageOffsetFirst,
            originalPageOffsetLast: originalPageOffsetLast
        )
    }
    
    func accessHintForPresenterIndex(_ index: Int) -> ViewportHint.Access {
        var pageIndex = 0
        var indexInPage = index - placeholdersBefore
        
        while indexInPage >= pages[pageIndex].data.count && pageIndex < pages.endIndex - 1 {
            indexInPage -= pages[pageIndex].data.count
            pageIndex += 1
        }
        return pages[pageIndex].viewportHintFor(
            indexInPage,
            index - placeholdersBefore,
            size - index - placeholdersAfter - 1,
            originalPageOffsetFirst,
            originalPageOffsetLast
        )
    }
    
    private func insertPage(_ insert: PageEvent<T>.Insert<T>, _ callback: ProcessPageEventCallback) {
        let count = insert.pages.reduce(0) { $0 + $1.data.count }
        let oldCount = size
        
        switch insert.loadType {
        case .refresh:
            fatalError()
        case .prepend:
            let placeholdersChangedCount = min(placeholdersBefore, count)
            let placeholdersChangedPos = placeholdersBefore - placeholdersChangedCount
            let itemsInsertedCount = count - placeholdersChangedCount
            let itemsInsertedPos = 0
            
            pages.insert(contentsOf: insert.pages, at: 0)
            storageCount += count
            placeholdersBefore = insert.placeholdersBefore
            
            callback.onChanged(position: placeholdersChangedPos, count: placeholdersChangedCount)
            callback.onInserted(position: itemsInsertedPos, count: itemsInsertedCount)
            let placeholderInsertedCount = size - oldCount - itemsInsertedCount
            
            if placeholderInsertedCount > 0 {
                callback.onInserted(position: 0, count: placeholderInsertedCount)
            } else if placeholderInsertedCount < 0 {
                callback.onRemoved(position: 0, count: -placeholderInsertedCount)
            }
        case .append:
            let placeholdersChangedCount = min(placeholdersAfter, count)
            let placeholdersChangesPos = placeholdersBefore + storageCount
            let itemsInsertedCount = count - placeholdersChangedCount
            let itemsInsertedPos = placeholdersChangesPos + placeholdersChangedCount
            
            pages += insert.pages
            storageCount += count
            placeholdersAfter = insert.placeholdersAfter
            
            callback.onChanged(position: placeholdersChangesPos, count: placeholdersChangedCount)
            callback.onInserted(position: itemsInsertedPos, count: itemsInsertedCount)
            let placeholderInsertedCount = size - oldCount - itemsInsertedCount
            
            if placeholderInsertedCount > 0 {
                callback.onInserted(position: size - placeholderInsertedCount, count: placeholderInsertedCount)
            } else if placeholderInsertedCount < 0 {
                callback.onRemoved(position: size, count: -placeholderInsertedCount)
            }
        }
        callback.onStateUpdate(
            source: insert.sourceLoadStates,
            mediator: insert.mediatorLoadStates
        )
    }
    
    private func dropPagesWithOffsets(_ pageOffsetsToDrop: ClosedRange<Int>) -> Int {
        var removeCount = 0
        let pageEnumerated = pages.enumerated()
        
        for (index, page) in pageEnumerated {
            if page.originalPageOffsets.contains(where: { pageOffsetsToDrop.contains($0) }) {
                removeCount += page.data.count
                pages.remove(at: index)
            }
        }
        return removeCount
    }
    
    private func dropPage(_ drop: PageEvent<T>.Drop<T>, _ callback: ProcessPageEventCallback) {
        let oldCount = size
        
        if drop.loadType == .prepend {
            let oldPlaceholdersBefore = placeholdersBefore
            let itemDropCount = dropPagesWithOffsets(drop.minPageOffset...drop.maxPageOffset)
            storageCount -= itemDropCount
            placeholdersBefore = drop.placeholdersRemaining
            let expectedCount = size
            let placeholdersToInsert = expectedCount - oldCount
            
            if placeholdersToInsert > 0 {
                callback.onInserted(position: 0, count: placeholdersToInsert)
            } else if placeholdersToInsert < 0 {
                callback.onRemoved(position: 0, count: -placeholdersToInsert)
            }
            let firstItemIndex = max(0, oldPlaceholdersBefore + placeholdersToInsert)
            let changeCount = drop.placeholdersRemaining - firstItemIndex
            
            if changeCount > 0 {
                callback.onChanged(position: firstItemIndex, count: changeCount)
            }
            callback.onStateUpdate(
                loadType: .prepend,
                fromMediator: false,
                loadState: .NotLoading(false)
            )
        } else {
            let oldPlaceholdersAfter = placeholdersAfter
            let itemDropCount = dropPagesWithOffsets(drop.minPageOffset...drop.maxPageOffset)
            storageCount -= itemDropCount
            placeholdersAfter = drop.placeholdersRemaining
            let expectedCount = size
            let placeholderToInsert = expectedCount - oldCount
            
            if placeholderToInsert > 0 {
                callback.onInserted(position: oldCount, count: placeholderToInsert)
            } else if placeholderToInsert < 0 {
                callback.onRemoved(position: oldCount + placeholderToInsert, count: -placeholderToInsert)
            }
            let oldPlaceholdersRemoved = placeholderToInsert < 0 ? min(oldPlaceholdersAfter, -placeholderToInsert) : 0
            let changeCount = drop.placeholdersRemaining - (oldPlaceholdersAfter - oldPlaceholdersRemoved)
            
            if changeCount > 0 {
                callback.onChanged(position: size - drop.placeholdersRemaining, count: changeCount)
            }
            callback.onStateUpdate(
                loadType: .append,
                fromMediator: false,
                loadState: .NotLoading(false)
            )
        }
    }
    
    init(
        pages: [TransformablePage<T>],
        placeholdersBefore: Int,
        placeholdersAfter: Int
    ) {
        self.pages = pages
        self.storageCount = pages.reduce(0) { $0 + $1.data.count }
        self.placeholdersBefore = placeholdersBefore
        self.placeholdersAfter = placeholdersAfter
    }
    
    convenience init(_ insertEvent: PageEvent<T>.Insert<T>) {
        self.init(
            pages: insertEvent.pages,
            placeholdersBefore: insertEvent.placeholdersBefore,
            placeholdersAfter: insertEvent.placeholdersAfter
        )
    }
    
    internal static func initial() -> PagePresenter<T> {
        return PagePresenter<T>(PageEvent<T>.Insert<T>.Refresh(
            pages: [TransformablePage<T>.EMPTY_INITIAL_PAGE],
            placeholdersBefore: 0,
            placeholdersAfter: 0,
            sourceLoadStates: LoadStates(.NotLoading(false), .NotLoading(true), .NotLoading(true))
        ))
    }
}

internal protocol ProcessPageEventCallback {
    func onChanged(position: Int, count: Int)
    func onInserted(position: Int, count: Int)
    func onRemoved(position: Int, count: Int)
    func onStateUpdate(loadType: LoadType, fromMediator: Bool, loadState: LoadState)
    func onStateUpdate(source: LoadStates, mediator: LoadStates?)
}
