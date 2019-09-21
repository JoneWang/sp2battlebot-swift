//
//  SP2API.swift
//  sp2battlebot
//
//  Created by Jone Wang on 21/9/2019.
//

import Foundation
import Moya

enum SP2API {
    case battleList
    case battleDetail(id: String)
}

extension SP2API: TargetType {
    var baseURL: URL {
        return URL(string: "https://app.splatoon2.nintendo.net")!
    }
    
    var path: String {
        switch self {
        case .battleList:
            return "/api/results"
        case .battleDetail(let id):
            return "/api/results/\(id)"
        }
    }
    
    var method: Moya.Method {
        return .get
    }
    
    var sampleData: Data {
        return "".data(using: .utf8)!
    }
    
    var task: Task {
        return .requestPlain
    }
    
    var headers: [String: String]? {
        return [
            "Cookie": "iksm_session=\(BotController.shared.sp2Session); path=/; domain=.app.splatoon2.nintendo.net;",
            "Accept": "application/json"
        ]
    }
}
