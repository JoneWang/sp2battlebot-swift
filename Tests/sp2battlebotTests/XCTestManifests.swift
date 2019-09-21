import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(sp2battlebotTests.allTests),
    ]
}
#endif
