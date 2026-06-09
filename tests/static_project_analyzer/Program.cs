using GodotDotnetMcp.Companion;
using GodotDotnetMcp.Companion.StaticAnalysis;

var tests = new (string Name, Action Run)[]
{
    ("reports_static_inventory_for_godot_dotnet_project", ReportsStaticInventoryForGodotDotnetProject),
    ("reports_static_dotnet_workspace_graph", ReportsStaticDotnetWorkspaceGraph),
    ("keeps_project_references_inside_project_boundary", KeepsProjectReferencesInsideProjectBoundary),
    ("reports_malformed_dotnet_projects_as_diagnostics", ReportsMalformedDotnetProjectsAsDiagnostics),
    ("does_not_claim_dotnet_workspace_when_every_project_is_malformed", DoesNotClaimDotnetWorkspaceWhenEveryProjectIsMalformed),
    ("skips_incomplete_reference_items_as_diagnostics", SkipsIncompleteReferenceItemsAsDiagnostics),
    ("reports_static_resource_reference_graph", ReportsStaticResourceReferenceGraph),
    ("resolves_forward_resource_declarations", ResolvesForwardResourceDeclarations),
    ("reports_missing_and_unsupported_resource_references", ReportsMissingAndUnsupportedResourceReferences),
    ("keeps_resource_references_inside_project_boundary", KeepsResourceReferencesInsideProjectBoundary),
    ("skips_dot_directories_while_scanning_project_files", SkipsDotDirectoriesWhileScanningProjectFiles),
    ("skips_hidden_and_system_directories_while_scanning_project_files", SkipsHiddenAndSystemDirectoriesWhileScanningProjectFiles),
    ("skips_reparse_point_directories_while_scanning_project_files", SkipsReparsePointDirectoriesWhileScanningProjectFiles),
    ("allows_project_roots_under_parent_dot_directories", AllowsProjectRootsUnderParentDotDirectories),
    ("keeps_live_editor_capabilities_unavailable_headlessly", KeepsLiveEditorCapabilitiesUnavailableHeadlessly),
    ("reports_missing_dotnet_workspace_without_claiming_live_state", ReportsMissingDotnetWorkspaceWithoutClaimingLiveState),
    ("does_not_register_non_godot_directories_as_projects", DoesNotRegisterNonGodotDirectoriesAsProjects),
};

foreach (var test in tests)
{
    try
    {
        test.Run();
        Console.WriteLine($"PASS {test.Name}");
    }
    catch (OperationCanceledException exception)
    {
        Console.WriteLine($"SKIP {test.Name}: {exception.Message}");
    }
}

return 0;

static void ReportsStaticInventoryForGodotDotnetProject()
{
    var root = CreateTempProjectRoot();
    var csprojPath = Path.Combine(root, "Game.csproj");
    File.WriteAllText(csprojPath, "<Project />");
    Directory.CreateDirectory(Path.Combine(root, "addons", "godot_dotnet_mcp"));

    var inventory = new ProjectInventoryAnalyzer().Analyze(root);

    AssertTrue(inventory.IsGodotProject);
    AssertTrue(inventory.ProjectId?.StartsWith("project_", StringComparison.Ordinal) == true);
    AssertEqual(CompanionMode.StaticHeadless, inventory.Mode);
    AssertTrue(inventory.HasPluginDirectory);
    AssertEqual(1, inventory.CSharpProjectFiles.Count);
    AssertEqual(Path.GetFullPath(csprojPath), inventory.CSharpProjectFiles[0]);
    AssertTrue(inventory.DotnetWorkspace.HasProjects);
    AssertFalse(inventory.DotnetWorkspace.HasDiagnostics);
    AssertFalse(inventory.ResourceReferences.HasResources);
    AssertTrue(inventory.HasCapability(CompanionCapability.StaticProjectAnalysis));
    AssertTrue(inventory.HasCapability(CompanionCapability.DotnetWorkspaceAnalysis));
    AssertTrue(inventory.HasCapability(CompanionCapability.ResourceGraphAnalysis));
}

