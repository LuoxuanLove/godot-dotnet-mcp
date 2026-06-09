using GodotDotnetMcp.Companion;

var tests = new (string Name, Action Run)[]
{
    ("starts_static_headless_without_live_editor_capabilities", StaticSessionDoesNotExposeLiveCapabilities),
    ("keeps_capability_sets_immutable", CapabilityCatalogSetsCannotBeMutated),
    ("binds_only_godot_project_roots", ProjectDescriptorRequiresGodotProjectRoot),
    ("keeps_explicit_csproj_inside_project_root", ProjectDescriptorKeepsProjectFileInsideRoot),
    ("project_descriptor_has_no_public_constructor", ProjectDescriptorHasNoPublicConstructor),
    ("broker_registers_projects_through_descriptor_factory", BrokerRegistersProjectsThroughDescriptorFactory),
    ("requires_project_and_session_scope_for_tools", ToolCallsRequireProjectAndSessionScope),
    ("rejects_cross_project_session_reuse", CrossProjectSessionReuseIsRejected),
    ("upgrades_to_editor_live_only_with_matching_online_bridge", ExplicitBridgeUpgradeEnablesLiveCapabilities),
};

foreach (var test in tests)
{
    test.Run();
    Console.WriteLine($"PASS {test.Name}");
}

return 0;

static void StaticSessionDoesNotExposeLiveCapabilities()
{
    var broker = new CompanionBroker();
    var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var session = broker.StartSession(project.ProjectId);

    AssertEqual(CompanionMode.StaticHeadless, session.Identity.Mode);
    AssertEqual<string?>(null, session.Identity.EditorSessionId);
    AssertTrue(session.HasCapability(CompanionCapability.StaticProjectAnalysis));
    AssertTrue(session.HasCapability(CompanionCapability.DotnetWorkspaceAnalysis));
    AssertFalse(session.HasCapability(CompanionCapability.EditorSelection));
    AssertFalse(session.HasCapability(CompanionCapability.InspectorState));
}

static void CapabilityCatalogSetsCannotBeMutated()
{
    var staticCapabilities = CompanionCapabilityCatalog.ForMode(CompanionMode.StaticHeadless);

    AssertThrows<NotSupportedException>(() =>
        ((ISet<CompanionCapability>)staticCapabilities).Add(CompanionCapability.EditorScreenshot));
    AssertFalse(staticCapabilities.Contains(CompanionCapability.EditorScreenshot));
}

static void ProjectDescriptorRequiresGodotProjectRoot()
{
    var notProjectRoot = Path.Combine(Path.GetTempPath(), "godot-dotnet-mcp-companion-contracts", Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(notProjectRoot);

    AssertThrows<ArgumentException>(() => ProjectDescriptor.FromRoot(notProjectRoot));
}

static void ProjectDescriptorKeepsProjectFileInsideRoot()
{
    var root = CreateTempProjectRoot();
    var projectFile = Path.Combine(root, "Game.csproj");
    File.WriteAllText(projectFile, "<Project />");

    var descriptor = ProjectDescriptor.FromRoot(root, projectFile);
    AssertEqual(Path.GetFullPath(projectFile), descriptor.ProjectFilePath);

    var externalProject = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N") + ".csproj");
    AssertThrows<ArgumentException>(() => ProjectDescriptor.FromRoot(root, externalProject));
    AssertThrows<ArgumentException>(() => ProjectDescriptor.FromRoot(root, "not-a-project.txt"));
}

static void ProjectDescriptorHasNoPublicConstructor()
{
    var publicConstructors = typeof(ProjectDescriptor).GetConstructors();
    AssertEqual(0, publicConstructors.Length);
}

static void BrokerRegistersProjectsThroughDescriptorFactory()
{
    var root = CreateTempProjectRoot();
    var broker = new CompanionBroker();
    var project = broker.RegisterProject(root);
    var session = broker.StartSession(project.ProjectId);

    AssertEqual(project.ProjectId, session.Identity.ProjectId);
    AssertEqual(Path.GetFullPath(root), project.ProjectRoot);
}

static void ToolCallsRequireProjectAndSessionScope()
{
    var broker = new CompanionBroker();
    var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var session = broker.StartSession(project.ProjectId);

    broker.RequireCapability(
        new ToolRequestScope(project.ProjectId, session.Identity.SessionId),
        CompanionCapability.StaticProjectAnalysis);

    AssertThrows<ArgumentException>(() =>
        broker.ResolveSession(new ToolRequestScope(string.Empty, session.Identity.SessionId)));
    AssertThrows<ArgumentException>(() =>
        broker.ResolveSession(new ToolRequestScope(project.ProjectId, string.Empty)));
}

static void CrossProjectSessionReuseIsRejected()
{
    var broker = new CompanionBroker();
    var firstProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var secondProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var firstSession = broker.StartSession(firstProject.ProjectId);

    AssertThrows<InvalidOperationException>(() =>
        broker.ResolveSession(new ToolRequestScope(secondProject.ProjectId, firstSession.Identity.SessionId)));
}

static void ExplicitBridgeUpgradeEnablesLiveCapabilities()
{
    var broker = new CompanionBroker();
    var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var session = broker.StartSession(project.ProjectId);

    broker.RequireCapability(
        new ToolRequestScope(project.ProjectId, session.Identity.SessionId),
        CompanionCapability.ResourceGraphAnalysis);

    AssertThrows<InvalidOperationException>(() =>
        broker.RequireCapability(
            new ToolRequestScope(project.ProjectId, session.Identity.SessionId),
            CompanionCapability.EditorScreenshot));

    AssertThrows<InvalidOperationException>(() =>
        session.UpgradeToEditorLive(new EditorBridgeStatus(
            EditorBridgeState.Online,
            project.ProjectId,
            null,
            "2.0.0")));

    session.UpgradeToEditorLive(new EditorBridgeStatus(
        EditorBridgeState.Online,
        project.ProjectId,
        "editor_session_1",
        "2.0.0"));

    AssertEqual(CompanionMode.EditorLive, session.Identity.Mode);
    AssertEqual("editor_session_1", session.Identity.EditorSessionId);
    broker.RequireCapability(
        new ToolRequestScope(project.ProjectId, session.Identity.SessionId),
        CompanionCapability.EditorScreenshot);

    var otherProject = ProjectDescriptor.FromRoot(CreateTempProjectRoot());
    var isolatedSession = new CompanionBroker();
    var registeredOther = isolatedSession.RegisterProject(otherProject);
    var staticSession = isolatedSession.StartSession(registeredOther.ProjectId);
    AssertThrows<InvalidOperationException>(() =>
        staticSession.UpgradeToEditorLive(EditorBridgeStatus.Disabled(registeredOther.ProjectId)));
}

static string CreateTempProjectRoot()
{
    var root = Path.Combine(Path.GetTempPath(), "godot-dotnet-mcp-companion-contracts", Guid.NewGuid().ToString("N"));
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

static void AssertThrows<TException>(Action action)
    where TException : Exception
{
    try
    {
        action();
    }
    catch (TException)
    {
        return;
    }

    throw new InvalidOperationException($"Expected exception {typeof(TException).Name}.");
}
