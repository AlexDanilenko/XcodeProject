import XCTest
@testable import XcodeProjectCore

class XcodeProjectTests: XCTestCase {
    
    // This test is overwrite actual project.pbxproj file.
    // When this test or this test and other test failed, You should check target project.pbxproj and it revert if necessary.
    func test_overwrite_check() {
        XCTContext.runActivity(named: "When it is no edit", block: { _ in
            // Overwrite
            let project1 = makeXcodeProject()
            let serializer1 = XcodeProjectSerializer()
            let content1 = serializer1.serialize(project: project1)
            try! project1.write()
            
            let project2 = makeXcodeProject()
            let serializer2 = XcodeProjectSerializer()
            let content2 = serializer2.serialize(project: project2)
            
            XCTAssertEqual(content1, content2)
        })
        XCTContext.runActivity(named: "When it is edited", block: { _ in
            // Resverse
            let projectForResverse = makeXcodeProject()
            
            // Overwrite
            let project1 = makeXcodeProject()
            let serializer1 = XcodeProjectSerializer()
            let content1 = serializer1.serialize(project: project1)
            let maker1 = FileReferenceMakerImpl()
            project1.objects.values.compactMap { $0 as? PBX.Group }.filter { $0.fullPath == "iOSTestProject" }.first!.children.append(maker1.make(context: project1.context, fileName: "aaaa.swift"))
            try! project1.write()
            
            let project2 = makeXcodeProject()
            let serializer2 = XcodeProjectSerializer()
            let content2 = serializer2.serialize(project: project2)
            XCTAssertNotEqual(content1, content2)
            
            XCTContext.runActivity(named: "And reversed", block: { _ in
                let serializer3 = XcodeProjectSerializer()
                let content3 = serializer3.serialize(project: projectForResverse)
                try! projectForResverse.write()
                
                XCTAssertEqual(content1, content3)
                XCTAssertNotEqual(content2, content3)
            })
        })
    }

    func test_edting_xcode_project() {
        XCTContext.runActivity(named: "Append file to iOSTestProject/. It is append same references and added original context `objects`.", block: { _ in
            let project = makeXcodeProject()
            let originalObjects = project.context.objects
            let mockIDGenerator = StringGeneratorMock()
            mockIDGenerator.generateReturnValue = "ABC"
            let maker = FileReferenceMakerImpl(hashIDGenerator: mockIDGenerator)
            let subject: ([String: PBX.Object]) -> Int = {
                $0.values.compactMap { $0 as? PBX.Group }.filter { $0.fullPath == "iOSTestProject" }.first!.children.count
            }
            from: do {
                XCTAssertEqual(subject(originalObjects), subject(project.objects))
                XCTAssertEqual(originalObjects.count, project.context.objects.count)
                XCTAssertEqual(originalObjects.count, project.objects.count)
                XCTAssertFalse(project.fileRefs.map { $0.id }.contains("ABC"))
            }
            project.groups.filter { $0.fullPath == "iOSTestProject" }.first!.children.append(maker.make(context: project.context, fileName: "aaaa.swift"))
            to: do {
                XCTAssertEqual(subject(originalObjects), subject(project.objects))
                XCTAssertEqual(originalObjects.count + 1, project.context.objects.count)
                XCTAssertEqual(originalObjects.count + 1, project.objects.count)
                XCTAssertTrue(project.fileRefs.map { $0.id }.contains("ABC"))
            }
        })
        XCTContext.runActivity(named: "Append buld file to target of iOSTestProject/. It is append same references and added original context `objects`.", block: { _ in
            let project = makeXcodeProject()
            let originalObjects = project.context.objects
            let mockIDGenerator = StringGeneratorMock()
            mockIDGenerator.generateReturnValue = "ABC"
            let maker = BuildFileMakerImpl(hashIDGenerator: mockIDGenerator)
            let subject: ([String: PBX.Object]) -> Int = {
                $0.values.compactMap { $0 as? PBX.Target }.filter { $0.name == "iOSTestProject" }.first!.buildPhases.first!.files.count
            }
            from: do {
                XCTAssertEqual(subject(originalObjects), subject(project.objects))
                XCTAssertEqual(originalObjects.count, project.context.objects.count)
                XCTAssertEqual(originalObjects.count, project.objects.count)
                XCTAssertFalse(project.objects.map { $0.key }.contains("ABC"))
            }
            project.objects.values.compactMap { $0 as? PBX.Target }.filter { $0.name == "iOSTestProject" }.first!.buildPhases.first!.files.append(maker.make(context: project.context, fileRefId: "ABC"))
            to: do {
                XCTAssertEqual(subject(originalObjects), subject(project.objects))
                XCTAssertEqual(originalObjects.count + 1, project.context.objects.count)
                XCTAssertEqual(originalObjects.count + 1, project.objects.count)
                XCTAssertTrue(project.objects.map { $0.key }.contains("ABC"))
            }
        })
    }
    