static void ReportsStaticDotnetWorkspaceGraph()
{
    var root = CreateTempProjectRoot();
    var libraryDir = Path.Combine(root, "src", "Library");
    Directory.CreateDirectory(libraryDir);
    var libraryProject = Path.Combine(libraryDir, "Library.csproj");
    File.WriteAllText(libraryProject, """
        <Project Sdk="Microsoft.NET.Sdk">
          <PropertyGroup>
            <TargetFrameworks>net8.0;net9.0</TargetFrameworks>
          </PropertyGroup>
          <ItemGroup Condition="'$(Configuration)' == 'Debug'">
            <PackageReference Include="Godot.NET.Sdk" Version="4.6.0" />
            <PackageReference Include="Example.Package">
              <Version>1.2.3</Version>
            </PackageReference>
            <Compile Include="Scripts/**/*.cs" />
            <Compile Remove="Generated/**/*.cs" />
          </ItemGroup>
        </Project>
        """);

    var inventory = new ProjectInventoryAnalyzer().Analyze(root);
    var project = inventory.DotnetWorkspace.Projects.Single();

    AssertEqual(Path.GetFullPath(libraryProject), project.ProjectFilePath);
    AssertEqual("Microsoft.NET.Sdk", project.Sdk);
    AssertEqual(2, project.TargetFrameworks.Count);
    AssertEqual("net8.0", project.TargetFrameworks[0]);
    AssertEqual("net9.0", project.TargetFrameworks[1]);
    AssertTrue(project.IsGodotSdkStyleProject);
    AssertEqual(2, project.PackageReferences.Count);
    AssertEqual("Godot.NET.Sdk", project.PackageReferences[0].Include);
    AssertEqual("4.6.0", project.PackageReferences[0].Version);
    AssertContains("Configuration", project.PackageReferences[0].Condition ?? string.Empty);
    AssertEqual("Example.Package", project.PackageReferences[1].Include);
    AssertEqual("1.2.3", project.PackageReferences[1].Version);
    AssertEqual(2, project.CompileItems.Count);
    AssertEqual("Scripts/**/*.cs", project.CompileItems[0].Include);
    AssertEqual("Generated/**/*.cs", project.CompileItems[1].Remove);
}

static void KeepsProjectReferencesInsideProjectBoundary()
{
    var root = CreateTempProjectRoot();
    var appProject = Path.Combine(root, "App.csproj");
    var libraryProject = Path.Combine(root, "Library", "Library.csproj");
    Directory.CreateDirectory(Path.GetDirectoryName(libraryProject)!);
    File.WriteAllText(libraryProject, "<Project Sdk=\"Microsoft.NET.Sdk\" />");
    var outsideProject = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N") + ".csproj");
    File.WriteAllText(outsideProject, "<Project />");
    File.WriteAllText(appProject, $"""
        <Project Sdk="Microsoft.NET.Sdk">
          <ItemGroup>
            <ProjectReference Include="Library/Library.csproj" />
            <ProjectReference Include="{outsideProject}" />
          </ItemGroup>
        </Project>
        """);

    var inventory = new ProjectInventoryAnalyzer().Analyze(root);
    var app = inventory.DotnetWorkspace.Projects.Single(project => project.ProjectFilePath == Path.GetFullPath(appProject));

    AssertEqual(2, app.ProjectReferences.Count);
    AssertTrue(app.ProjectReferences[0].IsInsideProjectRoot);
    AssertTrue(app.ProjectReferences[0].Exists);
    AssertFalse(app.ProjectReferences[1].IsInsideProjectRoot);
    AssertFalse(app.ProjectReferences[1].Exists);
    AssertTrue(inventory.DotnetWorkspace.Diagnostics.Any(diagnostic => diagnostic.Code == "dotnet_workspace_project_reference_outside_root"));
}

static void ReportsMalformedDotnetProjectsAsDiagnostics()
{
    var root = CreateTempProjectRoot();
    var goodProject = Path.Combine(root, "Good.csproj");
    var malformedProject = Path.Combine(root, "Broken.csproj");
    File.WriteAllText(goodProject, "<Project Sdk=\"Microsoft.NET.Sdk\" />");
    File.WriteAllText(malformedProject, "<Project>");

    var inventory = new ProjectInventoryAnalyzer().Analyze(root);

    AssertEqual(1, inventory.DotnetWorkspace.Projects.Count);
    AssertEqual(Path.GetFullPath(goodProject), inventory.DotnetWorkspace.Projects[0].ProjectFilePath);
    AssertEqual(1, inventory.DotnetWorkspace.Diagnostics.Count);
    AssertEqual(Path.GetFullPath(malformedProject), inventory.DotnetWorkspace.Diagnostics[0].ProjectFilePath);
    AssertEqual(DotnetWorkspaceDiagnosticSeverity.Error, inventory.DotnetWorkspace.Diagnostics[0].Severity);
    AssertEqual("dotnet_workspace_project_unreadable", inventory.DotnetWorkspace.Diagnostics[0].Code);
}

