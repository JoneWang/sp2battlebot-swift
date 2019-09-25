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
    static let telegramId = Expression<Int64>("telegram_id")
    static let telegramFirstName = Expression<String>("telegram_first_name")
    static let telegramLastName = Expression<String?>("telegram_last_name")
    static let telegramUsername = Expression<String?>("telegram_username")
    static let iksmSession = Expression<String?>("iksm_session")

    typealias T = User

    static func createTable() throws {
        let db = DataStore.shared.db
        try db.run(table.create(ifNotExists: true) { t in
            t.column(telegramId, primaryKey: true)
            t.column(telegramFirstName)
            t.column(telegramLastName)
            t.column(telegramUsername, unique: true)
            t.column(iksmSession)
        })
    }

    static func insert(_ item: T) throws {
        let db = DataStore.shared.db
        try db.run(table.insert(telegramId <- item.telegramUser.id,
                                telegramFirstName <- item.telegramUser.firstName,
                                telegramLastName <- item.telegramUser.lastName,
                                telegramUsername <- item.telegramUser.username,
                                iksmSession <- item.iksmSession!))
    }

    static func find(id: Int64) throws -> T? {
        let db = DataStore.shared.db

        let query = table.filter(telegramId == id)
        let items = try db.prepare(query)
        for item in items {
            return User(iksmSession: item[iksmSession],
                        telegramUser: TelegramUser(id: item[telegramId],
                                                   isBot: false,
                                                   firstName: item[telegramFirstName]))
        }

        return nil
    }

    static func update(_ item: T) throws {
        let db = DataStore.shared.db

        let query = table.filter(telegramId == item.telegramUser.id)
        try db.run(query.update(iksmSession <- item.iksmSession,
                                telegramFirstName <- item.telegramUser.firstName,
                                telegramLastName <- item.telegramUser.lastName,
                                telegramUsername <- item.telegramUser.username))
    }
}