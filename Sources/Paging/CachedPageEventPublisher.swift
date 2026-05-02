//
//  CachedPageEventPublisher.swift
//  Application
//
//  Created by hhp227 on 6/11/24.
//

import Foundation
import Combine

internal class CachedPageEventPublisher<T: Any> {
    private let pageController = FlattenedPageController<T>()
    private let mutableSharedSrc = PassthroughSubject<EnumeratedSequence<[PageEvent<T>]>.Element?, Never>()
    private var cancellables = Set<AnyCancellable>()
    private let upstream: AnyPublisher<PageEvent<T>, Never>

    private lazy var job: AnyCancellable = upstream
        .withIndex()
        .sink(
            receiveCompletion: { _ in self.mutableSharedSrc.send(nil) },
            receiveValue: {
                self.mutableSharedSrc.send($0)
                self.pageController.record($0)
            }
        )
    
    private func getSharedForDownstream() -> AnyPublisher<EnumeratedSequence<[PageEvent<T>]>.Element?, Never> {
        print("getSharedForDownstream")
        let history = self.pageController.getStateAsEvents()
        print("history: \(history)")
        self.job.store(in: &self.cancellables)
        
        return history.publisher
            .map { Optional($0) }
            .append(mutableSharedSrc)
            .eraseToAnyPublisher()
    }

    func close() {
        job.cancel()
    }
    
    var downstreamPublisher: AnyPublisher<PageEvent<T>, Never> {
        let callback1: (EnumeratedSequence<[PageEvent<T>]>.Element?, Int) -> Void = { print("test1 maxEventIndex=\($1) indexedValue: offset=\($0!.offset) value=\($0?.element) \(($0?.element as? PageEvent<T>.Insert<T>)?.loadType)") }
        let callback2: (EnumeratedSequence<[PageEvent<T>]>.Element?, Int) -> Void = { print("test2 maxEventIndex=\($1) indexedValue: offset=\($0!.offset) value=\($0?.element) \(($0?.element as? PageEvent<T>.Insert<T>)?.loadType)") }
        return DownstreamPublisher<T>(sharedForDownstream: getSharedForDownstream, callback1: callback1, callback2: callback2).eraseToAnyPublisher()
    }

    init(src: AnyPublisher<PageEvent<T>, Never>) {
        self.upstream = src
    }
}

struct DownstreamPublisher<T: Any>: Publisher {
    typealias Output = PageEvent<T>
    typealias Failure = Never
    
    var sharedForDownstream: () -> AnyPublisher<EnumeratedSequence<[PageEvent<T>]>.Element?, Never>

    var callback1: (EnumeratedSequence<[PageEvent<T>]>.Element?, Int) -> Void
    var callback2: (EnumeratedSequence<[PageEvent<T>]>.Element?, Int) -> Void

    func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, PageEvent<T> == S.Input {
        let subscription = DownstreamSubscription(subscriber: subscriber, sharedForDownstream: sharedForDownstream, callback1: callback1, callback2: callback2)

        subscriber.receive(subscription: subscription)
    }

    private class DownstreamSubscription<S: Subscriber>: Subscription where S.Input == PageEvent<T>, S.Failure == Never {
        var subscriber: S?
        var maxEventIndex = Int.min
        var sharedForDownstream: () -> AnyPublisher<EnumeratedSequence<[PageEvent<T>]>.Element?, Never>
        var callback1: (EnumeratedSequence<[PageEvent<T>]>.Element?, Int) -> Void
        var callback2: (EnumeratedSequence<[PageEvent<T>]>.Element?, Int) -> Void
        var cancellable: AnyCancellable? = nil

        init(subscriber: S, sharedForDownstream: @escaping () ->  AnyPublisher<EnumeratedSequence<[PageEvent<T>]>.Element?, Never>, callback1: @escaping (EnumeratedSequence<[PageEvent<T>]>.Element?, Int) -> Void, callback2: @escaping (EnumeratedSequence<[PageEvent<T>]>.Element?, Int) -> Void) {
            self.subscriber = subscriber
            self.sharedForDownstream = sharedForDownstream
            self.callback1 = callback1
            self.callback2 = callback2
        }

        func request(_ demand: Subscribers.Demand) {
            self.cancellable = self.sharedForDownstream()
                .prefix(while: { $0 != nil })
                .sink { indexedValue in
                    self.callback1(indexedValue, self.maxEventIndex)
                    if indexedValue!.offset > self.maxEventIndex {
                        self.callback2(indexedValue, self.maxEventIndex)
                        _ = self.subscriber?.receive(indexedValue!.element)
                        self.maxEventIndex = indexedValue!.offset
                    }
                }
            // better code
            /*sharedForDownstream
                .prefix(while: { $0 != nil })
                .compactMap { $0 }
                .filter { $0.offset > self.maxEventIndex }
                .handleEvents(receiveOutput: { self.maxEventIndex = $0.offset })
                .sink { _ = self.subscriber?.receive($0.element) }
                .store(in: &cancellables)*/
        }