static void DoesNotClaimDotnetWorkspaceWhenEveryProjectIsMalformed()
{
    var root = CreateTempProjectRoot();
    File.WriteAllText(Path.Combine(root, "Broken.csproj"), "<Project>");

    var inventory = new ProjectInventoryAnalyzer().Analyze(root);

    AssertFalse(inventory.DotnetWorkspace.HasProjects);
    AssertTrue(inventory.DotnetWorkspace.HasDiagnostics);
    AssertFalse(inventory.HasCapability(CompanionCapability.DotnetWorkspaceAnalysis));
    AssertContains("No .csproj file could be parsed successfully", inventory.GetCapability(CompanionCapability.DotnetWorkspaceAnalysis).Reason);
}

static void SkipsIncompleteReferenceItemsAsDiagnostics()
{
    var root = CreateTempProjectRoot();
    var project = Path.Combine(root, "Game.csproj");
    File.WriteAllText(project, """
        <Project Sdk="Microsoft.NET.Sdk">
          <ItemGroup>
            <PackageReference Version="1.0.0" />
            <ProjectReference Include=" " />
          </ItemGroup>
        </Project>
        """);

    var inventory = new ProjectInventoryAnalyzer().Analyze(root);
    var graph = inventory.DotnetWorkspace.Projects.Single();

    AssertEqual(0, graph.PackageReferences.Count);
    AssertEqual(0, graph.ProjectReferences.Count);
    AssertEqual(2, inventory.DotnetWorkspace.Diagnostics.Count);
    AssertTrue(inventory.DotnetWorkspace.Diagnostics.Any(diagnostic => diagnostic.Code == "dotnet_workspace_package_reference_missing_include"));
    AssertTrue(inventory.DotnetWorkspace.Diagnostics.Any(diagnostic => diagnostic.Code == "dotnet_workspace_project_reference_missing_include"));
}

static void ReportsStaticResourceReferenceGraph()
{
    var root = CreateTempProjectRoot();
    Directory.CreateDirectory(Path.Combine(root, "scenes"));
    Directory.CreateDirectory(Path.Combine(root, "scripts"));
    Directory.CreateDirectory(Path.Combine(root, "resources"));
    var scenePath = Path.Combine(root, "scenes", "Main.tscn");
    var scriptPath = Path.Combine(root, "scripts", "Player.cs");
    var resourcePath = Path.Combine(root, "resources", "Config.tres");
    File.WriteAllText(scriptPath, string.Empty);
    File.WriteAllText(resourcePath, """
        [gd_resource type="Resource" format=3 uid="uid://config123"]

        [resource]
        value = 1
        """);
    File.WriteAllText(scenePath, """
        [gd_scene load_steps=3 format=3 uid="uid://main123"]

        [ext_resource type="Script" path="res://scripts/Player.cs" id="1_player"]
        [ext_resource type="Resource" uid="uid://config123" path="res://resources/Config.tres" id="2_config"]

        [sub_resource type="Animation" id="Animation_idle"]

        [node name="Main" type="Node"]
        script = ExtResource("1_player")
        config = ExtResource("2_config")
        animation = SubResource("Animation_idle")
        """);

    var inventory = new ProjectInventoryAnalyzer().Analyze(root);
    var graph = inventory.ResourceReferences;

    AssertTrue(graph.HasResources);
    AssertEqual(2, graph.Files.Count);
    AssertEqual(2, graph.ExternalResources.Count);
    AssertEqual(1, graph.SubResources.Count);
    AssertEqual(6, graph.ReferenceUsages.Count);
    AssertTrue(graph.ReferenceUsages.Any(reference => reference.Kind == ResourceReferenceUsageKind.ExtResource && reference.Reference == "1_player" && reference.Exists));
    AssertTrue(graph.ReferenceUsages.Any(reference => reference.Kind == ResourceReferenceUsageKind.SubResource && reference.Reference == "Animation_idle" && reference.Exists));
    AssertTrue(graph.ReferenceUsages.Any(reference => reference.Kind == ResourceReferenceUsageKind.Uid && reference.Reference == "uid://main123"));
    AssertTrue(graph.ReferenceUsages.Any(reference => reference.Kind == ResourceReferenceUsageKind.Uid && reference.Reference == "uid://config123"));
    AssertFalse(graph.HasDiagnostics);
}

