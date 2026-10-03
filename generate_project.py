#!/usr/bin/env python3
"""Generate Xcode project for FocusWater universal app."""

import os
import sys
import uuid

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
SOURCE_DIR = os.path.join(PROJECT_DIR, "FocusWater")

# All source files relative to SOURCE_DIR
SOURCE_FILES = [
    "FocusWaterApp.swift",
    "Models/FocusSession.swift",
    "Models/FocusSettings.swift",
    "Models/WaterBottle.swift",
    "ViewModels/FocusViewModel.swift",
    "Extensions/AppPreferences.swift",
    "Extensions/Color+Theme.swift",
    "Views/ContentView.swift",
    "Views/DailyGoalSetupSheet.swift",
    "Views/FocusTab/FocusView.swift",
    "Views/FocusTab/BottleCanvas.swift",
    "Views/FocusTab/AddFocusSheet.swift",
    "Views/WarehouseTab/WarehouseView.swift",
    "Views/WarehouseTab/BottleCard.swift",
    "Views/StatsTab/StatsView.swift",
    "Views/StatsTab/WeeklyChart.swift",
    "Views/StatsTab/StreakBadge.swift",
]

RESOURCE_FILES = [
    "Resources/Assets.xcassets",
    "Resources/PrivacyInfo.xcprivacy",
]

# Referenced by the pbxproj with group path relative to SOURCE_DIR
GROUPS = {
    "": [  # root group
        ("FocusWaterApp.swift", "FocusWaterApp.swift"),
        ("Models", "Models"),
        ("ViewModels", "ViewModels"),
        ("Extensions", "Extensions"),
        ("Views", "Views"),
        ("Resources", "Resources"),
    ],
    "Models": [
        ("FocusSession.swift", "Models/FocusSession.swift"),
        ("FocusSettings.swift", "Models/FocusSettings.swift"),
        ("WaterBottle.swift", "Models/WaterBottle.swift"),
    ],
    "ViewModels": [
        ("FocusViewModel.swift", "ViewModels/FocusViewModel.swift"),
    ],
    "Extensions": [
        ("AppPreferences.swift", "Extensions/AppPreferences.swift"),
        ("Color+Theme.swift", "Extensions/Color+Theme.swift"),
    ],
    "Views": [
        ("ContentView.swift", "Views/ContentView.swift"),
        ("DailyGoalSetupSheet.swift", "Views/DailyGoalSetupSheet.swift"),
        ("FocusTab", "Views/FocusTab"),
        ("WarehouseTab", "Views/WarehouseTab"),
        ("StatsTab", "Views/StatsTab"),
    ],
    "FocusTab": [
        ("FocusView.swift", "Views/FocusTab/FocusView.swift"),
        ("BottleCanvas.swift", "Views/FocusTab/BottleCanvas.swift"),
        ("AddFocusSheet.swift", "Views/FocusTab/AddFocusSheet.swift"),
    ],
    "WarehouseTab": [
        ("WarehouseView.swift", "Views/WarehouseTab/WarehouseView.swift"),
        ("BottleCard.swift", "Views/WarehouseTab/BottleCard.swift"),
    ],
    "StatsTab": [
        ("StatsView.swift", "Views/StatsTab/StatsView.swift"),
        ("WeeklyChart.swift", "Views/StatsTab/WeeklyChart.swift"),
        ("StreakBadge.swift", "Views/StatsTab/StreakBadge.swift"),
    ],
    "Resources": [
        ("Assets.xcassets", "Resources/Assets.xcassets"),
        ("PrivacyInfo.xcprivacy", "Resources/PrivacyInfo.xcprivacy"),
    ],
}


def gen_uuid():
    # Xcode uses 24-char hex UUIDs
    return uuid.uuid4().hex[:24].upper()


