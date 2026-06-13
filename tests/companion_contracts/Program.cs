using GodotDotnetMcp.Companion;

var tests = new (string Name, Action Run)[]
{
    ("starts_static_headless_without_live_editor_capabilities", StaticSessionDoesNotExposeLiveCapabilities),
    ("keeps_capability_sets_immutable", CapabilityCatalogSetsCannotBeMutated),
    ("binds_only_godot_project_roots", ProjectDescriptorRequiresGodotProjectRoot),
    ("keeps_explicit_csproj_inside_project_root", ProjectDescriptorKeepsProjectFileInsideRoot),
    ("disambiguates_same_root_csproj_scopes", ProjectDescriptorDisambiguatesSameRootProjectFiles),
    ("project_descriptor_has_no_public_constructor", ProjectDescriptorHasNoPublicConstructor),
    ("broker_registers_projects_through_descriptor_factory", BrokerRegistersProjectsThroughDescriptorFactory),
    ("broker_lists_registered_projects_without_renewing_sessions", BrokerListsRegisteredProjectsWithoutRenewingSessions),
    ("session_identity_preserves_explicit_project_file_scope", SessionIdentityPreservesExplicitProjectFileScope),
    ("requires_project_and_session_scope_for_tools", ToolCallsRequireProjectAndSessionScope),
    ("reports_machine_readable_tool_scope_validation", ReportsMachineReadableToolScopeValidation),
    ("tool_scope_validation_does_not_renew_session_leases", ToolScopeValidationDoesNotRenewSessionLeases),
    ("tool_scope_validation_uses_one_clock_snapshot", ToolScopeValidationUsesOneClockSnapshot),
    ("rejects_cross_project_session_reuse", CrossProjectSessionReuseIsRejected),
    ("stops_and_rejects_revoked_sessions", StopsAndRejectsRevokedSessions),
    ("expires_and_rejects_stale_sessions", ExpiresAndRejectsStaleSessions),
    ("prunes_expired_sessions_before_starting_new_sessions", PrunesExpiredSessionsBeforeStartingNewSessions),
    ("limits_active_sessions_globally_and_per_project", LimitsActiveSessionsGloballyAndPerProject),
    ("renews_session_leases_on_valid_use", RenewsSessionLeasesOnValidUse),
    ("keeps_revoked_sessions_terminal_under_concurrency", RevokedSessionsStayTerminalUnderConcurrency),
    ("keeps_session_snapshots_active_under_concurrency", SessionSnapshotsStayActiveUnderConcurrency),
    ("upgrades_to_editor_live_only_with_matching_online_bridge", ExplicitBridgeUpgradeEnablesLiveCapabilities),
    ("requires_bridge_live_state_support_for_editor_live_upgrade", BridgeLiveStateSupportIsRequired),
    ("rejects_incompatible_editor_bridge_versions", IncompatibleEditorBridgeVersionsAreRejected),
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

static void ProjectDescriptorDisambiguatesSameRootProjectFiles()
{
    var root = CreateTempProjectRoot();
    var gameProject = Path.Combine(root, "Game.csproj");
    var toolsDirectory = Path.Combine(root, "Tools");
    Directory.CreateDirectory(toolsDirectory);
    var toolsProject = Path.Combine(toolsDirectory, "Tools.csproj");
    File.WriteAllText(gameProject, "<Project />");
    File.WriteAllText(toolsProject, "<Project />");

    var rootDescriptor = ProjectDescriptor.FromRoot(root);
    var gameDescriptor = ProjectDescriptor.FromRoot(root, gameProject);
    var toolsDescriptor = ProjectDescriptor.FromRoot(root, toolsProject);

    AssertEqual(rootDescriptor.ProjectId, ProjectDescriptor.FromRoot(root).ProjectId);
    AssertNotEqual(rootDescriptor.ProjectId, gameDescriptor.ProjectId);
    AssertNotEqual(gameDescriptor.ProjectId, toolsDescriptor.ProjectId);
    AssertNotEqual(rootDescriptor.ProjectId, toolsDescriptor.ProjectId);
    AssertEqual(gameDescriptor.ProjectId, ProjectDescriptor.FromRoot(root, Path.Combine("Game.csproj")).ProjectId);
    AssertEqual(toolsDescriptor.ProjectId, ProjectDescriptor.FromRoot(root, Path.Combine("Tools", "Tools.csproj")).ProjectId);

    var broker = new CompanionBroker();
    var registeredGame = broker.RegisterProject(gameDescriptor);
    var registeredTools = broker.RegisterProject(toolsDescriptor);
    var gameSession = broker.StartSession(registeredGame.ProjectId);

    AssertThrows<InvalidOperationException>(() =>
        broker.ResolveSession(new ToolRequestScope(registeredTools.ProjectId, gameSession.Identity.SessionId)));
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

static void BrokerListsRegisteredProjectsWithoutRenewingSessions()
{
    var now = DateTimeOffset.Parse("2026-06-09T00:00:00Z");
    var broker = new CompanionBroker(TimeSpan.FromSeconds(10), () => now);
    var firstProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var secondRoot = CreateTempProjectRoot();
    var secondProjectFile = Path.Combine(secondRoot, "Game.csproj");
    File.WriteAllText(secondProjectFile, "<Project />");
    var secondProject = broker.RegisterProject(secondRoot, secondProjectFile);
    var firstSession = broker.StartSession(firstProject.ProjectId);
    var secondSession = broker.StartSession(secondProject.ProjectId);
    secondSession.UpgradeToEditorLive(new EditorBridgeStatus(
        EditorBridgeState.Online,
        secondProject.ProjectId,
        "editor_session_1",
        "v2.0.0",
        SupportsLiveEditorState: true));
    var firstExpiry = firstSession.Identity.ExpiresAtUtc;
    var secondExpiry = secondSession.Identity.ExpiresAtUtc;
    now = now.AddSeconds(5);

    var projects = broker.ListProjects().ToArray();

    AssertEqual(2, projects.Length);
    var sortedProjectIds = projects.Select(project => project.ProjectId)
        .OrderBy(projectId => projectId, StringComparer.Ordinal)
        .ToArray();
    AssertEqual(sortedProjectIds[0], projects[0].ProjectId);
    AssertEqual(sortedProjectIds[1], projects[1].ProjectId);
    var firstSummary = projects.Single(project => project.ProjectId == firstProject.ProjectId);
    var secondSummary = projects.Single(project => project.ProjectId == secondProject.ProjectId);
    AssertEqual(firstProject.ProjectRoot, firstSummary.ProjectRoot);
    AssertEqual<string?>(null, firstSummary.ProjectFilePath);
    AssertFalse(firstSummary.ProjectFileScoped);
    AssertEqual(1, firstSummary.ActiveSessionCount);
    AssertEqual(1, firstSummary.StaticHeadlessSessionCount);
    AssertEqual(0, firstSummary.EditorLiveSessionCount);
    AssertEqual(secondProject.ProjectRoot, secondSummary.ProjectRoot);
    AssertEqual(secondProject.ProjectFilePath, secondSummary.ProjectFilePath);
    AssertTrue(secondSummary.ProjectFileScoped);
    AssertEqual(1, secondSummary.ActiveSessionCount);
    AssertEqual(0, secondSummary.StaticHeadlessSessionCount);
    AssertEqual(1, secondSummary.EditorLiveSessionCount);
    AssertEqual(firstExpiry, firstSession.Identity.ExpiresAtUtc);
    AssertEqual(secondExpiry, secondSession.Identity.ExpiresAtUtc);
    AssertEqual(DateTimeOffset.Parse("2026-06-09T00:00:00Z"), firstSession.Identity.LastUsedAtUtc);

    now = now.AddSeconds(6);
    firstSummary = broker.ListProjects().Single(project => project.ProjectId == firstProject.ProjectId);
    secondSummary = broker.ListProjects().Single(project => project.ProjectId == secondProject.ProjectId);
    AssertEqual(0, firstSummary.ActiveSessionCount);
    AssertEqual(0, secondSummary.ActiveSessionCount);
}

static void SessionIdentityPreservesExplicitProjectFileScope()
{
    var root = CreateTempProjectRoot();
    var projectFile = Path.Combine(root, "Game.csproj");
    File.WriteAllText(projectFile, "<Project />");
    var broker = new CompanionBroker();

    var rootProject = broker.RegisterProject(root);
    var rootSession = broker.StartSession(rootProject.ProjectId);

    AssertEqual<string?>(null, rootSession.Identity.ProjectFilePath);

    var scopedProject = broker.RegisterProject(root, projectFile);
    var scopedSession = broker.StartSession(scopedProject.ProjectId);

    AssertEqual(Path.GetFullPath(projectFile), scopedProject.ProjectFilePath);
    AssertEqual(scopedProject.ProjectFilePath, scopedSession.Identity.ProjectFilePath);
    AssertEqual(scopedProject.ProjectId, scopedSession.Identity.ProjectId);
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

static void ReportsMachineReadableToolScopeValidation()
{
    var now = DateTimeOffset.Parse("2026-06-09T00:00:00Z");
    var broker = new CompanionBroker(TimeSpan.FromSeconds(10), () => now);
    var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var otherProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var session = broker.StartSession(project.ProjectId);
    var validScope = new ToolRequestScope(project.ProjectId, session.Identity.SessionId);

    var accepted = broker.ValidateToolScope(validScope, CompanionCapability.StaticProjectAnalysis);
    AssertTrue(accepted.Accepted);
    AssertEqual(ToolScopeValidationReason.Accepted, accepted.Reason);
    AssertEqual(session.Identity.SessionId, accepted.Session?.SessionId);

    var missingProject = broker.ValidateToolScope(new ToolRequestScope(string.Empty, session.Identity.SessionId));
    AssertFalse(missingProject.Accepted);
    AssertEqual(ToolScopeValidationReason.MissingProjectId, missingProject.Reason);
    AssertEqual<ProjectSessionIdentity?>(null, missingProject.Session);

    var missingSession = broker.ValidateToolScope(new ToolRequestScope(project.ProjectId, string.Empty));
    AssertFalse(missingSession.Accepted);
    AssertEqual(ToolScopeValidationReason.MissingSessionId, missingSession.Reason);

    var unknownSession = broker.ValidateToolScope(new ToolRequestScope(project.ProjectId, "session_missing"));
    AssertFalse(unknownSession.Accepted);
    AssertEqual(ToolScopeValidationReason.UnknownSessionId, unknownSession.Reason);

    var crossProject = broker.ValidateToolScope(new ToolRequestScope(otherProject.ProjectId, session.Identity.SessionId));
    AssertFalse(crossProject.Accepted);
    AssertEqual(ToolScopeValidationReason.ProjectSessionMismatch, crossProject.Reason);
    AssertEqual(session.Identity.SessionId, crossProject.Session?.SessionId);

    var missingCapability = broker.ValidateToolScope(validScope, CompanionCapability.EditorScreenshot);
    AssertFalse(missingCapability.Accepted);
    AssertEqual(ToolScopeValidationReason.CapabilityUnavailable, missingCapability.Reason);
    AssertEqual(session.Identity.SessionId, missingCapability.Session?.SessionId);

    now = now.AddSeconds(11);
    var expired = broker.ValidateToolScope(validScope);
    AssertFalse(expired.Accepted);
    AssertEqual(ToolScopeValidationReason.ExpiredSession, expired.Reason);
    AssertEqual(session.Identity.SessionId, expired.Session?.SessionId);
}

static void ToolScopeValidationDoesNotRenewSessionLeases()
{
    var now = DateTimeOffset.Parse("2026-06-09T00:00:00Z");
    var broker = new CompanionBroker(TimeSpan.FromSeconds(10), () => now);
    var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var session = broker.StartSession(project.ProjectId);
    var firstExpiry = session.Identity.ExpiresAtUtc;
    now = now.AddSeconds(5);

    var result = broker.ValidateToolScope(
        new ToolRequestScope(project.ProjectId, session.Identity.SessionId),
        CompanionCapability.StaticProjectAnalysis);

    AssertTrue(result.Accepted);
    AssertEqual(firstExpiry, session.Identity.ExpiresAtUtc);
    AssertEqual(DateTimeOffset.Parse("2026-06-09T00:00:00Z"), session.Identity.LastUsedAtUtc);
}

static void ToolScopeValidationUsesOneClockSnapshot()
{
    var reads = -1;
    var clockReads = new[]
    {
        DateTimeOffset.Parse("2026-06-09T00:00:00Z"),
        DateTimeOffset.Parse("2026-06-09T00:00:00Z"),
        DateTimeOffset.Parse("2026-06-09T00:00:09.999Z"),
        DateTimeOffset.Parse("2026-06-09T00:00:10.001Z"),
    };
    var broker = new CompanionBroker(
        TimeSpan.FromSeconds(10),
        () => clockReads[Math.Min(++reads, clockReads.Length - 1)]);
    var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var session = broker.StartSession(project.ProjectId);
    AssertEqual(DateTimeOffset.Parse("2026-06-09T00:00:10Z"), session.Identity.ExpiresAtUtc);

    var result = broker.ValidateToolScope(
        new ToolRequestScope(project.ProjectId, session.Identity.SessionId),
        CompanionCapability.StaticProjectAnalysis);

    AssertTrue(result.Accepted);
    AssertEqual(ToolScopeValidationReason.Accepted, result.Reason);
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

static void StopsAndRejectsRevokedSessions()
{
    var broker = new CompanionBroker();
    var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var session = broker.StartSession(project.ProjectId);
    var scope = new ToolRequestScope(project.ProjectId, session.Identity.SessionId);

    AssertTrue(broker.StopSession(scope));
    AssertTrue(session.Identity.Revoked);
    AssertFalse(session.HasCapability(CompanionCapability.StaticProjectAnalysis));
    AssertFalse(session.HasCapability(CompanionCapability.EditorScreenshot));
    AssertThrows<InvalidOperationException>(() =>
        session.UpgradeToEditorLive(new EditorBridgeStatus(
            EditorBridgeState.Online,
            project.ProjectId,
            "editor_session_1",
            "2.0.0",
            true)));
    AssertThrows<KeyNotFoundException>(() => broker.ResolveSession(scope));
    AssertFalse(broker.Sessions.Any(current => current.SessionId == session.Identity.SessionId));
}

static void ExpiresAndRejectsStaleSessions()
{
    var now = DateTimeOffset.Parse("2026-06-09T00:00:00Z");
    var broker = new CompanionBroker(TimeSpan.FromSeconds(10), () => now);
    var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var session = broker.StartSession(project.ProjectId);
    now = now.AddSeconds(11);

    AssertFalse(session.HasCapability(CompanionCapability.StaticProjectAnalysis));
    AssertFalse(session.HasCapability(CompanionCapability.EditorScreenshot));
    AssertThrows<InvalidOperationException>(() =>
        session.UpgradeToEditorLive(new EditorBridgeStatus(
            EditorBridgeState.Online,
            project.ProjectId,
            "editor_session_1",
            "2.0.0",
            true)));
    AssertThrows<InvalidOperationException>(() =>
        broker.ResolveSession(new ToolRequestScope(project.ProjectId, session.Identity.SessionId)));
    AssertThrows<KeyNotFoundException>(() =>
        broker.ResolveSession(new ToolRequestScope(project.ProjectId, session.Identity.SessionId)));

    var visibleSession = broker.StartSession(project.ProjectId);
    now = now.AddSeconds(11);
    AssertFalse(broker.Sessions.Any(current => current.SessionId == visibleSession.Identity.SessionId));
    AssertThrows<KeyNotFoundException>(() =>
        broker.ResolveSession(new ToolRequestScope(project.ProjectId, visibleSession.Identity.SessionId)));
}

static void PrunesExpiredSessionsBeforeStartingNewSessions()
{
    var now = DateTimeOffset.Parse("2026-06-09T00:00:00Z");
    var broker = new CompanionBroker(
        TimeSpan.FromSeconds(5),
        () => now,
        maxActiveSessions: 2,
        maxActiveSessionsPerProject: 2);
    var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var first = broker.StartSession(project.ProjectId);
    var second = broker.StartSession(project.ProjectId);
    now = now.AddSeconds(6);

    var replacement = broker.StartSession(project.ProjectId);

    AssertFalse(broker.Sessions.Any(current => current.SessionId == first.Identity.SessionId));
    AssertFalse(broker.Sessions.Any(current => current.SessionId == second.Identity.SessionId));
    AssertTrue(broker.Sessions.Any(current => current.SessionId == replacement.Identity.SessionId));
}

static void LimitsActiveSessionsGloballyAndPerProject()
{
    var broker = new CompanionBroker(
        TimeSpan.FromMinutes(30),
        maxActiveSessions: 3,
        maxActiveSessionsPerProject: 2);
    var firstProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var secondProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));

    broker.StartSession(firstProject.ProjectId);
    broker.StartSession(firstProject.ProjectId);
    AssertThrows<InvalidOperationException>(() => broker.StartSession(firstProject.ProjectId));

    broker.StartSession(secondProject.ProjectId);
    AssertThrows<InvalidOperationException>(() => broker.StartSession(secondProject.ProjectId));
}

static void RenewsSessionLeasesOnValidUse()
{
    var now = DateTimeOffset.Parse("2026-06-09T00:00:00Z");
    var broker = new CompanionBroker(TimeSpan.FromSeconds(10), () => now);
    var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var session = broker.StartSession(project.ProjectId);
    var firstExpiry = session.Identity.ExpiresAtUtc;
    now = now.AddSeconds(5);

    var renewed = broker.RenewSession(new ToolRequestScope(project.ProjectId, session.Identity.SessionId));

    AssertEqual(session.Identity.SessionId, renewed.Identity.SessionId);
    AssertTrue(renewed.Identity.ExpiresAtUtc > firstExpiry);
    AssertEqual(now, renewed.Identity.LastUsedAtUtc);
}

static void RevokedSessionsStayTerminalUnderConcurrency()
{
    for (var i = 0; i < 100; i++)
    {
        var broker = new CompanionBroker();
        var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
        var session = broker.StartSession(project.ProjectId);
        var scope = new ToolRequestScope(project.ProjectId, session.Identity.SessionId);
        var bridgeStatus = new EditorBridgeStatus(
            EditorBridgeState.Online,
            project.ProjectId,
            "editor_session_1",
            "2.0.0",
            true);

        var stopTask = Task.Run(() =>
        {
            try
            {
                broker.StopSession(scope);
            }
            catch (KeyNotFoundException)
            {
            }
            catch (InvalidOperationException)
            {
            }
        });
        var renewTask = Task.Run(() =>
        {
            try
            {
                broker.RenewSession(scope);
            }
            catch (KeyNotFoundException)
            {
            }
            catch (InvalidOperationException)
            {
            }
        });
        var upgradeTask = Task.Run(() =>
        {
            try
            {
                session.UpgradeToEditorLive(bridgeStatus);
            }
            catch (InvalidOperationException)
            {
            }
        });

        Task.WaitAll(stopTask, renewTask, upgradeTask);
        if (!session.Identity.Revoked)
        {
            broker.StopSession(scope);
        }

        AssertTrue(session.Identity.Revoked);
        AssertFalse(session.IsActive(DateTimeOffset.UtcNow));
        AssertFalse(session.HasCapability(CompanionCapability.StaticProjectAnalysis));
        AssertFalse(session.HasCapability(CompanionCapability.EditorScreenshot));
        AssertThrows<InvalidOperationException>(() => session.UpgradeToEditorLive(bridgeStatus));
    }
}

static void SessionSnapshotsStayActiveUnderConcurrency()
{
    for (var i = 0; i < 100; i++)
    {
        var broker = new CompanionBroker();
        var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
        var session = broker.StartSession(project.ProjectId);
        var scope = new ToolRequestScope(project.ProjectId, session.Identity.SessionId);
        var stopTask = Task.Run(() =>
        {
            try
            {
                broker.StopSession(scope);
            }
            catch (KeyNotFoundException)
            {
            }
            catch (InvalidOperationException)
            {
            }
        });
        var snapshotTask = Task.Run(() => broker.Sessions.ToArray());

        Task.WaitAll(stopTask, snapshotTask);
        foreach (var identity in snapshotTask.Result)
        {
            AssertFalse(identity.Revoked);
            AssertTrue(identity.ExpiresAtUtc > DateTimeOffset.UtcNow);
        }

        AssertFalse(broker.Sessions.Any(current => current.SessionId == session.Identity.SessionId));
    }
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
            "2.0.0",
            true)));

    session.UpgradeToEditorLive(new EditorBridgeStatus(
        EditorBridgeState.Online,
        project.ProjectId,
        "editor_session_1",
        "2.0.0",
        true));

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

