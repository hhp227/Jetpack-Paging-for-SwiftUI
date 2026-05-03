//
//  LazyPagingItems.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/19.
//

import Foundation
import Combine
import SwiftUI

public class LazyPagingItems<T : Any>: ObservableObject, DifferCallback {
    private let publisher: AnyPublisher<PagingData<T>, Never>
    
    @Published private(set) var itemSnapshotList = ItemSnapshotList<T>(0, 0, [])
    
    private var hasStartedCollection = false

    var itemCount: Int {
        get {
            return pagingDataDiffer.size
        }
    }
    
    private lazy var pagingDataDiffer: PagingDataDiffer<T> = PagingDataDiffer<T>(
        differCallback: self,
        updateItemSnapshotList: updateItemSnapshotList
    )

    private var subscriptions = Set<AnyCancellable>()

    private func updateItemSnapshotList() {
        if Thread.isMainThread {
            self.itemSnapshotList = self.pagingDataDiffer.snapshot()
        } else {
            DispatchQueue.main.async {
                self.itemSnapshotList = self.pagingDataDiffer.snapshot()
            }
        }
    }

    public func get(_ index: Int) -> T? {
        let _ = pagingDataDiffer.get(index: index)
        return itemSnapshotList[index]
    }

    public func peek(_ index: Int) -> T? {
        return itemSnapshotList[index]
    }

    public func retry() {
        pagingDataDiffer.retry()
    }

    public func refresh() {
        pagingDataDiffer.refresh()
    }

    @Published public private(set) var loadState: CombinedLoadStates = CombinedLoadStates(
        refresh: InitialLoadStates.refresh,
        prepend: InitialLoadStates.prepend,
        append: InitialLoadStates.append,
        source: InitialLoadStates
    )
    
    internal func collectLoadState() {
        pagingDataDiffer.loadStatePublisher
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .assign(to: \.loadState, on: self)
            .store(in: &subscriptions)
    }
    
    internal func collectPagingData() {
        publisher
            .buffer(size: 1, prefetch: .keepFull, whenFull: .dropOldest)
            .sink(receiveValue: self.pagingDataDiffer.collectFrom)
            .store(in: &subscriptions)
    }
    
    func startCollecting() {
        guard !hasStartedCollection else { return }
        hasStartedCollection = true
        collectPagingData()
        collectLoadState()
    }

    func onChanged(_ position: Int, _ count: Int) {
        if count > 0 {
            updateItemSnapshotList()
        }
    }

    func onInserted(_ position: Int, _ count: Int) {
        if count > 0 {
            updateItemSnapshotList()
        }
    }

    func onRemoved(_ position: Int, _ count: Int) {
        if count > 0 {
            updateItemSnapshotList()
        }
    }

    init<P: Publisher>(_ publisher: P) where P.Output == PagingData<T>, P.Failure == Never {
        self.publisher = publisher.eraseToAnyPublisher()
    }
}

private let InitialLoadStates = LoadStates(
    refresh: .Loading.instance,
    prepend: .NotLoading(false),
    append: .NotLoading(false)
)

extension Publisher where Failure == Never {
    public func collectAsLazyPagingItems<T>() -> LazyPagingItems<T> where Output == PagingData<T> {
        let lazyPagingItems = LazyPagingItems(self)
        lazyPagingItems.startCollecting()
        return lazyPagingItems
    }
}

extension ForEach where Data == Range<Int>, ID == Int, Content : View {
    public init<T>(_ data: LazyPagingItems<T>, @ViewBuilder content: @escaping (T?) -> Content) {
        print("???? \(data.itemCount)")
        self.init(0..<data.itemCount, id: \.self) { index in
            content(data.get(index))
        }
    }
}

/*extension ForEach where Data == Range<Int>, ID == Int, Content == AnyView {
    public init<T>(_ data: LazyPagingItems<T>, @ViewBuilder content: @escaping (T?) -> Content) {
        self.init(0..<data.itemCount, id: \.self) { index in
            AnyView(content(data.get(index)).onAppear {
                data.get(index)
            })
            // TODO 여기서. onAppear로 accessHint접근하는방법 알아보기
        }
    }
}*/
