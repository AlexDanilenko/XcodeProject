//
//  Allswift
//  xcp
//
//  Created by kingkong999yhirose on 2016/12/23.
//  Copyright © 2016年 kingkong999yhirose. All rights reserved.
//

import Foundation

public typealias PathType = [PBXObjectIDType: PathComponent]
// TODO: Confirm Iteratable, Collection
public protocol Context: class {
    var objects: [String: PBX.Object] { get set }
    var fullFilePaths: PathType { get }
    var xcodeprojectUrl: URL { get }
    var xcodeprojectDirectoryURL: URL { get }
    var allPBX: PBXRawMapType { get }

    func extractPBXProject() -> PBX.Project
    func extractProjectName() -> String
    func resetGroupFullPaths()
    // FIXME: Integrate reset Group full paths
    func createGroupPath(with group: PBX.Group, parentPath: String) 

    func object<T: PBX.Object>(for key: String) -> T
}

// MARK: Convenience Accessors
extension Context {
    public var rootID: String {
        return allPBX["rootObject"] as! String
    }
    public var mainGroup: PBX.Group {
        return extractPBXProject().mainGroup
    }
    private func list<T: PBX.Object>() -> [T] {
        return objects.values.toArray().ofType(T.self)
    }
    public var fileRefs: [PBX.FileReference] {
        return list()
    }
    public var groups: [PBX.Group] {
        return list()
    }
    public var buildFiles: [PBX.BuildFile] {
        return list()
    }
    public var buildPhases: [PBX.BuildPhase] {
        return list()
    }
    public var targets: [PBX.Target] {
        return list()
    }
}

class InternalContext: Context {
    var objects: [String: PBX.Object] = [:]
    var fullFilePaths: PathType = [:]
    var allPBX: PBXRawMapType
    let xcodeprojectUrl: URL
    var xcodeprojectDirectoryURL: URL {
        let directory = xcodeprojectUrl
            .absoluteString
            .components(separatedBy: "/")
            .dropLast() // drop project.pbxproj
            .dropLast() // drop YOUR_PROJECT.xcodeproj
            .joined(separator: "/")
        return URL(fileURLWithPath: directory)
    }

    init(
        allPBX: PBXRawMapType,
        xcodeProjectUrl: URL
        ) {
        self.allPBX = allPBX
        self.xcodeprojectUrl = xcodeProjectUrl
        setup()
    }
    
    func extractPBXProject() -> PBX.Project {
        for value in objects.values {
            if let v = value as? PBX.Project {
                return v
            }
        }
        fatalError()
    }
    
    func extractProjectName() -> String {
        guard let xcodeProjFile = xcodeprojectUrl
            .pathComponents
            .dropLast() // drop project.pbxproj
            .last // get PROJECTNAME.xcodeproj
            else {
                fatalError("No Xcode project found from \(xcodeprojectUrl.absoluteString), please specify one")
        }
        
        guard let projectName = xcodeProjFile.components(separatedBy: ".").first else {
            fatalError("Can not get project name from \(xcodeProjFile)")
        }
        
        return projectName
    }

    func object<T: PBX.Object>(for key: String) -> T {
        guard let object = objects[key] as? T else {
            fatalError(assertionMessage(description: "wrong format is \(T.self): \(key)"))
        }
        return object
    }
    
    func resetGroupFullPaths() {
        let project = extractPBXProject()
        fullFilePaths.removeAll()
        
        createFileRefPath(with: project.mainGroup)
        createFileRefForSubGroupPath(with: project.mainGroup)
        createGroupPath(with: project.mainGroup, parentPath: "")
    }
}


// MARK: Create
private extension InternalContext {
    func setup() {
        let objects = allPBX["objects"] as! [String: PBXRawMapType]
        objects
            .forEach { (hashId, objectDictionary) in
                guard
                    let isa = objectDictionary["isa"] as? String
                    else {
                        fatalError(
                            assertionMessage(description:
                                "not exists isa key: \(hashId), value: \(objectDictionary)",
                                "you should check for project.pbxproj that is correct."
                            )
                        )
                }
                
                let pbxType = ObjectType.type(with: isa)
                let pbxObject = pbxType.init(
                    id: hashId,
                    dictionary: objectDictionary,
                    isa: isa,
                    context: self
                )
                
                self.objects[hashId] = pbxObject
        }
        resetGroupFullPaths()
    }
}

// TODO: Move to PBX.Project
extension InternalContext {
    func createGroupPath(with group: PBX.Group, parentPath: String) {
        defer {
            group.subGroups.forEach { createGroupPath(with: $0, parentPath: group.fullPath) }
        }
        guard let path = group.path else {
            return
        }
        switch parentPath.isEmpty {
        case true:
            group.fullPath = path
        case false:
            group.fullPath = parentPath + "/" + path
        }
    }
    
    func createFileRefForSubGroupPath(with group: PBX.Group, prefix: String = "") {
        group
            .subGroups
            .forEach { subGroup in
                guard let path = subGroup.path else {
                    createFileRefPath(with: subGroup, prefix: prefix)
                    createFileRefForSubGroupPath(with: subGroup, prefix: prefix)
                    return
                }
                let nextPrefix: String
                switch group.sourceTree {
                case .group:
                    nextPrefix = generatePath(with: prefix, path: path)
                default:
                    nextPrefix = prefix
                }
                createFileRefPath(with: subGroup, prefix: nextPrefix)
                createFileRefForSubGroupPath(with: subGroup, prefix: nextPrefix)
        }
    }
    
    func createFileRefPath(with group: PBX.Group, prefix: String = "") {
        group
            .fileRefs
            .forEach { reference in
                guard let path = reference.path else {
                    return
                }
                switch (reference.sourceTree, group.sourceTree) {
                case (.group, .group) :
                    fullFilePaths[reference.id] = .environmentPath(.SOURCE_ROOT, generatePath(with: prefix, path: path))
                case (.group, .absolute) :
                    fullFilePaths[reference.id] = .simple(generatePath(with: prefix, path: path))
                case (.group, .folder(let environment)) :
                    fullFilePaths[reference.id] = .environmentPath(environment, generatePath(with: prefix, path: path))
                case (.absolute, _):
                    fullFilePaths[reference.id] = .simple(path)
                case (.folder(let environment), _):
                    fullFilePaths[reference.id] = .environmentPath(environment, generatePath(with: prefix, path: path))
                }
        }
    }
    
    func generatePath(with prefix: String, path: String) -> String {
        return prefix + "/" + path
    }
}

