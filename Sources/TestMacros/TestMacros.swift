/// A macro that produces a fixture() function with default values
/// values not mapped, will be initialized with .fixture()
/// so make sure to implement .fixture() on custom objects
@attached(member, names: named(fixture))
public macro Fixture() = #externalMacro(module: "TestMacrosMacros", type: "FixtureMacro")
