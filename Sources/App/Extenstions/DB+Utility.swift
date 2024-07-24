//
//  File.swift
//  
//
//  Created by Vamsi Madduluri on 21/07/24.
//

import Foundation
import Vapor
import Fluent

// MARK: DB Transactions
extension Model {
    
    static func existing(matching: ModelValueFilter<Self>, on database: Database) async throws -> Self? {
        return try await Self.query(on: database).filter(matching).first()
    }
    
    static func isExisting(matching: ModelValueFilter<Self>, on database: Database) async throws -> Bool {
        return try await existing(matching: matching, on: database) != nil
    }
}