static void ResolvesForwardResourceDeclarations()
{
    var root = CreateTempProjectRoot();
    var scenePath = Path.Combine(root, "Forward.tscn");
    var scriptPath = Path.Combine(root, "Forward.cs");
    File.WriteAllText(scriptPath, string.Empty);
    File.WriteAllText(scenePath, """
        [gd_scene load_steps=2 format=3]

        [node name="Forward" type="Node"]
        script = ExtResource("ForwardScript")
        child = SubResource("ForwardSub")

        [ext_resource type="Script" path="res://Forward.cs" id="ForwardScript"]
        [sub_resource type="Resource" id="ForwardSub"]
        """);

    var inventory = new ProjectInventoryAnalyzer().Analyze(root);

    AssertTrue(inventory.ResourceReferences.ReferenceUsages.Any(reference => reference.Kind == ResourceReferenceUsageKind.ExtResource && reference.Reference == "ForwardScript" && reference.Exists));
    AssertTrue(inventory.ResourceReferences.ReferenceUsages.Any(reference => reference.Kind == ResourceReferenceUsageKind.SubResource && reference.Reference == "ForwardSub" && reference.Exists));
    AssertFalse(inventory.ResourceReferences.Diagnostics.Any(diagnostic => diagnostic.Code == "resource_graph_missing_reference_declaration"));
}

static void ReportsMissingAndUnsupportedResourceReferences()
{
    var root = CreateTempProjectRoot();
    var scenePath = Path.Combine(root, "Broken.tscn");
    var binaryPath = Path.Combine(root, "Binary.res");
    File.WriteAllText(binaryPath, "binary-placeholder");
    File.WriteAllText(scenePath, """
        [gd_scene load_steps=2 format=3]

        [ext_resource type="Texture2D" path="res://missing.png" id="MissingTexture"]

        [node name="Broken" type="Node"]
        texture = ExtResource("MissingTexture")
        unresolved_external = ExtResource("UnknownExternal")
        unresolved_sub = SubResource("UnknownSub")
        packed = load("res://also_missing.tres")
        """);

    var inventory = new ProjectInventoryAnalyzer().Analyze(root);
    var graph = inventory.ResourceReferences;

    AssertEqual(2, graph.Files.Count);
    AssertEqual(1, graph.ExternalResources.Count);
    AssertTrue(graph.ReferenceUsages.Any(reference => reference.Kind == ResourceReferenceUsageKind.ExtResource && reference.Reference == "MissingTexture" && !reference.Exists));
    AssertTrue(graph.Diagnostics.Any(diagnostic => diagnostic.Code == "resource_graph_missing_reference_declaration"));
    AssertTrue(graph.Diagnostics.Any(diagnostic => diagnostic.Code == "resource_graph_reference_missing_file"));
    AssertTrue(graph.Diagnostics.Any(diagnostic => diagnostic.Code == "resource_graph_binary_resource_unsupported"));
}

static void KeepsResourceReferencesInsideProjectBoundary()
{
    var root = CreateTempProjectRoot();
    var scenePath = Path.Combine(root, "Escapes.tscn");
    File.WriteAllText(scenePath, """
        [gd_scene load_steps=2 format=3]

        [ext_resource type="Resource" path="res://../outside.tres" id="Escape"]

        [node name="Escapes" type="Node"]
        escape = ExtResource("Escape")
        direct = preload("res://../outside.gd")
        """);

    var inventory = new ProjectInventoryAnalyzer().Analyze(root);

    AssertTrue(inventory.ResourceReferences.ExternalResources.Single().IsInsideProjectRoot == false);
    AssertTrue(inventory.ResourceReferences.ReferenceUsages.Any(reference => reference.Kind == ResourceReferenceUsageKind.Preload && reference.IsInsideProjectRoot == false));
    AssertTrue(inventory.ResourceReferences.Diagnostics.Any(diagnostic => diagnostic.Code == "resource_graph_reference_outside_project"));
}

