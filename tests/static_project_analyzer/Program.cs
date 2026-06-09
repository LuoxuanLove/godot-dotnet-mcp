using GodotDotnetMcp.Companion;
using GodotDotnetMcp.Companion.StaticAnalysis;

var tests = new (string Name, Action Run)[]
{
    ("reports_static_inventory_for_godot_dotnet_project", ReportsStaticInventoryForGodotDotnetProject),
    ("skips_dot_directories_while_scanning_project_files", SkipsDotDirectoriesWhileScanningProjectFiles),
    ("allows_project_roots_under_parent_dot_directories", AllowsProjectRootsUnderParentDotDirectories),
    ("keeps_live_editor_capabilities_unavailable_headlessly", KeepsLiveEditorCapabilitiesUnavailableHeadlessly),
    ("reports_missing_dotnet_workspace_without_claiming_live_state", ReportsMissingDotnetWorkspaceWithoutClaimingLiveState),
    ("does_not_register_non_godot_directories_as_projects", DoesNotRegisterNonGodotDirectoriesAsProjects),
};

foreach (var test in tests)
{
    test.Run();
    Console.WriteLine($"PASS {test.Name}");
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
    AssertTrue(inventory.HasCapability(CompanionCapability.StaticProjectAnalysis));
    AssertTrue(inventory.HasCapability(CompanionCapability.DotnetWorkspaceAnalysis));
    AssertTrue(inventory.HasCapability(CompanionCapability.ResourceGraphAnalysis));
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
