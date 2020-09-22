import func Utility.exec
import Foundation
import XcodeProj
import PathKit

func fatal() -> Never {
    fputs("error: invalid usage\n", stderr)
    exit(1)
}

guard CommandLine.arguments.count == 3 else { fatal() }
let srcfile = Path(CommandLine.arguments[1])
let srcroot = Path(CommandLine.arguments[2])
guard srcfile.isAbsolute, srcroot.isAbsolute else { fatal() }

let name = srcfile.lastComponentWithoutExtension

let debug = XCBuildConfiguration(name: "Debug", buildSettings: [
    "FRAMEWORK_SEARCH_PATHS": ".build/debug",
    "HEADER_SEARCH_PATHS": ".build/debug",
    "LIBRARY_SEARCH_PATHS": ".build/debug",
    "SWIFT_INCLUDE_PATHS": ".build/debug",
    "SWIFT_VERSION": "4.2",  //FIXME
])
let confs = XCConfigurationList(buildConfigurations: [debug], defaultConfigurationName: "Debug")

let mainGroup = PBXGroup(sourceTree: .sourceRoot, path: "")
let rootObject = PBXProject(
    name: name,
    buildConfigurationList: confs,
    compatibilityVersion: "Xcode 9.3",
    mainGroup: mainGroup
)

// The object version seems to indicate the model version used to encode the PBXProj file. Setting this value too
// high could yield a project file that is not editable in any production version of Xcode (i.e. Xcode 12 == 54).
let objectVersion: UInt = 51

let pbxProj = PBXProj(rootObject: rootObject, objectVersion: objectVersion)

let proj = XcodeProj(workspace: XCWorkspace(), pbxproj: pbxProj)

pbxProj.add(object: rootObject)
pbxProj.add(object: confs)
pbxProj.add(object: debug)
pbxProj.add(object: mainGroup)

let srcfileElement = try mainGroup.addFile(at: srcfile, sourceRoot: srcroot)
srcfileElement.explicitFileType = "sourcecode.swift"

let xcodeprojPath = srcroot + "\(name).xcodeproj"

do {
    let buildTarget = PBXAggregateTarget(name: name)
    let phase = PBXShellScriptBuildPhase()
    phase.shellScript = """
        cd $PROJECT_DIR
        swift build
        """
    pbxProj.add(object: buildTarget)
    pbxProj.add(object: phase)

    buildTarget.buildPhases.append(phase)

    rootObject.targets.append(buildTarget)

    let path = xcodeprojPath + "xcshareddata/xcschemes"
    try path.mkpath()

    // can't use xcodeproj module as it doesn’t support PathRunnable
    try """
        <?xml version="1.0" encoding="UTF-8"?>
        <Scheme
           LastUpgradeVersion = "1020"
           version = "1.3">
           <BuildAction
              parallelizeBuildables = "YES"
              buildImplicitDependencies = "YES">
              <BuildActionEntries>
                 <BuildActionEntry
                    buildForTesting = "YES"
                    buildForRunning = "YES"
                    buildForProfiling = "YES"
                    buildForArchiving = "YES"
                    buildForAnalyzing = "YES">
                    <BuildableReference
                       BuildableIdentifier = "primary"
                       BlueprintIdentifier = "4D6E39AAF01F4E0AFBCF529A9D08E79C"
                       BuildableName = "\(name)"
                       BlueprintName = "\(name)"
                       ReferencedContainer = "container:\(name).xcodeproj">
                    </BuildableReference>
                 </BuildActionEntry>
              </BuildActionEntries>
           </BuildAction>
           <TestAction
              buildConfiguration = "Debug"
              selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
              selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
              shouldUseLaunchSchemeArgsEnv = "YES">
              <Testables>
              </Testables>
              <AdditionalOptions>
              </AdditionalOptions>
           </TestAction>
           <LaunchAction
              buildConfiguration = "Debug"
              selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
              selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
              launchStyle = "0"
              useCustomWorkingDirectory = "NO"
              ignoresPersistentStateOnLaunch = "NO"
              debugDocumentVersioning = "YES"
              debugServiceExtension = "internal"
              allowLocationSimulation = "YES">
              <PathRunnable
                  runnableDebuggingMode = "0"
                  FilePath = "\(srcroot)/.build/debug/\(name)">
              </PathRunnable>
              <MacroExpansion>
                 <BuildableReference
                    BuildableIdentifier = "primary"
                    BlueprintIdentifier = "4D6E39AAF01F4E0AFBCF529A9D08E79C"
                    BuildableName = "\(name)"
                    BlueprintName = "\(name)"
                    ReferencedContainer = "container:\(name).xcodeproj">
                 </BuildableReference>
              </MacroExpansion>
              <AdditionalOptions>
              </AdditionalOptions>
           </LaunchAction>
           <ProfileAction
              buildConfiguration = "Debug"
              shouldUseLaunchSchemeArgsEnv = "YES"
              savedToolIdentifier = ""
              useCustomWorkingDirectory = "NO"
              debugDocumentVersioning = "YES">
              <MacroExpansion>
                 <BuildableReference
                    BuildableIdentifier = "primary"
                    BlueprintIdentifier = "4D6E39AAF01F4E0AFBCF529A9D08E79C"
                    BuildableName = "\(name)"
                    BlueprintName = "\(name)"
                    ReferencedContainer = "container:\(name).xcodeproj">
                 </BuildableReference>
              </MacroExpansion>
           </ProfileAction>
           <AnalyzeAction
              buildConfiguration = "Debug">
           </AnalyzeAction>
           <ArchiveAction
              buildConfiguration = "Debug"
              revealArchiveInOrganizer = "YES">
           </ArchiveAction>
        </Scheme>
        """.write(toFile: (path + "\(name).xcscheme").string, atomically: true, encoding: .utf8)
}

do {
    let completionTarget = PBXNativeTarget(name: "\(name)-completion", productType: .commandLineTool)
    let phase = PBXSourcesBuildPhase()

    pbxProj.add(object: completionTarget)
    pbxProj.add(object: phase)

    completionTarget.buildPhases.append(phase)
    _ = try phase.add(file: srcfileElement)

    rootObject.targets.append(completionTarget)
}

try proj.write(path: xcodeprojPath)

try exec(arg0: "/usr/bin/open", args: [xcodeprojPath.string])