static void SkipsDotDirectoriesWhileScanningProjectFiles()
{
    var root = CreateTempProjectRoot();
    var projectFile = Path.Combine(root, "Game.csproj");
    File.WriteAllText(projectFile, "<Project />");
    var hiddenProjectDir = Path.Combine(root, ".godot", "mono");
    Directory.CreateDirectory(hiddenProjectDir);
    File.WriteAllText(Path.Combine(hiddenProjectDir, "Generated.csproj"), "<Project />");

    var inventory = new ProjectInventoryAnalyzer().Analyze(root);

    AssertEqual(1, inventory.CSharpProjectFiles.Count);
    AssertEqual(Path.GetFullPath(projectFile), inventory.CSharpProjectFiles[0]);
    AssertEqual(1, inventory.DotnetWorkspace.Projects.Count);
}

static void SkipsHiddenAndSystemDirectoriesWhileScanningProjectFiles()
{
    var root = CreateTempProjectRoot();
    var projectFile = Path.Combine(root, "Game.csproj");
    File.WriteAllText(projectFile, "<Project />");
    var hiddenProjectDir = Path.Combine(root, "HiddenGenerated");
    var systemProjectDir = Path.Combine(root, "SystemGenerated");
    Directory.CreateDirectory(hiddenProjectDir);
    Directory.CreateDirectory(systemProjectDir);
    File.WriteAllText(Path.Combine(hiddenProjectDir, "Hidden.csproj"), "<Project />");
    File.WriteAllText(Path.Combine(systemProjectDir, "System.csproj"), "<Project />");

    SetTemporaryAttributes(hiddenProjectDir, FileAttributes.Hidden, () =>
        SetTemporaryAttributes(systemProjectDir, FileAttributes.System, () =>
        {
            var inventory = new ProjectInventoryAnalyzer().Analyze(root);

            AssertEqual(1, inventory.CSharpProjectFiles.Count);
            AssertEqual(Path.GetFullPath(projectFile), inventory.CSharpProjectFiles[0]);
            AssertEqual(1, inventory.DotnetWorkspace.Projects.Count);
        }));
}

