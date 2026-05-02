//
//  ItemSnapshotList.swift
//  Paging
//
//  Created by 홍희표 on 2023/01/04.
//

struct ItemSnapshotList<T>: RangeReplaceableCollection {
    typealias Element = T
    typealias Index = Int
    typealias SubSequence = ItemSnapshotList<T>
    typealias Indices = Range<Int>
    fileprivate var array: Array<T>
    
    let placeholdersBefore: Int
    
    let placeholdersAfter: Int

    var startIndex: Int { return array.startIndex }
    var endIndex: Int { return array.endIndex }
    var indices: Range<Int> { return array.indices }


    func index(after i: Int) -> Int {
        return array.index(after: i)
    }
    
    var count: Int {
        return placeholdersBefore + array.count + placeholdersAfter
    }

    init(_ placeholdersBefore: Int, _ placeholdersAfter: Int, _ array: [T]) {
        self.placeholdersBefore = placeholdersBefore
        self.placeholdersAfter = placeholdersAfter
        self.array = array
    }

    init() {
        placeholdersBefore = 0
        placeholdersAfter = 0
        array = []
    }
}

// Instance Methods

/*extension ItemSnapshotList {
    init<S>(_ elements: S) where S : Sequence, ItemSnapshotList.Element == S.Element {
        array = Array<S.Element>(elements)
    }

    init(repeating repeatedValue: ItemSnapshotList.Element, count: Int) {
        array = Array(repeating: repeatedValue, count: count)
    }
}*/

// Instance Methods

extension ItemSnapshotList {
    public mutating func append(_ newElement: ItemSnapshotList.Element) {
        array.append(newElement)
    }

    public mutating func append<S>(contentsOf newElements: S) where S : Sequence, ItemSnapshotList.Element == S.Element {
        array.append(contentsOf: newElements)
    }

    func filter(_ isIncluded: (ItemSnapshotList.Element) throws -> Bool) rethrows -> ItemSnapshotList {
        let subArray = try array.filter(isIncluded)
        return ItemSnapshotList(subArray)
    }

    public mutating func insert(_ newElement: ItemSnapshotList.Element, at i: ItemSnapshotList.Index) {
        array.insert(newElement, at: i)
    }

    mutating func insert<S>(contentsOf newElements: S, at i: ItemSnapshotList.Index) where S : Collection, ItemSnapshotList.Element == S.Element {
        array.insert(contentsOf: newElements, at: i)
    }

    mutating func popLast() -> ItemSnapshotList.Element? {
        return array.popLast()
    }

    @discardableResult mutating func remove(at i: ItemSnapshotList.Index) -> ItemSnapshotList.Element {
        return array.remove(at: i)
    }

    mutating func removeAll(keepingCapacity keepCapacity: Bool) {
        array.removeAll()
    }

    mutating func removeAll(where shouldBeRemoved: (ItemSnapshotList.Element) throws -> Bool) rethrows {
        try array.removeAll(where: shouldBeRemoved)
    }

    @discardableResult mutating func removeFirst() -> ItemSnapshotList.Element {
        return array.removeFirst()
    }

    mutating func removeFirst(_ k: Int) {
        array.removeFirst(k)
    }
    @discardableResult mutating func removeLast() -> ItemSnapshotList.Element {
        return array.removeLast()
    }

    mutating func removeLast(_ k: Int) {
        array.removeLast(k)
    }

    mutating func removeSubrange(_ bounds: Range<Int>) {
        array.removeSubrange(bounds)
    }

    mutating func replaceSubrange<C, R>(_ subrange: R, with newElements: C) where C : Collection, R : RangeExpression, T == C.Element, ItemSnapshotList<T>.Index == R.Bound {
        array.replaceSubrange(subrange, with: newElements)
    }

    mutating func reserveCapacity(_ n: Int) {
        array.reserveCapacity(n)
    }
}

// Subscripts

extension ItemSnapshotList {
    subscript(bounds: Range<ItemSnapshotList.Index>) -> ItemSnapshotList.SubSequence {
        get { return ItemSnapshotList(array[bounds]) }
    }

    subscript(bounds: ItemSnapshotList.Index) -> ItemSnapshotList.Element {
        get {
            switch bounds {
            case placeholdersBefore..<(placeholdersBefore + array.count):
                return array[bounds - placeholdersBefore]
            default:
                return array[bounds]
            }
        }
        set(value) { array[bounds] = value }
    }
}

// Operator Functions

extension ItemSnapshotList {
    static func + <Other>(lhs: Other, rhs: ItemSnapshotList) -> ItemSnapshotList where Other : Sequence, ItemSnapshotList.Element == Other.Element {
        return ItemSnapshotList(lhs + rhs.array)
    }

    static func + <Other>(lhs: ItemSnapshotList, rhs: Other) -> ItemSnapshotList where Other : Sequence, ItemSnapshotList.Element == Other.Element{
         return ItemSnapshotList(lhs.array + rhs)
    }

    static func + <Other>(lhs: ItemSnapshotList, rhs: Other) -> ItemSnapshotList where Other : RangeReplaceableCollection, ItemSnapshotList.Element == Other.Element {
        return ItemSnapshotList(lhs.array + rhs)
    }

    static func + (lhs: ItemSnapshotList<T>, rhs: ItemSnapshotList<T>) -> ItemSnapshotList {
        return ItemSnapshotList(lhs.array + rhs.array)
    }

    static func += <Other>(lhs: inout ItemSnapshotList, rhs: Other) where Other : Sequence, ItemSnapshotList.Element == Other.Element {
        lhs.array += rhs
    }
}

extension ItemSnapshotList: CustomStringConvertible {
    var description: String { return "\(array)" }
}