        func cancel() {
            subscriber = nil
        }
    }
}

private class FlattenedPageController<T: Any> {
    private let list = FlattenedPageEventStorage<T>()
    private let lock = NSLock()
    private var maxEventIndex = -1

    func record(_ event: EnumeratedSequence<[PageEvent<T>]>.Element) {
        lock.withLock {
            maxEventIndex = event.offset
            list.append(event.element)
        }
    }

    func getStateAsEvents() -> [EnumeratedSequence<[PageEvent<T>]>.Element] {
        return lock.withLock {
            let catchupEvents = list.getAsEvents()
            let startEventIndex = maxEventIndex - catchupEvents.count + 1
            return catchupEvents.enumerated().map { (index, pageEvent) in
                (offset: startEventIndex + index, element: pageEvent)
            }
        }
    }
}

internal class FlattenedPageEventStorage<T: Any> {
    private var placeholdersBefore = 0
    private var placeholdersAfter = 0
    private var pages = [TransformablePage<T>]()
    private var sourceStates = MutableLoadStateCollection()
    private var mediatorStates: LoadStates? = nil
    private var receivedFirstEvent = false

    func append(_ event: PageEvent<T>) {
        receivedFirstEvent = true
        switch event {
        case let insert as PageEvent<T>.Insert<T>:
            handleInsert(insert)
        case let drop as PageEvent<T>.Drop<T>:
            handlePageDrop(drop)
        case let loadStateUpdate as PageEvent<T>.LoadStateUpdate<T>:
            handleLoadStateUpdate(loadStateUpdate)
        case let staticList as PageEvent<T>.StaticList<T>:
            handleStaticList(staticList)
        default:
            break
        }
    }

    private func handlePageDrop(_ event: PageEvent<T>.Drop<T>) {
        sourceStates.set(event.loadType, .NotLoading(false))
        switch event.loadType {
        case .prepend:
            placeholdersBefore = event.placeholdersRemaining
            pages.removeFirst(event.pageCount)
        case .append:
            placeholdersAfter = event.placeholdersRemaining
            pages.removeLast(event.pageCount)
        default:
            fatalError("Page drop type must be prepend or append")
        }
    }

    private func handleInsert(_ event: PageEvent<T>.Insert<T>) {
        sourceStates.set(event.sourceLoadStates)
        mediatorStates = event.mediatorLoadStates

        switch event.loadType {
        case .refresh:
            pages.removeAll()
            placeholdersAfter = event.placeholdersAfter
            placeholdersBefore = event.placeholdersBefore
            pages += event.pages
        case .prepend:
            placeholdersBefore = event.placeholdersBefore
            pages.insert(contentsOf: event.pages.reversed(), at: 0)
        case .append:
            placeholdersAfter = event.placeholdersAfter
            pages += event.pages
        }
    }

    private func handleLoadStateUpdate(_ event: PageEvent<T>.LoadStateUpdate<T>) {
        sourceStates.set(event.source)
        mediatorStates = event.mediator
    }
    
    private func handleStaticList(_ event: PageEvent<T>.StaticList<T>) {
        if event.sourceLoadStates != nil {
            sourceStates.set(event.sourceLoadStates!)
        }
        
        if event.mediatorLoadStates != nil {
            mediatorStates = event.mediatorLoadStates
        }
        
        pages.removeAll()
        placeholdersAfter = 0
        placeholdersBefore = 0
        pages.append(TransformablePage(originalPageOffset: 0, data: event.data))
    }

    func getAsEvents() -> [PageEvent<T>] {
        guard receivedFirstEvent else { return [] }
        var events = [PageEvent<T>]()
        let source = sourceStates.snapshot()
        if !pages.isEmpty {
            events.append(
                PageEvent<T>.Insert.Refresh(
                    pages: pages,
                    placeholdersBefore: placeholdersBefore,
                    placeholdersAfter: placeholdersAfter,
                    sourceLoadStates: source,
                    mediatorLoadStates: mediatorStates
                )
            )
        } else {
            events.append(
                PageEvent<T>.LoadStateUpdate(
                    source: source,
                    mediator: mediatorStates
                )
            )
        }
        return events
    }
}

extension Publisher {
    func withIndex() -> AnyPublisher<EnumeratedSequence<[Output]>.Element, Failure> {
        self.scan((offset: -1, element: nil as Output?)) { (acc, current) in
            (offset: acc.offset + 1, element: current)
        }
        .compactMap { (index, value) in
            value.map { (offset: index, element: $0) }
        }
        .eraseToAnyPublisher()
    }
}