static void SkipsReparsePointDirectoriesWhileScanningProjectFiles()
{
    var root = CreateTempProjectRoot();
    var projectFile = Path.Combine(root, "Game.csproj");
    File.WriteAllText(projectFile, "<Project />");
    var outsideRoot = Path.Combine(Path.GetTempPath(), "godot-dotnet-mcp-static-analyzer-outside", Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(outsideRoot);
    File.WriteAllText(Path.Combine(outsideRoot, "Outside.csproj"), "<Project />");
    var linkPath = Path.Combine(root, "LinkedOutside");
    if (!TryCreateDirectorySymbolicLink(linkPath, outsideRoot))
    {
        throw new OperationCanceledException("directory symbolic links are unavailable.");
    }

    var inventory = new ProjectInventoryAnalyzer().Analyze(root);

    AssertEqual(1, inventory.CSharpProjectFiles.Count);
    AssertEqual(Path.GetFullPath(projectFile), inventory.CSharpProjectFiles[0]);
    AssertEqual(1, inventory.DotnetWorkspace.Projects.Count);
}

static void AllowsProjectRootsUnderParentDotDirectories()
{
    var parent = Path.Combine(Path.GetTempPath(), ".godot-dotnet-mcp-static-analyzer", Guid.NewGuid().ToString("N"));
    var root = Path.Combine(parent, "Game");
    Directory.CreateDirectory(root);
    File.WriteAllText(Path.Combine(root, "project.godot"), string.Empty);
    var projectFile = Path.Combine(root, "Game.csproj");
    File.WriteAllText(projectFile, "<Project />");

    var inventory = new ProjectInventoryAnalyzer().Analyze(root);

    AssertTrue(inventory.HasCapability(CompanionCapability.DotnetWorkspaceAnalysis));
    AssertEqual(1, inventory.CSharpProjectFiles.Count);
    AssertEqual(Path.GetFullPath(projectFile), inventory.CSharpProjectFiles[0]);
}

static void KeepsLiveEditorCapabilitiesUnavailableHeadlessly()
{
    var root = CreateTempProjectRoot();
    File.WriteAllText(Path.Combine(root, "Game.csproj"), "<Project />");

    var inventory = new ProjectInventoryAnalyzer().Analyze(root);

    foreach (var capability in new[]
    {
        CompanionCapability.EditorSelection,
        CompanionCapability.InspectorState,
        CompanionCapability.DockState,
        CompanionCapability.EditorScreenshot,
        CompanionCapability.RuntimeValidation,
    })
    {
        var status = inventory.GetCapability(capability);
        AssertEqual(CompanionMode.EditorLive, status.Mode);
        AssertFalse(status.Available);
        AssertContains("online Godot editor bridge", status.Reason);
        AssertContains("explicit editor-live upgrade", status.Reason);
    }
}

static void ReportsMissingDotnetWorkspaceWithoutClaimingLiveState()
{
    var root = CreateTempProjectRoot();

    var inventory = new ProjectInventoryAnalyzer().Analyze(root);

    AssertTrue(inventory.IsGodotProject);
    AssertFalse(inventory.HasCSharpProject);
    AssertFalse(inventory.DotnetWorkspace.HasProjects);
    AssertTrue(inventory.HasCapability(CompanionCapability.StaticProjectAnalysis));
    AssertFalse(inventory.HasCapability(CompanionCapability.DotnetWorkspaceAnalysis));
    AssertContains(".csproj", inventory.GetCapability(CompanionCapability.DotnetWorkspaceAnalysis).Reason);
    AssertFalse(inventory.HasCapability(CompanionCapability.EditorScreenshot));
}

static void DoesNotRegisterNonGodotDirectoriesAsProjects()
{
    var root = Path.Combine(Path.GetTempPath(), "godot-dotnet-mcp-static-analyzer", Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(root);
    File.WriteAllText(Path.Combine(root, "Loose.csproj"), "<Project />");

    var inventory = new ProjectInventoryAnalyzer().Analyze(root);

    AssertFalse(inventory.IsGodotProject);
    AssertEqual<string?>(null, inventory.ProjectId);
    AssertFalse(inventory.ResourceReferences.HasResources);
    AssertFalse(inventory.HasCapability(CompanionCapability.StaticProjectAnalysis));
    AssertFalse(inventory.HasCapability(CompanionCapability.DotnetWorkspaceAnalysis));
    AssertContains("project.godot", inventory.GetCapability(CompanionCapability.DotnetWorkspaceAnalysis).Reason);
    AssertFalse(inventory.HasCapability(CompanionCapability.EditorScreenshot));
}

static string CreateTempProjectRoot()
{
    var root = Path.Combine(Path.GetTempPath(), "godot-dotnet-mcp-static-analyzer", Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(root);
    File.WriteAllText(Path.Combine(root, "project.godot"), string.Empty);
    return root;
}

static void SetTemporaryAttributes(string path, FileAttributes attributes, Action run)
{
    var originalAttributes = File.GetAttributes(path);
    try
    {
        File.SetAttributes(path, originalAttributes | attributes);
        run();
    }
    finally
    {
        File.SetAttributes(path, originalAttributes);
    }
}

static bool TryCreateDirectorySymbolicLink(string linkPath, string targetPath)
{
    try
    {
        Directory.CreateSymbolicLink(linkPath, targetPath);
        return true;
    }
    catch (UnauthorizedAccessException)
    {
        return false;
    }
    catch (IOException)
    {
        return false;
    }
    catch (PlatformNotSupportedException)
    {
        return false;
    }
}

static void AssertTrue(bool condition)
{
    if (!condition)
    {
        throw new InvalidOperationException("Expected condition to be true.");
    }
}

static void AssertFalse(bool condition)
{
    if (condition)
    {
        throw new InvalidOperationException("Expected condition to be false.");
    }
}

static void AssertEqual<T>(T expected, T actual)
{
    if (!EqualityComparer<T>.Default.Equals(expected, actual))
    {
        throw new InvalidOperationException($"Expected {expected}, got {actual}.");
    }
}

static void AssertContains(string expectedSubstring, string actual)
{
    if (!actual.Contains(expectedSubstring, StringComparison.Ordinal))
    {
        throw new InvalidOperationException($"Expected '{actual}' to contain '{expectedSubstring}'.");
    }
}