    func testAppendFilePathToTargetName() {
        XCTContext.runActivity(named: "When append file is not exist", block: { _ in
            XCTContext.runActivity(named: "and directory is not exists", block: { (_) in
                XCTContext.runActivity(named: "when under the Hoge/. Hoge is not exists", block: { _ in
                    let xcodeproject = makeXcodeProject()
                    let originalObjects = xcodeproject.context.objects
                    let originalGroupsCount = xcodeproject.groups.count

                    from: do {
                        XCTAssertEqual(originalObjects.keys.count, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                        XCTAssertEqual(originalGroupsCount, xcodeproject.groups.count)
                    }
                    
                    xcodeproject.appendFile(path: "Hoge/bbbb.swift", targetName: "iOSTestProject")
                    
                    to: do {
                        XCTAssertEqual(originalObjects.keys.count + 3, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count + 1, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count + 1, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count + 1, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                        XCTAssertEqual(originalGroupsCount + 1, xcodeproject.groups.count)
                        XCTAssertEqual(xcodeproject.groups[path: "Hoge"]!.children.count, 1)
                    }
                })
                XCTContext.runActivity(named: "when under the Hoge/Fuga. Hoge and Fuga is not exists", block: { _ in
                    let xcodeproject = makeXcodeProject()
                    let originalObjects = xcodeproject.context.objects
                    
                    from: do {
                        XCTAssertEqual(originalObjects.keys.count, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                    }
                    
                    xcodeproject.appendFile(path: "Hoge/Fuga/aaaa.swift", targetName: "iOSTestProject")
                    
                    to: do {
                        XCTAssertEqual(originalObjects.keys.count + 4, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count + 2, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count + 1, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count + 1, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                    }
                })
            })
            XCTContext.runActivity(named: "and directory is exists", block: { (_) in
                XCTContext.runActivity(named: "when root directory", block: { _ in
                    let xcodeproject = makeXcodeProject()
                    let originalObjects = xcodeproject.context.objects

                    from: do {
                        XCTAssertEqual(originalObjects.keys.count, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                    }
                    
                    xcodeproject.appendFile(path: "aaaa.swift", targetName: "iOSTestProject")
                    
                    to: do {
                        XCTAssertEqual(originalObjects.keys.count + 2, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count + 1, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count + 1, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                    }
                })
                XCTContext.runActivity(named: "when under the iOSTestProject/", block: { _ in
                    let xcodeproject = makeXcodeProject()
                    let originalObjects = xcodeproject.context.objects
                    let originalSubGroups = xcodeproject.groups[path: "iOSTestProject"]!.subGroups

                    from: do {
                        XCTAssertEqual(originalObjects.keys.count, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                        XCTAssertEqual(originalSubGroups.count, xcodeproject.context.groups[path: "iOSTestProject"]!.subGroups.count)
                    }
                    
                    xcodeproject.appendFile(path: "iOSTestProject/aaaa.swift", targetName: "iOSTestProject")
                    
                    to: do {
                        XCTAssertEqual(originalObjects.keys.count + 2, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count + 1, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count + 1, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                        XCTAssertEqual(originalSubGroups.count, xcodeproject.context.groups[path: "iOSTestProject"]!.subGroups.count)
                    }
                })
                XCTContext.runActivity(named: "when under the iOSTestProject/Group", block: { _ in
                    let xcodeproject = makeXcodeProject()
                    let originalObjects = xcodeproject.context.objects
                    
                    from: do {
                        XCTAssertEqual(originalObjects.keys.count, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                    }
                    
                    xcodeproject.appendFile(path: "iOSTestProject/Group/aaaa.swift", targetName: "iOSTestProject")
                    
                    to: do {
                        XCTAssertEqual(originalObjects.keys.count + 2, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count + 1, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count + 1, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                    }
                })
            })
        })
        
        XCTContext.runActivity(named: "When appendFile file is exist", block: { _ in
            XCTContext.runActivity(named: "and directory is exists", block: { _ in
                XCTContext.runActivity(named: "when root directory", block: { _ in
                    let xcodeproject = makeXcodeProject()
                    let originalObjects = xcodeproject.context.objects
                    
                    from: do {
                        XCTAssertEqual(originalObjects.keys.count, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                    }
                    
                    xcodeproject.appendFile(path: "Config.swift", targetName: "iOSTestProject")
                    
                    to: do {
                        XCTAssertEqual(originalObjects.keys.count, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                    }
                })
                XCTContext.runActivity(named: "when under the iOSTestProject/", block: { _ in
                    let xcodeproject = makeXcodeProject()
                    let originalObjects = xcodeproject.context.objects
                    
                    from: do {
                        XCTAssertEqual(originalObjects.keys.count, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                    }
                    
                    xcodeproject.appendFile(path: "iOSTestProject/AppDelegate.swift", targetName: "iOSTestProject")
                    
                    to: do {
                        XCTAssertEqual(originalObjects.keys.count, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                    }
                })
                XCTContext.runActivity(named: "when under the iOSTestProject/Group", block: { _ in
                    let xcodeproject = makeXcodeProject()
                    let originalObjects = xcodeproject.context.objects
                    
                    from: do {
                        XCTAssertEqual(originalObjects.keys.count, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                    }
                    
                    xcodeproject.appendFile(path: "iOSTestProject/Group/FileReference.swift", targetName: "iOSTestProject")
                    
                    to: do {
                        XCTAssertEqual(originalObjects.keys.count, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                    }
                })
            })
        })
        
    }
    func testRemoveFilePathToTargetName() {
        XCTContext.runActivity(named: "When will remove file is exist", block: { _ in
            XCTContext.runActivity(named: "and directory is exists", block: { _ in
                XCTContext.runActivity(named: "when root directory", block: { _ in
                    let xcodeproject = makeXcodeProject()
                    let originalObjects = xcodeproject.context.objects
                    
                    from: do {
                        XCTAssertEqual(originalObjects.keys.count, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                    }
                    
                    xcodeproject.removeFile(path: "Config.swift", targetName: "iOSTestProject")

                    to: do {
                        XCTAssertEqual(originalObjects.keys.count - 2, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count - 1, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count - 1, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                    }
                })
                XCTContext.runActivity(named: "when under the iOSTestProject/", block: { _ in
                    let xcodeproject = makeXcodeProject()
                    let originalObjects = xcodeproject.context.objects
                    
                    from: do {
                        XCTAssertEqual(originalObjects.keys.count, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                    }
                    
                    xcodeproject.removeFile(path: "iOSTestProject/AppDelegate.swift", targetName: "iOSTestProject")

                    to: do {
                        XCTAssertEqual(originalObjects.keys.count - 2, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count - 1, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count - 1, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                    }
                })
                XCTContext.runActivity(named: "when under the iOSTestProject/Group. It will to empty for iOSTestProject/Group. But not remove it.", block: { _ in
                    let xcodeproject = makeXcodeProject()
                    let originalObjects = xcodeproject.context.objects
                    
                    from: do {
                        XCTAssertEqual(originalObjects.keys.count, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                    }

                    xcodeproject.removeFile(path: "iOSTestProject/Group/FileReference.swift", targetName: "iOSTestProject")
                    
                    to: do {
                        XCTAssertEqual(originalObjects.keys.count - 2, xcodeproject.context.objects.keys.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.Group }.count, xcodeproject.context.objects.values.compactMap { $0 as? PBX.Group }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.FileReference }.count - 1, xcodeproject.context.objects.values.compactMap { $0 as? PBX.FileReference }.count)
                        XCTAssertEqual(originalObjects.values.compactMap { $0 as? PBX.BuildFile }.count - 1, xcodeproject.context.objects.values.compactMap { $0 as? PBX.BuildFile }.count)
                    }
                    
                })
            })
        })
        
    }
}
