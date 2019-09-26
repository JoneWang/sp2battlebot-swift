//
// Created by Jone Wang on 25/9/2019.
//

import Foundation
import SQLite

enum DataStoreError: Error {
    case DatabaseConnectionError
    case InsertError
    case DeleteError
    case SearchError
    case NilInData
    case Error
}

class DataStore {
    static var shared = DataStore()

    var db: Connection

    init() {
        do {
            let currentPath = FileManager.default.currentDirectoryPath
            let sqlitePath = "\(currentPath)/bot.sqlite3"
            print("sqlite path: \(sqlitePath)")
            db = try Connection(sqlitePath)
        } catch {
            print("SQLite error: \(error)")
            exit(1)
        }
    }

    func createTables() throws {
        do {
            try UserDataHelper.createTable()
        } catch {
            print(error)
            throw DataStoreError.DatabaseConnectionError
        }
    }
}