def main():
    if "--force" not in sys.argv:
        raise SystemExit(
            "This legacy generator does not preserve the current test target and signing settings. "
            "Edit FocusWater.xcodeproj directly, or rerun with --force only if you intentionally "
            "want to replace the project structure."
        )

    uuids = {}

    def uid(key):
        if key not in uuids:
            uuids[key] = gen_uuid()
        return uuids[key]

    # Pre-generate all needed UUIDs
    for f in SOURCE_FILES:
        name = os.path.basename(f)
        uid(f"fileRef_{name}")
        uid(f"buildFile_{name}")
    for f in RESOURCE_FILES:
        name = os.path.basename(f)
        uid(f"fileRef_{name}")
        uid(f"buildFile_{name}")

    uid("srcGroup")
    uid("prodGroup")
    uid("mainGroup")
    uid("target")
    uid("project")
    uid("buildConfigList_target")
    uid("buildConfigList_project")
    uid("buildConfig_debug_target")
    uid("buildConfig_release_target")
    uid("buildConfig_debug_project")
    uid("buildConfig_release_project")
    uid("sourcesPhase")
    uid("resourcesPhase")
    uid("frameworksPhase")
    uid("productRef")

    # Build the pbxproj content
    lines = []
    lines.append("// !$*UTF8*$!")
    lines.append("{")
    lines.append('\tarchiveVersion = 1;')
    lines.append('\tclasses = {')
    lines.append('\t};')
    lines.append('\tobjectVersion = 77;')
    lines.append('\tobjects = {')
    lines.append('')

    # ---- PBXBuildFile section ----
    lines.append("/* Begin PBXBuildFile section */")
    for f in SOURCE_FILES:
        name = os.path.basename(f)
        ref = uid(f"fileRef_{name}")
        bf = uid(f"buildFile_{name}")
        lines.append(f"\t\t{bf} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};")
    for f in RESOURCE_FILES:
        name = os.path.basename(f)
        ref = uid(f"fileRef_{name}")
        bf = uid(f"buildFile_{name}")
        lines.append(f"\t\t{bf} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};")
    lines.append("/* End PBXBuildFile section */")
    lines.append('')

    # ---- PBXFileReference section ----
    lines.append("/* Begin PBXFileReference section */")
    for f in SOURCE_FILES:
        name = os.path.basename(f)
        ref = uid(f"fileRef_{name}")
        lines.append(f'\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{name}"; sourceTree = "<group>"; }};')
    for f in RESOURCE_FILES:
        name = os.path.basename(f)
        ref = uid(f"fileRef_{name}")
        if name.endswith(".xcassets"):
            file_type = "folder.assetcatalog"
        else:
            file_type = "text.plist.xml"
        lines.append(f'\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {file_type}; path = "{name}"; sourceTree = "<group>"; }};')
    # Product reference as PBXFileReference (Xcode 16 no longer supports PBXProductReference)
    pref = uid("productRef")
    lines.append(f'\t\t{pref} /* FocusWater.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "FocusWater.app"; sourceTree = BUILT_PRODUCTS_DIR; }};')
    lines.append("/* End PBXFileReference section */")
    lines.append('')

    # ---- PBXFrameworksBuildPhase ----
    lines.append("/* Begin PBXFrameworksBuildPhase section */")
    fw = uid("frameworksPhase")
    lines.append(f"\t\t{fw} /* Frameworks */ = {{")
    lines.append(f"\t\t\tisa = PBXFrameworksBuildPhase;")
    lines.append(f"\t\t\tbuildActionMask = 2147483647;")
    lines.append(f"\t\t\tfiles = (")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append(f"\t\t}};")
    lines.append("/* End PBXFrameworksBuildPhase section */")
    lines.append('')

    # ---- PBXGroup section ----
    lines.append("/* Begin PBXGroup section */")

    def write_group(group_name, group_path, entries, indent_level=2):
        indent = '\t' * indent_level
        gid = uid(f"group_{group_name}" if group_name else "mainGroup")
        path_line = f'name = "{group_name}";' if group_name != "" else ""
        if group_path:
            path_line = f'path = "{group_path}"; sourceTree = "<group>";'
        else:
            path_line += f' sourceTree = "<group>";'

        lines.append(f"{indent}{gid} = {{")
        lines.append(f"{indent}\tisa = PBXGroup;")
        lines.append(f"{indent}\tchildren = (")
        for entry_name, entry_path in entries:
            if entry_name.endswith(".swift"):
                ref = uid(f"fileRef_{entry_name}")
                lines.append(f"{indent}\t\t{ref} /* {entry_name} */,")
            else:
                sub_gid = uid(f"group_{entry_name}")
                lines.append(f"{indent}\t\t{sub_gid} /* {entry_name} */,")
        lines.append(f"{indent}\t);")
        if group_name:
            lines.append(f'{indent}\tname = "{group_name}";')
        lines.append(f"{indent}\t{path_line}")
        lines.append(f"{indent}}};")

    # Main group (source root)
    write_group("", "FocusWater", GROUPS[""])
    # Subgroups
    for group_name in ["Models", "ViewModels", "Extensions", "Views", "Resources", "FocusTab", "WarehouseTab", "StatsTab"]:
        write_group(group_name, group_name, GROUPS[group_name])

    # Products group
    prod_gid = uid("prodGroup")
    lines.append(f"\t\t{prod_gid} /* Products */ = {{")
    lines.append(f"\t\t\tisa = PBXGroup;")
    lines.append(f"\t\t\tchildren = (")
    lines.append(f"\t\t\t\t{uid('productRef')} /* FocusWater.app */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tname = Products;")
    lines.append(f"\t\t\tsourceTree = \"<group>\";")
    lines.append(f"\t\t}};")

    lines.append("/* End PBXGroup section */")
    lines.append('')

    # ---- PBXNativeTarget ----
    lines.append("/* Begin PBXNativeTarget section */")
    tid = uid("target")
    lines.append(f"\t\t{tid} /* FocusWater */ = {{")
    lines.append(f"\t\t\tisa = PBXNativeTarget;")
    lines.append(f"\t\t\tbuildConfigurationList = {uid('buildConfigList_target')} /* Build configuration list for PBXNativeTarget \"FocusWater\" */;")
    lines.append(f"\t\t\tbuildPhases = (")
    lines.append(f"\t\t\t\t{uid('sourcesPhase')} /* Sources */,")
    lines.append(f"\t\t\t\t{uid('resourcesPhase')} /* Resources */,")
    lines.append(f"\t\t\t\t{uid('frameworksPhase')} /* Frameworks */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tbuildRules = (")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tdependencies = (")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tname = FocusWater;")
    lines.append(f"\t\t\tproductName = FocusWater;")
    lines.append(f"\t\t\tproductReference = {uid('productRef')} /* FocusWater.app */;")
    lines.append(f"\t\t\tproductType = \"com.apple.product-type.application\";")
    lines.append(f"\t\t}};")
    lines.append("/* End PBXNativeTarget section */")
    lines.append('')

    # ---- PBXProject ----
    lines.append("/* Begin PBXProject section */")
    pid = uid("project")
    lines.append(f"\t\t{pid} /* Project object */ = {{")
    lines.append(f"\t\t\tisa = PBXProject;")
    lines.append(f"\t\t\tattributes = {{")
    lines.append(f"\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    lines.append(f"\t\t\t\tLastSwiftUpdateCheck = 1600;")
    lines.append(f"\t\t\t\tLastUpgradeCheck = 1600;")
    lines.append(f"\t\t\t}};")
    lines.append(f"\t\t\tbuildConfigurationList = {uid('buildConfigList_project')} /* Build configuration list */;")
    lines.append(f"\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    lines.append(f"\t\t\tdevelopmentRegion = en;")
    lines.append(f"\t\t\thasScannedForEncodings = 0;")
    lines.append(f"\t\t\tknownRegions = (en, Base, \"zh-Hans\");")
    lines.append(f"\t\t\tmainGroup = {uid('mainGroup')};")
    lines.append(f"\t\t\tproductRefGroup = {uid('prodGroup')};")
    lines.append(f"\t\t\tprojectDirPath = \"\";")
    lines.append(f"\t\t\tprojectRoot = \"\";")
    lines.append(f"\t\t\ttargets = (")
    lines.append(f"\t\t\t\t{tid} /* FocusWater */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t}};")
    lines.append("/* End PBXProject section */")
    lines.append('')

    # ---- PBXSourcesBuildPhase ----
    lines.append("/* Begin PBXSourcesBuildPhase section */")
    sp = uid("sourcesPhase")
    lines.append(f"\t\t{sp} /* Sources */ = {{")
    lines.append(f"\t\t\tisa = PBXSourcesBuildPhase;")
    lines.append(f"\t\t\tbuildActionMask = 2147483647;")
    lines.append(f"\t\t\tfiles = (")
    for f in SOURCE_FILES:
        name = os.path.basename(f)
        bf = uid(f"buildFile_{name}")
        lines.append(f"\t\t\t\t{bf} /* {name} in Sources */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append(f"\t\t}};")
    lines.append("/* End PBXSourcesBuildPhase section */")
    lines.append('')

    # ---- PBXResourcesBuildPhase ----
    lines.append("/* Begin PBXResourcesBuildPhase section */")
    rp = uid("resourcesPhase")
    lines.append(f"\t\t{rp} /* Resources */ = {{")
    lines.append(f"\t\t\tisa = PBXResourcesBuildPhase;")
    lines.append(f"\t\t\tbuildActionMask = 2147483647;")
    lines.append(f"\t\t\tfiles = (")
    for f in RESOURCE_FILES:
        name = os.path.basename(f)
        bf = uid(f"buildFile_{name}")
        lines.append(f"\t\t\t\t{bf} /* {name} in Resources */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append(f"\t\t}};")
    lines.append("/* End PBXResourcesBuildPhase section */")
    lines.append('')

    # ---- XCBuildConfiguration ----
    lines.append("/* Begin XCBuildConfiguration section */")

    # Target configs
    for (suffix, config_name, swift_version) in [
        ("debug_target", "Debug", "5.0"),
        ("release_target", "Release", "5.0"),
    ]:
        cid = uid(f"buildConfig_{suffix}")
        lines.append(f"\t\t{cid} /* {config_name} */ = {{")
        lines.append(f"\t\t\tisa = XCBuildConfiguration;")
        lines.append(f"\t\t\tbuildSettings = {{")
        lines.append(f"\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
        lines.append(f"\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        lines.append(f"\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        lines.append(f"\t\t\t\tENABLE_PREVIEWS = YES;")
        lines.append(f"\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
        lines.append(f"\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = \"\";")
        lines.append(f"\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
        lines.append(f"\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (\"$(inherited)\", \"@executable_path/../Frameworks\");")
        lines.append(f"\t\t\t\tMARKETING_VERSION = 1.0;")
        lines.append(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.hanzibo.FocusWater;")
        lines.append(f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
        lines.append(f"\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator macosx\";")
        lines.append(f"\t\t\t\tSUPPORTS_MACCATALYST = YES;")
        lines.append(f"\t\t\t\tSWIFT_VERSION = {swift_version};")
        lines.append(f"\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
        if config_name == "Release":
            lines.append(f"\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
        lines.append(f"\t\t\t}};")
        lines.append(f"\t\t\tname = {config_name};")
        lines.append(f"\t\t}};")

    # Project configs
    for (suffix, config_name) in [
        ("debug_project", "Debug"),
        ("release_project", "Release"),
    ]:
        cid = uid(f"buildConfig_{suffix}")
        lines.append(f"\t\t{cid} /* {config_name} */ = {{")
        lines.append(f"\t\t\tisa = XCBuildConfiguration;")
        lines.append(f"\t\t\tbuildSettings = {{")
        lines.append(f"\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
        lines.append(f"\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
        lines.append(f"\t\t\t\tCOPY_PHASE_STRIP = NO;")
        lines.append(f"\t\t\t\tDEBUG_INFORMATION_FORMAT = \"{'dwarf' if config_name == 'Debug' else 'dwarf-with-dsym'}\";")
        lines.append(f"\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
        lines.append(f"\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;")
        lines.append(f"\t\t\t\tGCC_OPTIMIZATION_LEVEL = {'0' if config_name == 'Debug' else 's'};")
        lines.append(f"\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
        lines.append(f"\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;")
        lines.append(f"\t\t\t\tMTL_ENABLE_DEBUG_INFO = {'INCLUDE_SOURCE' if config_name == 'Debug' else 'NO'};")
        lines.append(f"\t\t\t\tONLY_ACTIVE_ARCH = {'YES' if config_name == 'Debug' else 'NO'};")
        lines.append(f"\t\t\t\tSDKROOT = auto;")
        lines.append(f"\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator macosx\";")
        lines.append(f"\t\t\t\tSUPPORTS_MACCATALYST = YES;")
        lines.append(f"\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
        if config_name == "Debug":
            lines.append(f'\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG";')
        lines.append(f"\t\t\t}};")
        lines.append(f"\t\t\tname = {config_name};")
        lines.append(f"\t\t}};")

    lines.append("/* End XCBuildConfiguration section */")
    lines.append('')

    # ---- XCConfigurationList ----
    lines.append("/* Begin XCConfigurationList section */")
    for (suffix, kind) in [("target", "PBXNativeTarget"), ("project", "PBXProject")]:
        cid = uid(f"buildConfigList_{suffix}")
        dc = uid(f"buildConfig_debug_{suffix}")
        rc = uid(f"buildConfig_release_{suffix}")
        lines.append(f"\t\t{cid} /* Build configuration list */ = {{")
        lines.append(f"\t\t\tisa = XCConfigurationList;")
        lines.append(f"\t\t\tbuildConfigurations = (")
        lines.append(f"\t\t\t\t{dc} /* Debug */,")
        lines.append(f"\t\t\t\t{rc} /* Release */,")
        lines.append(f"\t\t\t);")
        lines.append(f"\t\t\tdefaultConfigurationIsVisible = 0;")
        lines.append(f"\t\t\tdefaultConfigurationName = Release;")
        lines.append(f"\t\t}};")
    lines.append("/* End XCConfigurationList section */")
    lines.append('')

    lines.append('\t};')
    lines.append(f'\trootObject = {uid("project")} /* Project object */;')
    lines.append('}')

    # Write the pbxproj
    pbxproj_dir = os.path.join(PROJECT_DIR, "FocusWater.xcodeproj")
    os.makedirs(pbxproj_dir, exist_ok=True)
    pbxproj_path = os.path.join(pbxproj_dir, "project.pbxproj")
    with open(pbxproj_path, 'w') as f:
        f.write('\n'.join(lines))

    # Write the xcscheme with the correct target UUID
    scheme_dir = os.path.join(pbxproj_dir, "xcshareddata", "xcschemes")
    os.makedirs(scheme_dir, exist_ok=True)
    scheme_path = os.path.join(scheme_dir, "FocusWater.xcscheme")

    target_id = uid("target")
    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
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
               BlueprintIdentifier = "{target_id}"
               BuildableName = "FocusWater.app"
               BlueprintName = "FocusWater"
               ReferencedContainer = "container:FocusWater.xcodeproj">
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
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "FocusWater.app"
            BlueprintName = "FocusWater"
            ReferencedContainer = "container:FocusWater.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "FocusWater.app"
            BlueprintName = "FocusWater"
            ReferencedContainer = "container:FocusWater.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
'''
    with open(scheme_path, 'w') as f:
        f.write(scheme)

    print(f"Generated: {pbxproj_path}")
    print(f"Generated: {scheme_path}")
    print(f"Source files: {len(SOURCE_FILES)}")


if __name__ == "__main__":
    main()