static void BridgeLiveStateSupportIsRequired()
{
    var broker = new CompanionBroker();
    var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var session = broker.StartSession(project.ProjectId);

    AssertThrows<InvalidOperationException>(() =>
        session.UpgradeToEditorLive(new EditorBridgeStatus(
            EditorBridgeState.Online,
            project.ProjectId,
            "editor_session_1",
            "2.0.0",
            false)));
    AssertEqual(CompanionMode.StaticHeadless, session.Identity.Mode);
}

static void IncompatibleEditorBridgeVersionsAreRejected()
{
    var broker = new CompanionBroker();
    var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var session = broker.StartSession(project.ProjectId);

    foreach (var pluginVersion in new string?[]
    {
        null,
        "",
        "1.4.0",
        "3.0.0",
        "not-a-version",
        " 2.0.0",
        "2.0.0 ",
        "02.0.0",
        "2.0.0-",
        "2.0.0+",
        "2.0.0-%%%",
        "2.0.0+bad space",
        "2.0.0-preview..1",
    })
    {
        AssertThrows<InvalidOperationException>(() =>
            session.UpgradeToEditorLive(new EditorBridgeStatus(
                EditorBridgeState.Online,
                project.ProjectId,
                "editor_session_1",
                pluginVersion,
                true)));
        AssertEqual(CompanionMode.StaticHeadless, session.Identity.Mode);
    }

    AssertThrows<InvalidOperationException>(() =>
        session.UpgradeToEditorLive(new EditorBridgeStatus(
            EditorBridgeState.VersionMismatch,
            project.ProjectId,
            "editor_session_1",
            "2.0.0",
            false)));

    session.UpgradeToEditorLive(new EditorBridgeStatus(
        EditorBridgeState.Online,
        project.ProjectId,
        "editor_session_1",
        "v2.0.0-preview.1+build.5",
        true));
    AssertEqual(CompanionMode.EditorLive, session.Identity.Mode);
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

static void AssertNotEqual<T>(T unexpected, T actual)
{
    if (EqualityComparer<T>.Default.Equals(unexpected, actual))
    {
        throw new InvalidOperationException($"Expected value other than {unexpected}.");
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
