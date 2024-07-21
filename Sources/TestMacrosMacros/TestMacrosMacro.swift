import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct FixtureMacro: MemberMacro {
    @main
    struct CopyableMacroPlugin: CompilerPlugin {
        let providingMacros: [Macro.Type] = [
            FixtureMacro.self,
            SpyMacro.self
        ]
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let storedProperties = declaration
            .as(StructDeclSyntax.self)?.storedProperties(),
              !storedProperties.isEmpty
        else { return [] }
        
        let funcArguments = storedProperties
            .compactMap { property -> (name: String, type: String, value: String)? in
                guard
                    let patternBinding = property.bindings.first?.as(
                        PatternBindingSyntax.self
                    ),
                    
                    let name = patternBinding.pattern.as(
                        IdentifierPatternSyntax.self
                    )?.identifier,
                    let anottation = patternBinding.typeAnnotation,
                        let type = anottation.as(TypeAnnotationSyntax.self)?.trimmed.description.replacingOccurrences(of: "?", with: "")
                else { return nil }
                
                return (name: name.text, type: type, value: getFixtureForType(anottation.type.description.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        
        let funcBody: ExprSyntax = """
        .init(
        \(raw: funcArguments.map { "\($0.name): \($0.name)" }.joined(separator: ", \n"))
        )
        """
        
        guard
            let funcDeclSyntax = try? FunctionDeclSyntax(
                SyntaxNodeString(
                    stringLiteral: """
                    static func fixture(
                    \(funcArguments.map { "\($0.name)\($0.type) = \($0.value) "}.joined(separator: ", \n"))
                    ) -> Self
                    """.trimmingCharacters(in: .whitespacesAndNewlines)
                ),
                bodyBuilder: {
                    funcBody
                }
            ),
            let finalDeclaration = DeclSyntax(funcDeclSyntax)
        else {
            return []
        }
        
        return [finalDeclaration]
    }
    
    
}

extension VariableDeclSyntax {
    var isStoredProperty: Bool {
        guard let binding = bindings.first,
              bindings.count == 1
        else { return false }
        
        switch binding.accessorBlock?.accessors {
        case .none:
            return true
            
        case .accessors(let node):
            for accessor in node {
                switch accessor.accessorSpecifier.tokenKind {
                case .keyword(.willSet), .keyword(.didSet):
                    // stored properties can have observers
                    break
                default:
                    // everything else makes it a computed property
                    return false
                }
            }
            return true
            
        case .getter:
            return false
        }
    }
}

extension DeclGroupSyntax {
    func storedProperties() -> [VariableDeclSyntax] {
        memberBlock.members.compactMap { member in
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                  variable.isStoredProperty
            else { return nil }
            
            return variable
        }
    }
}

func getFixtureForType(_ value: String) -> String {
    switch value.replacingOccurrences(of: "?", with: "") {
    case "String":
        return """
            "someString"
        """
    case "Int":
        return "0"
    case let array where value.contains("["):
        if array.contains("String") {
            return """
                ["someString"]
            """
        } else {
            return """
                [.fixture()]
            """
        }
    default:
        return ".fixture()"
    }

}


public struct SpyMacro: MemberMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let declaration = declaration.as(ClassDeclSyntax.self) else {
            return []
        }
        let functions = declaration.memberBlock.members.map {
            $0.decl.as(FunctionDeclSyntax.self)
        }.compactMap {
            $0?.name.text
        }.joined(separator: ",")

        let newFunc = try FunctionDeclSyntax("private func that() {}").as(DeclSyntax.self)
        return [
            """
        enum Functions {
            case \(raw: functions)
        }
        
        """
        ]
    }

}
