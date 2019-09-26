//
// Created by Jone Wang on 25/9/2019.
//

import Foundation
import SQLite

protocol DataHelper {
    associatedtype T
    static var table: Table { get }
    static func createTable() throws
    static func insert(_ item: T) throws
    static func find(id: Int64) throws -> T?
    static func update(_ item: T) throws
}

class UserDataHelper: DataHelper {
    static let table = Table("users")
    static let userId = Expression<Int64>("id")
    static let username = Expression<String?>("username")
    static let firstName = Expression<String>("first_name")
    static let lastName = Expression<String?>("last_name")
    static let iksmSession = Expression<String?>("iksm_session")

    typealias T = User

    static func createTable() throws {
        let db = DataStore.shared.db
        try db.run(table.create(ifNotExists: true) { t in
            t.column(userId, primaryKey: true)
            t.column(firstName)
            t.column(lastName)
            t.column(username, unique: true)
            t.column(iksmSession)
        })
    }

    static func insert(_ item: T) throws {
        let db = DataStore.shared.db
        try db.run(table.insert(userId <- item.id,
                                firstName <- item.firstName,
                                lastName <- item.lastName,
                                username <- item.username,
                                iksmSession <- item.iksmSession!))
    }

    static func find(id: Int64) throws -> T? {
        let db = DataStore.shared.db

        let query = table.filter(userId == id)
        let items = try db.prepare(query)
        for item in items {
            var user = User(id: item[userId],
                            isBot: false,
                            username: item[username],
                            firstName: item[firstName],
                            lastName: item[lastName])
            user.iksmSession = item[iksmSession]
            return user
        }

        return nil
    }

    static func update(_ item: T) throws {
        let db = DataStore.shared.db

        let query = table.filter(userId == item.id)
        try db.run(query.update(iksmSession <- item.iksmSession,
                                firstName <- item.firstName,
                                lastName <- item.lastName,
                                username <- item.username))
    }
}