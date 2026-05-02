//
//  LoadType.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/19.
//

import Foundation

public enum LoadType: CaseIterable {
    var ordinal: Int {
        return LoadType.allCases.firstIndex(of: self) ?? -1
    }
    case refresh
    case prepend
    case append
}
