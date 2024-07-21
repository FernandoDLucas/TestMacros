import TestMacros

@Fixture
struct Island {

    var name: String
    var population: Int
    var beachs: [String]
    var neightboors: [Island]

}

@Spy
final class someC {

    private func that()  {}

    func they() {
        
    }

}

public final class SpyClass<T> {

    public init () {}

    public var isCalled: Bool = false
    public var response: T?

    public func resetState() {
        self.isCalled = false
        self.response = nil
    }
}
