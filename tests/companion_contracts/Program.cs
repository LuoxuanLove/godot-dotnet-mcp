using GodotDotnetMcp.Companion;
using System.Text.Json;

var tests = new (string Name, Action Run)[]
{
    ("starts_static_headless_without_live_editor_capabilities", StaticSessionDoesNotExposeLiveCapabilities),
    ("keeps_capability_sets_immutable", CapabilityCatalogSetsCannotBeMutated),
    ("validates_explicit_broker_lifecycle_options", ValidatesExplicitBrokerLifecycleOptions),
    ("matches_broker_lifecycle_manifest_to_runtime_contract", BrokerLifecycleManifestMatchesRuntimeContract),
    ("validates_explicit_broker_transport_options", ValidatesExplicitBrokerTransportOptions),
    ("binds_only_godot_project_roots", ProjectDescriptorRequiresGodotProjectRoot),
    ("keeps_explicit_csproj_inside_project_root", ProjectDescriptorKeepsProjectFileInsideRoot),
    ("disambiguates_same_root_csproj_scopes", ProjectDescriptorDisambiguatesSameRootProjectFiles),
    ("project_descriptor_has_no_public_constructor", ProjectDescriptorHasNoPublicConstructor),
    ("broker_registers_projects_through_descriptor_factory", BrokerRegistersProjectsThroughDescriptorFactory),
    ("broker_lists_registered_projects_without_renewing_sessions", BrokerListsRegisteredProjectsWithoutRenewingSessions),
    ("broker_reports_status_without_side_effects", BrokerReportsStatusWithoutSideEffects),
    ("broker_manifest_declares_status_snapshot", BrokerManifestDeclaresStatusSnapshot),
    ("broker_lists_project_sessions_without_crossing_project_boundaries", BrokerListsProjectSessionsWithoutCrossingProjectBoundaries),
    ("broker_tracks_editor_bridge_status_without_upgrading_sessions", BrokerTracksEditorBridgeStatusWithoutUpgradingSessions),
    ("broker_evaluates_stored_editor_live_upgrade_without_mutating_sessions", BrokerEvaluatesStoredEditorLiveUpgradeWithoutMutatingSessions),
    ("broker_upgrades_sessions_to_editor_live_from_stored_bridge_status", BrokerUpgradesSessionsToEditorLiveFromStoredBridgeStatus),
    ("broker_removes_projects_and_revokes_their_sessions", BrokerRemovesProjectsAndRevokesTheirSessions),
    ("broker_shutdown_revokes_sessions_and_clears_bridge_state", BrokerShutdownRevokesSessionsAndClearsBridgeState),
    ("broker_manifest_declares_shutdown_contract", BrokerManifestDeclaresShutdownContract),
    ("session_identity_preserves_explicit_project_file_scope", SessionIdentityPreservesExplicitProjectFileScope),
    ("requires_project_and_session_scope_for_tools", ToolCallsRequireProjectAndSessionScope),
    ("reports_machine_readable_tool_scope_validation", ReportsMachineReadableToolScopeValidation),
    ("broker_evaluates_tool_availability_without_renewing_sessions", BrokerEvaluatesToolAvailabilityWithoutRenewingSessions),
    ("broker_manifest_declares_tool_availability_preflight", BrokerManifestDeclaresToolAvailabilityPreflight),
    ("reports_session_capabilities_without_renewing_leases", ReportsSessionCapabilitiesWithoutRenewingLeases),
    ("broker_reports_session_health_without_renewing_leases", BrokerReportsSessionHealthWithoutRenewingLeases),
    ("broker_manifest_declares_session_health_snapshot", BrokerManifestDeclaresSessionHealthSnapshot),
    ("tool_scope_validation_does_not_renew_session_leases", ToolScopeValidationDoesNotRenewSessionLeases),
    ("session_health_uses_one_clock_snapshot", SessionHealthUsesOneClockSnapshot),
    ("tool_scope_validation_uses_one_clock_snapshot", ToolScopeValidationUsesOneClockSnapshot),
    ("rejects_cross_project_session_reuse", CrossProjectSessionReuseIsRejected),
    ("stops_and_rejects_revoked_sessions", StopsAndRejectsRevokedSessions),
    ("expires_and_rejects_stale_sessions", ExpiresAndRejectsStaleSessions),
    ("prunes_expired_sessions_before_starting_new_sessions", PrunesExpiredSessionsBeforeStartingNewSessions),
    ("limits_active_sessions_globally_and_per_project", LimitsActiveSessionsGloballyAndPerProject),
    ("renews_session_leases_on_valid_use", RenewsSessionLeasesOnValidUse),
    ("keeps_revoked_sessions_terminal_under_concurrency", RevokedSessionsStayTerminalUnderConcurrency),
    ("keeps_session_snapshots_active_under_concurrency", SessionSnapshotsStayActiveUnderConcurrency),
    ("keeps_tool_availability_snapshots_consistent_under_stop_concurrency", ToolAvailabilitySnapshotsStayConsistentUnderStopConcurrency),
    ("evaluates_editor_live_upgrade_without_changing_session_state", EditorLiveUpgradeEligibilityDoesNotMutateSession),
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

static void ValidatesExplicitBrokerLifecycleOptions()
{
    BrokerLifecycleOptions.Default.Validate();

    AssertFalse(BrokerLifecycleOptions.Default.EnabledByDefault);
    AssertFalse(BrokerLifecycleOptions.Default.StartsBackgroundProcess);
    AssertFalse(BrokerLifecycleOptions.Default.OpensListeningPort);
    AssertFalse(BrokerLifecycleOptions.Default.LaunchesGodotEditor);
    AssertTrue(BrokerLifecycleOptions.Default.RequiresExplicitStart);
    AssertTrue(BrokerLifecycleOptions.Default.RequiresExplicitEditorLaunch);

    AssertThrows<InvalidOperationException>(() =>
        new BrokerLifecycleOptions(EnabledByDefault: true).Validate());
    AssertThrows<InvalidOperationException>(() =>
        new BrokerLifecycleOptions(StartsBackgroundProcess: true).Validate());
    AssertThrows<InvalidOperationException>(() =>
        new BrokerLifecycleOptions(OpensListeningPort: true).Validate());
    AssertThrows<InvalidOperationException>(() =>
        new BrokerLifecycleOptions(LaunchesGodotEditor: true).Validate());
    AssertThrows<InvalidOperationException>(() =>
        new BrokerLifecycleOptions(RequiresExplicitStart: false).Validate());
    AssertThrows<InvalidOperationException>(() =>
        new BrokerLifecycleOptions(RequiresExplicitEditorLaunch: false).Validate());
}

static void BrokerLifecycleManifestMatchesRuntimeContract()
{
    var manifestPath = FindRepositoryFile(Path.Combine("companion", "contracts", "v2-broker-manifest.json"));
    using var manifest = JsonDocument.Parse(File.ReadAllText(manifestPath));
    var lifecycle = manifest.RootElement.GetProperty("default_lifecycle");
    var runtimeOptions = BrokerLifecycleOptions.Default;

    AssertEqual(runtimeOptions.EnabledByDefault, lifecycle.GetProperty("enabled_by_default").GetBoolean());
    AssertEqual(runtimeOptions.StartsBackgroundProcess, lifecycle.GetProperty("starts_background_process").GetBoolean());
    AssertEqual(runtimeOptions.OpensListeningPort, lifecycle.GetProperty("opens_listening_port").GetBoolean());
    AssertEqual(runtimeOptions.LaunchesGodotEditor, lifecycle.GetProperty("launches_godot_editor").GetBoolean());
    AssertEqual(runtimeOptions.RequiresExplicitStart, lifecycle.GetProperty("requires_explicit_start").GetBoolean());
    AssertEqual(runtimeOptions.RequiresExplicitEditorLaunch, lifecycle.GetProperty("requires_explicit_editor_launch").GetBoolean());
    AssertTrue(lifecycle.GetProperty("validated_by_runtime_contract").GetBoolean());
}

static void ValidatesExplicitBrokerTransportOptions()
{
    BrokerTransportOptions.Default.Validate();
    BrokerTransportOptions.CreateStdio().Validate();
    BrokerTransportOptions.CreateHttpLoopback(8765).Validate();

    AssertEqual(BrokerTransportMode.Stdio, BrokerTransportOptions.Default.Mode);
    AssertFalse(BrokerTransportOptions.Default.HttpLoopbackEnabled);
    AssertEqual("127.0.0.1", BrokerTransportOptions.Default.HttpLoopbackHost);
    AssertEqual<int?>(null, BrokerTransportOptions.Default.HttpLoopbackPort);

    AssertThrows<InvalidOperationException>(() =>
        new BrokerTransportOptions(BrokerTransportMode.Stdio, HttpLoopbackEnabled: true).Validate());
    AssertThrows<InvalidOperationException>(() =>
        new BrokerTransportOptions(BrokerTransportMode.Stdio, HttpLoopbackPort: 8765).Validate());
    AssertThrows<InvalidOperationException>(() =>
        new BrokerTransportOptions(BrokerTransportMode.HttpLoopback).Validate());
    AssertThrows<InvalidOperationException>(() =>
        new BrokerTransportOptions(BrokerTransportMode.HttpLoopback, HttpLoopbackEnabled: true).Validate());
    AssertThrows<InvalidOperationException>(() =>
        BrokerTransportOptions.CreateHttpLoopback(8765, "0.0.0.0").Validate());
    AssertThrows<InvalidOperationException>(() =>
        BrokerTransportOptions.CreateHttpLoopback(0).Validate());
    AssertThrows<InvalidOperationException>(() =>
        BrokerTransportOptions.CreateHttpLoopback(65536).Validate());
    AssertThrows<ArgumentException>(() =>
        new BrokerTransportOptions(BrokerTransportMode.HttpLoopback, HttpLoopbackEnabled: true, HttpLoopbackHost: " ").Validate());
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

static void BrokerReportsStatusWithoutSideEffects()
{
    var now = DateTimeOffset.Parse("2026-06-09T00:00:00Z");
    var broker = new CompanionBroker(TimeSpan.FromSeconds(10), () => now);
    var firstProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var secondProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var thirdProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var firstSession = broker.StartSession(firstProject.ProjectId);
    var secondSession = broker.StartSession(secondProject.ProjectId);
    var thirdSession = broker.StartSession(thirdProject.ProjectId);
    var firstExpiry = firstSession.Identity.ExpiresAtUtc;
    var secondExpiry = secondSession.Identity.ExpiresAtUtc;
    broker.UpdateEditorBridgeStatus(new EditorBridgeStatus(
        EditorBridgeState.Online,
        secondProject.ProjectId,
        "editor_session_1",
        "2.0.0",
        true));
    broker.UpgradeSessionToEditorLive(new ToolRequestScope(secondProject.ProjectId, secondSession.Identity.SessionId));
    broker.UpdateEditorBridgeStatus(new EditorBridgeStatus(
        EditorBridgeState.Online,
        thirdProject.ProjectId,
        "editor_session_2",
        "1.9.0",
        true));
    now = now.AddSeconds(5);

    var status = broker.GetBrokerStatus();

    AssertEqual(now, status.CapturedAtUtc);
    AssertEqual(3, status.RegisteredProjectCount);
    AssertEqual(3, status.ActiveSessionCount);
    AssertEqual(2, status.StaticHeadlessSessionCount);
    AssertEqual(1, status.EditorLiveSessionCount);
    AssertEqual(2, status.StoredBridgeStatusCount);
    AssertEqual(2, status.OnlineBridgeStatusCount);
    AssertEqual(1, status.LiveCapableBridgeStatusCount);
    AssertEqual(1, status.DisabledBridgeStatusCount);
    AssertEqual(3, status.Projects.Count);
    AssertEqual(firstExpiry, firstSession.Identity.ExpiresAtUtc);
    AssertEqual(secondExpiry, secondSession.Identity.ExpiresAtUtc);
    AssertEqual(DateTimeOffset.Parse("2026-06-09T00:00:00Z"), firstSession.Identity.LastUsedAtUtc);
    var projectIds = status.Projects.Select(project => project.ProjectId).ToArray();
    var sortedProjectIds = projectIds.OrderBy(projectId => projectId, StringComparer.Ordinal).ToArray();
    AssertEqual(string.Join("|", sortedProjectIds), string.Join("|", projectIds));

    var stoppedScope = new ToolRequestScope(thirdProject.ProjectId, thirdSession.Identity.SessionId);
    AssertTrue(broker.StopSession(stoppedScope));
    var afterStop = broker.GetBrokerStatus();
    AssertEqual(2, afterStop.ActiveSessionCount);
    AssertEqual(1, afterStop.StaticHeadlessSessionCount);
    AssertEqual(1, afterStop.EditorLiveSessionCount);

    now = now.AddSeconds(6);
    var expired = broker.GetBrokerStatus();
    AssertEqual(0, expired.ActiveSessionCount);
    AssertEqual(0, expired.StaticHeadlessSessionCount);
    AssertEqual(0, expired.EditorLiveSessionCount);
    AssertEqual(3, expired.RegisteredProjectCount);
}

static void BrokerManifestDeclaresStatusSnapshot()
{
    var manifestPath = FindRepositoryFile(Path.Combine("companion", "contracts", "v2-broker-manifest.json"));
    using var manifest = JsonDocument.Parse(File.ReadAllText(manifestPath));
    var status = manifest.RootElement.GetProperty("broker_status");

    AssertTrue(status.GetProperty("snapshot_supported").GetBoolean());
    AssertFalse(status.GetProperty("snapshot_renews_sessions").GetBoolean());
    AssertFalse(status.GetProperty("snapshot_scans_filesystem").GetBoolean());
    AssertFalse(status.GetProperty("snapshot_launches_godot_editor").GetBoolean());
    AssertTrue(status.GetProperty("reports_registered_project_count").GetBoolean());
    AssertTrue(status.GetProperty("reports_session_mode_counts").GetBoolean());
    AssertTrue(status.GetProperty("reports_bridge_status_counts").GetBoolean());
    AssertTrue(status.GetProperty("reports_project_summaries").GetBoolean());
}

static void BrokerListsProjectSessionsWithoutCrossingProjectBoundaries()
{
    var now = DateTimeOffset.Parse("2026-06-09T00:00:00Z");
    var broker = new CompanionBroker(TimeSpan.FromSeconds(10), () => now);
    var firstProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var secondProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var firstSession = broker.StartSession(firstProject.ProjectId);
    var secondSession = broker.StartSession(firstProject.ProjectId);
    var otherSession = broker.StartSession(secondProject.ProjectId);
    var firstExpiry = firstSession.Identity.ExpiresAtUtc;

    AssertThrows<ArgumentException>(() => broker.ListProjectSessions(string.Empty));
    AssertThrows<KeyNotFoundException>(() => broker.ListProjectSessions("project_missing"));

    now = now.AddSeconds(5);
    var firstProjectSessions = broker.ListProjectSessions(firstProject.ProjectId).ToArray();

    AssertEqual(2, firstProjectSessions.Length);
    AssertTrue(firstProjectSessions.All(session => session.ProjectId == firstProject.ProjectId));
    AssertTrue(firstProjectSessions.Any(session => session.SessionId == firstSession.Identity.SessionId));
    AssertTrue(firstProjectSessions.Any(session => session.SessionId == secondSession.Identity.SessionId));
    AssertFalse(firstProjectSessions.Any(session => session.SessionId == otherSession.Identity.SessionId));
    AssertEqual(firstExpiry, firstSession.Identity.ExpiresAtUtc);
    AssertEqual(DateTimeOffset.Parse("2026-06-09T00:00:00Z"), firstSession.Identity.LastUsedAtUtc);

    var secondProjectSessions = broker.ListProjectSessions(secondProject.ProjectId).ToArray();
    AssertEqual(1, secondProjectSessions.Length);
    AssertEqual(otherSession.Identity.SessionId, secondProjectSessions[0].SessionId);

    now = now.AddSeconds(6);
    AssertEqual(0, broker.ListProjectSessions(firstProject.ProjectId).Count);
    AssertEqual(0, broker.ListProjectSessions(secondProject.ProjectId).Count);

    var removableProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var removableSession = broker.StartSession(removableProject.ProjectId);
    AssertEqual(1, broker.ListProjectSessions(removableProject.ProjectId).Count);
    AssertTrue(broker.RemoveProject(removableProject.ProjectId));
    AssertTrue(removableSession.Identity.Revoked);
    AssertThrows<KeyNotFoundException>(() => broker.ListProjectSessions(removableProject.ProjectId));
}

static void BrokerTracksEditorBridgeStatusWithoutUpgradingSessions()
{
    var broker = new CompanionBroker();
    var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var otherProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var session = broker.StartSession(project.ProjectId);

    AssertThrows<ArgumentException>(() => broker.GetEditorBridgeStatus(string.Empty));
    AssertThrows<KeyNotFoundException>(() => broker.GetEditorBridgeStatus("project_missing"));
    AssertThrows<ArgumentException>(() =>
        broker.UpdateEditorBridgeStatus(new EditorBridgeStatus(
            EditorBridgeState.Online,
            string.Empty,
            "editor_session_1",
            "2.0.0",
            true)));
    AssertThrows<KeyNotFoundException>(() =>
        broker.UpdateEditorBridgeStatus(new EditorBridgeStatus(
            EditorBridgeState.Online,
            "project_missing",
            "editor_session_1",
            "2.0.0",
            true)));

    var defaultStatus = broker.GetEditorBridgeStatus(project.ProjectId);
    AssertEqual(EditorBridgeState.Disabled, defaultStatus.State);
    AssertEqual(project.ProjectId, defaultStatus.ProjectId);
    AssertFalse(defaultStatus.ProvidesLiveEditorState);

    var onlineStatus = new EditorBridgeStatus(
        EditorBridgeState.Online,
        project.ProjectId,
        "editor_session_1",
        "2.0.0",
        true);
    var updatedStatus = broker.UpdateEditorBridgeStatus(onlineStatus);
    AssertEqual(onlineStatus, updatedStatus);
    AssertEqual(onlineStatus, broker.GetEditorBridgeStatus(project.ProjectId));
    AssertEqual(CompanionMode.StaticHeadless, session.Identity.Mode);
    AssertEqual<string?>(null, session.Identity.EditorSessionId);
    AssertFalse(session.HasCapability(CompanionCapability.EditorScreenshot));

    var eligibility = session.EvaluateEditorLiveUpgrade(broker.GetEditorBridgeStatus(project.ProjectId));
    AssertTrue(eligibility.Eligible);
    AssertEqual(CompanionMode.StaticHeadless, session.Identity.Mode);

    session.UpgradeToEditorLive(broker.GetEditorBridgeStatus(project.ProjectId));
    AssertEqual(CompanionMode.EditorLive, session.Identity.Mode);
    AssertEqual("editor_session_1", session.Identity.EditorSessionId);

    AssertEqual(EditorBridgeState.Disabled, broker.GetEditorBridgeStatus(otherProject.ProjectId).State);
    AssertTrue(broker.RemoveProject(project.ProjectId));
    AssertThrows<KeyNotFoundException>(() => broker.GetEditorBridgeStatus(project.ProjectId));

    for (var i = 0; i < 100; i++)
    {
        var raceBroker = new CompanionBroker();
        var raceRoot = CreateTempProjectRoot();
        var raceProject = raceBroker.RegisterProject(ProjectDescriptor.FromRoot(raceRoot));
        var staleStatus = new EditorBridgeStatus(
            EditorBridgeState.Online,
            raceProject.ProjectId,
            "stale_editor_session",
            "2.0.0",
            true);

        var removeTask = Task.Run(() => raceBroker.RemoveProject(raceProject.ProjectId));
        var updateTask = Task.Run(() =>
        {
            try
            {
                raceBroker.UpdateEditorBridgeStatus(staleStatus);
            }
            catch (KeyNotFoundException)
            {
            }
        });

        Task.WaitAll(removeTask, updateTask);
        AssertTrue(removeTask.Result);
        var registeredAgain = raceBroker.RegisterProject(ProjectDescriptor.FromRoot(raceRoot));
        var statusAfterReRegister = raceBroker.GetEditorBridgeStatus(registeredAgain.ProjectId);
        AssertEqual(EditorBridgeState.Disabled, statusAfterReRegister.State);
        AssertEqual<string?>(null, statusAfterReRegister.EditorSessionId);
    }
}

static void BrokerEvaluatesStoredEditorLiveUpgradeWithoutMutatingSessions()
{
    var now = DateTimeOffset.Parse("2026-06-09T00:00:00Z");
    var broker = new CompanionBroker(TimeSpan.FromSeconds(10), () => now);
    var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var otherProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var session = broker.StartSession(project.ProjectId);
    var scope = new ToolRequestScope(project.ProjectId, session.Identity.SessionId);
    var initialIdentity = session.Identity;

    AssertThrows<InvalidOperationException>(() =>
        broker.EvaluateStoredEditorLiveUpgrade(new ToolRequestScope(otherProject.ProjectId, session.Identity.SessionId)));
    AssertThrows<KeyNotFoundException>(() =>
        broker.EvaluateStoredEditorLiveUpgrade(new ToolRequestScope(project.ProjectId, "session_missing")));

    var offline = broker.EvaluateStoredEditorLiveUpgrade(scope);
    AssertFalse(offline.Eligible);
    AssertEqual(EditorLiveUpgradeEligibilityReason.BridgeNotOnline, offline.Reason);
    AssertEqual(EditorBridgeState.Disabled, offline.BridgeStatus.State);
    AssertEqual(project.ProjectId, offline.BridgeStatus.ProjectId);
    AssertEqual(CompanionMode.StaticHeadless, session.Identity.Mode);
    AssertEqual<string?>(null, session.Identity.EditorSessionId);
    AssertEqual(initialIdentity.LastUsedAtUtc, session.Identity.LastUsedAtUtc);
    AssertEqual(initialIdentity.ExpiresAtUtc, session.Identity.ExpiresAtUtc);

    broker.UpdateEditorBridgeStatus(new EditorBridgeStatus(
        EditorBridgeState.Online,
        project.ProjectId,
        "editor_session_1",
        "2.0.0",
        true));

    now = now.AddSeconds(1);
    var eligible = broker.EvaluateStoredEditorLiveUpgrade(scope);
    AssertTrue(eligible.Eligible);
    AssertEqual(EditorLiveUpgradeEligibilityReason.Eligible, eligible.Reason);
    AssertEqual("editor_session_1", eligible.BridgeStatus.EditorSessionId);
    AssertEqual(CompanionMode.StaticHeadless, session.Identity.Mode);
    AssertEqual<string?>(null, session.Identity.EditorSessionId);
    AssertEqual(initialIdentity.LastUsedAtUtc, session.Identity.LastUsedAtUtc);
    AssertEqual(initialIdentity.ExpiresAtUtc, session.Identity.ExpiresAtUtc);
    AssertThrows<InvalidOperationException>(() =>
        broker.RequireCapability(scope, CompanionCapability.EditorScreenshot));

    broker.UpdateEditorBridgeStatus(new EditorBridgeStatus(
        EditorBridgeState.Online,
        project.ProjectId,
        "editor_session_2",
        "1.4.0",
        true));
    var incompatible = broker.EvaluateStoredEditorLiveUpgrade(scope);
    AssertFalse(incompatible.Eligible);
    AssertEqual(EditorLiveUpgradeEligibilityReason.IncompatiblePluginVersion, incompatible.Reason);

    now = now.AddSeconds(10);
    var expired = broker.EvaluateStoredEditorLiveUpgrade(scope);
    AssertFalse(expired.Eligible);
    AssertEqual(EditorLiveUpgradeEligibilityReason.SessionExpired, expired.Reason);
}

static void BrokerUpgradesSessionsToEditorLiveFromStoredBridgeStatus()
{
    var broker = new CompanionBroker();
    var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var otherProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var session = broker.StartSession(project.ProjectId);
    var otherSession = broker.StartSession(otherProject.ProjectId);
    var scope = new ToolRequestScope(project.ProjectId, session.Identity.SessionId);

    AssertThrows<InvalidOperationException>(() => broker.UpgradeSessionToEditorLive(scope));
    AssertEqual(CompanionMode.StaticHeadless, session.Identity.Mode);
    AssertEqual<string?>(null, session.Identity.EditorSessionId);

    var onlineStatus = new EditorBridgeStatus(
        EditorBridgeState.Online,
        project.ProjectId,
        "editor_session_1",
        "2.0.0",
        true);
    broker.UpdateEditorBridgeStatus(onlineStatus);

    AssertThrows<InvalidOperationException>(() =>
        broker.UpgradeSessionToEditorLive(new ToolRequestScope(otherProject.ProjectId, session.Identity.SessionId)));
    AssertEqual(CompanionMode.StaticHeadless, session.Identity.Mode);
    AssertEqual(CompanionMode.StaticHeadless, otherSession.Identity.Mode);

    var upgradedSession = broker.UpgradeSessionToEditorLive(scope);
    AssertEqual(session.Identity.SessionId, upgradedSession.Identity.SessionId);
    AssertEqual(CompanionMode.EditorLive, session.Identity.Mode);
    AssertEqual("editor_session_1", session.Identity.EditorSessionId);
    broker.RequireCapability(scope, CompanionCapability.EditorScreenshot);

    broker.UpdateEditorBridgeStatus(EditorBridgeStatus.Disabled(project.ProjectId));
    AssertEqual(CompanionMode.StaticHeadless, session.Identity.Mode);
    AssertEqual<string?>(null, session.Identity.EditorSessionId);
    AssertThrows<InvalidOperationException>(() =>
        broker.RequireCapability(scope, CompanionCapability.EditorScreenshot));

    broker.UpdateEditorBridgeStatus(onlineStatus);
    broker.UpgradeSessionToEditorLive(scope);
    AssertEqual(CompanionMode.EditorLive, session.Identity.Mode);
    broker.UpdateEditorBridgeStatus(new EditorBridgeStatus(
        EditorBridgeState.Online,
        project.ProjectId,
        "editor_session_2",
        "2.0.0",
        true));
    AssertEqual(CompanionMode.EditorLive, session.Identity.Mode);
    AssertEqual("editor_session_2", session.Identity.EditorSessionId);
    broker.RequireCapability(scope, CompanionCapability.EditorScreenshot);

    broker.UpdateEditorBridgeStatus(new EditorBridgeStatus(
        EditorBridgeState.Online,
        project.ProjectId,
        "editor_session_2",
        "1.4.0",
        true));
    AssertEqual(CompanionMode.StaticHeadless, session.Identity.Mode);
    AssertEqual<string?>(null, session.Identity.EditorSessionId);

    AssertThrows<InvalidOperationException>(() =>
        broker.UpgradeSessionToEditorLive(new ToolRequestScope(otherProject.ProjectId, otherSession.Identity.SessionId)));
    AssertEqual(CompanionMode.StaticHeadless, otherSession.Identity.Mode);

    for (var i = 0; i < 100; i++)
    {
        var raceBroker = new CompanionBroker();
        var raceProject = raceBroker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
        var raceSession = raceBroker.StartSession(raceProject.ProjectId);
        var raceScope = new ToolRequestScope(raceProject.ProjectId, raceSession.Identity.SessionId);
        var raceOnlineStatus = new EditorBridgeStatus(
            EditorBridgeState.Online,
            raceProject.ProjectId,
            "race_editor_session",
            "2.0.0",
            true);
        raceBroker.UpdateEditorBridgeStatus(raceOnlineStatus);

        var upgradeTask = Task.Run(() =>
        {
            try
            {
                raceBroker.UpgradeSessionToEditorLive(raceScope);
            }
            catch (InvalidOperationException)
            {
            }
        });
        var offlineTask = Task.Run(() => raceBroker.UpdateEditorBridgeStatus(EditorBridgeStatus.Disabled(raceProject.ProjectId)));

        Task.WaitAll(upgradeTask, offlineTask);
        var latestStatus = raceBroker.GetEditorBridgeStatus(raceProject.ProjectId);
        AssertEqual(EditorBridgeState.Disabled, latestStatus.State);
        AssertEqual(CompanionMode.StaticHeadless, raceSession.Identity.Mode);
        AssertEqual<string?>(null, raceSession.Identity.EditorSessionId);
        AssertThrows<InvalidOperationException>(() =>
            raceBroker.RequireCapability(raceScope, CompanionCapability.EditorScreenshot));
    }
}

static void BrokerRemovesProjectsAndRevokesTheirSessions()
{
    var broker = new CompanionBroker();
    var firstProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var secondProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var firstSession = broker.StartSession(firstProject.ProjectId);
    var secondSession = broker.StartSession(secondProject.ProjectId);

    AssertThrows<ArgumentException>(() => broker.RemoveProject(string.Empty));
    AssertFalse(broker.RemoveProject("project_missing"));

    AssertTrue(broker.RemoveProject(firstProject.ProjectId));

    AssertFalse(broker.Projects.Any(project => project.ProjectId == firstProject.ProjectId));
    AssertFalse(broker.ListProjects().Any(project => project.ProjectId == firstProject.ProjectId));
    AssertTrue(firstSession.Identity.Revoked);
    AssertFalse(firstSession.HasCapability(CompanionCapability.StaticProjectAnalysis));
    AssertFalse(broker.Sessions.Any(session => session.SessionId == firstSession.Identity.SessionId));
    AssertThrows<KeyNotFoundException>(() => broker.StartSession(firstProject.ProjectId));
    AssertThrows<KeyNotFoundException>(() =>
        broker.ResolveSession(new ToolRequestScope(firstProject.ProjectId, firstSession.Identity.SessionId)));

    AssertTrue(broker.Projects.Any(project => project.ProjectId == secondProject.ProjectId));
    AssertFalse(secondSession.Identity.Revoked);
    AssertTrue(broker.Sessions.Any(session => session.SessionId == secondSession.Identity.SessionId));
    var secondResolved = broker.ResolveSession(new ToolRequestScope(secondProject.ProjectId, secondSession.Identity.SessionId));
    AssertEqual(secondSession.Identity.SessionId, secondResolved.Identity.SessionId);

    AssertFalse(broker.RemoveProject(firstProject.ProjectId));
}

static void BrokerShutdownRevokesSessionsAndClearsBridgeState()
{
    var now = DateTimeOffset.Parse("2026-06-09T00:00:00Z");
    var broker = new CompanionBroker(TimeSpan.FromSeconds(10), () => now);
    var firstProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var secondProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var firstSession = broker.StartSession(firstProject.ProjectId);
    var secondSession = broker.StartSession(secondProject.ProjectId);
    broker.UpdateEditorBridgeStatus(new EditorBridgeStatus(
        EditorBridgeState.Online,
        firstProject.ProjectId,
        "editor_session_1",
        "2.0.0",
        true));
    broker.UpdateEditorBridgeStatus(new EditorBridgeStatus(
        EditorBridgeState.Online,
        secondProject.ProjectId,
        "editor_session_2",
        "2.0.0",
        true));
    now = now.AddSeconds(5);

    var shutdown = broker.Shutdown();

    AssertEqual(now, shutdown.CapturedAtUtc);
    AssertEqual(2, shutdown.RegisteredProjectCount);
    AssertEqual(2, shutdown.RevokedSessionCount);
    AssertEqual(2, shutdown.ClearedBridgeStatusCount);
    AssertTrue(firstSession.Identity.Revoked);
    AssertTrue(secondSession.Identity.Revoked);
    AssertEqual(0, broker.Sessions.Count);
    AssertEqual(2, broker.Projects.Count);
    AssertEqual(EditorBridgeState.Disabled, broker.GetEditorBridgeStatus(firstProject.ProjectId).State);
    AssertEqual(EditorBridgeState.Disabled, broker.GetEditorBridgeStatus(secondProject.ProjectId).State);
    AssertThrows<KeyNotFoundException>(() =>
        broker.ResolveSession(new ToolRequestScope(firstProject.ProjectId, firstSession.Identity.SessionId)));

    var newSession = broker.StartSession(firstProject.ProjectId);
    AssertFalse(newSession.Identity.Revoked);
    var secondShutdown = broker.Shutdown();
    AssertEqual(1, secondShutdown.RevokedSessionCount);
    AssertEqual(0, secondShutdown.ClearedBridgeStatusCount);
}

static void BrokerManifestDeclaresShutdownContract()
{
    var manifestPath = FindRepositoryFile(Path.Combine("companion", "contracts", "v2-broker-manifest.json"));
    using var manifest = JsonDocument.Parse(File.ReadAllText(manifestPath));
    var shutdown = manifest.RootElement.GetProperty("broker_shutdown");

    AssertTrue(shutdown.GetProperty("explicit_shutdown_supported").GetBoolean());
    AssertTrue(shutdown.GetProperty("shutdown_revokes_sessions").GetBoolean());
    AssertTrue(shutdown.GetProperty("shutdown_clears_bridge_status").GetBoolean());
    AssertFalse(shutdown.GetProperty("shutdown_removes_registered_projects").GetBoolean());
    AssertFalse(shutdown.GetProperty("shutdown_scans_filesystem").GetBoolean());
    AssertFalse(shutdown.GetProperty("shutdown_launches_godot_editor").GetBoolean());
    AssertTrue(shutdown.GetProperty("reports_revoked_session_count").GetBoolean());
    AssertTrue(shutdown.GetProperty("reports_cleared_bridge_status_count").GetBoolean());
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

static void BrokerEvaluatesToolAvailabilityWithoutRenewingSessions()
{
    var now = DateTimeOffset.Parse("2026-06-09T00:00:00Z");
    var broker = new CompanionBroker(TimeSpan.FromSeconds(10), () => now);
    var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var otherProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var session = broker.StartSession(project.ProjectId);
    var scope = new ToolRequestScope(project.ProjectId, session.Identity.SessionId);
    var initialIdentity = session.Identity;

    AssertThrows<ArgumentException>(() =>
        broker.EvaluateToolAvailability(scope, " ", CompanionCapability.StaticProjectAnalysis));

    var staticTool = broker.EvaluateToolAvailability(
        scope,
        "  static.resource_graph  ",
        CompanionCapability.ResourceGraphAnalysis);
    AssertTrue(staticTool.Available);
    AssertEqual("static.resource_graph", staticTool.ToolName);
    AssertEqual(ToolScopeValidationReason.Accepted, staticTool.Reason);
    AssertEqual(CompanionCapability.ResourceGraphAnalysis, staticTool.RequiredCapability);
    AssertEqual(session.Identity.SessionId, staticTool.Session?.SessionId);
    AssertTrue(staticTool.Capabilities.Contains(CompanionCapability.StaticProjectAnalysis));
    AssertTrue(staticTool.Capabilities.Contains(CompanionCapability.ResourceGraphAnalysis));
    AssertFalse(staticTool.Capabilities.Contains(CompanionCapability.EditorScreenshot));
    AssertEqual(initialIdentity.LastUsedAtUtc, session.Identity.LastUsedAtUtc);
    AssertEqual(initialIdentity.ExpiresAtUtc, session.Identity.ExpiresAtUtc);

    var liveToolBeforeUpgrade = broker.EvaluateToolAvailability(
        scope,
        "editor.capture",
        CompanionCapability.EditorScreenshot);
    AssertFalse(liveToolBeforeUpgrade.Available);
    AssertEqual(ToolScopeValidationReason.CapabilityUnavailable, liveToolBeforeUpgrade.Reason);
    AssertEqual(session.Identity.SessionId, liveToolBeforeUpgrade.Session?.SessionId);
    AssertFalse(liveToolBeforeUpgrade.Capabilities.Contains(CompanionCapability.EditorScreenshot));
    AssertEqual(initialIdentity.LastUsedAtUtc, session.Identity.LastUsedAtUtc);
    AssertEqual(initialIdentity.ExpiresAtUtc, session.Identity.ExpiresAtUtc);

    var crossProject = broker.EvaluateToolAvailability(
        new ToolRequestScope(otherProject.ProjectId, session.Identity.SessionId),
        "static.resource_graph",
        CompanionCapability.ResourceGraphAnalysis);
    AssertFalse(crossProject.Available);
    AssertEqual(ToolScopeValidationReason.ProjectSessionMismatch, crossProject.Reason);
    AssertEqual<ProjectSessionIdentity?>(null, crossProject.Session);
    AssertEqual(0, crossProject.Capabilities.Count);

    broker.UpdateEditorBridgeStatus(new EditorBridgeStatus(
        EditorBridgeState.Online,
        project.ProjectId,
        "editor_session_1",
        "2.0.0",
        true));
    broker.UpgradeSessionToEditorLive(scope);
    var liveTool = broker.EvaluateToolAvailability(
        scope,
        "editor.capture",
        CompanionCapability.EditorScreenshot);
    AssertTrue(liveTool.Available);
    AssertEqual(CompanionMode.EditorLive, liveTool.Session?.Mode);
    AssertTrue(liveTool.Capabilities.Contains(CompanionCapability.EditorScreenshot));

    now = now.AddSeconds(11);
    var expiredTool = broker.EvaluateToolAvailability(
        scope,
        "editor.capture",
        CompanionCapability.EditorScreenshot);
    AssertFalse(expiredTool.Available);
    AssertEqual(ToolScopeValidationReason.ExpiredSession, expiredTool.Reason);
    AssertEqual(session.Identity.SessionId, expiredTool.Session?.SessionId);
    AssertEqual(0, expiredTool.Capabilities.Count);
}

static void BrokerManifestDeclaresToolAvailabilityPreflight()
{
    var manifestPath = FindRepositoryFile(Path.Combine("companion", "contracts", "v2-broker-manifest.json"));
    using var manifest = JsonDocument.Parse(File.ReadAllText(manifestPath));
    var toolAvailability = manifest.RootElement.GetProperty("tool_availability");

    AssertTrue(toolAvailability.GetProperty("preflight_supported").GetBoolean());
    AssertFalse(toolAvailability.GetProperty("preflight_renews_sessions").GetBoolean());
    AssertTrue(toolAvailability.GetProperty("requires_project_id").GetBoolean());
    AssertTrue(toolAvailability.GetProperty("requires_session_id").GetBoolean());
    AssertTrue(toolAvailability.GetProperty("reports_required_capability").GetBoolean());
    AssertTrue(toolAvailability.GetProperty("reports_current_capabilities").GetBoolean());
    AssertTrue(toolAvailability.GetProperty("rejects_cross_project_session").GetBoolean());
}

static void ReportsSessionCapabilitiesWithoutRenewingLeases()
{
    var now = DateTimeOffset.Parse("2026-06-09T00:00:00Z");
    var broker = new CompanionBroker(TimeSpan.FromSeconds(10), () => now);
    var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var otherProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var session = broker.StartSession(project.ProjectId);
    var scope = new ToolRequestScope(project.ProjectId, session.Identity.SessionId);
    var initialIdentity = session.Identity;

    AssertThrows<ArgumentException>(() => broker.GetSessionCapabilities(new ToolRequestScope(string.Empty, session.Identity.SessionId)));
    AssertThrows<ArgumentException>(() => broker.GetSessionCapabilities(new ToolRequestScope(project.ProjectId, string.Empty)));
    AssertThrows<KeyNotFoundException>(() => broker.GetSessionCapabilities(new ToolRequestScope(project.ProjectId, "session_missing")));
    AssertThrows<InvalidOperationException>(() =>
        broker.GetSessionCapabilities(new ToolRequestScope(otherProject.ProjectId, session.Identity.SessionId)));

    var staticSnapshot = broker.GetSessionCapabilities(scope);
    AssertEqual(session.Identity.SessionId, staticSnapshot.Session.SessionId);
    AssertEqual(CompanionMode.StaticHeadless, staticSnapshot.Session.Mode);
    AssertTrue(staticSnapshot.Capabilities.Contains(CompanionCapability.StaticProjectAnalysis));
    AssertTrue(staticSnapshot.Capabilities.Contains(CompanionCapability.DotnetWorkspaceAnalysis));
    AssertTrue(staticSnapshot.Capabilities.Contains(CompanionCapability.ResourceGraphAnalysis));
    AssertFalse(staticSnapshot.Capabilities.Contains(CompanionCapability.EditorScreenshot));
    AssertThrows<NotSupportedException>(() =>
        ((IList<CompanionCapability>)staticSnapshot.Capabilities)[0] = CompanionCapability.EditorScreenshot);
    AssertEqual(initialIdentity.LastUsedAtUtc, session.Identity.LastUsedAtUtc);
    AssertEqual(initialIdentity.ExpiresAtUtc, session.Identity.ExpiresAtUtc);

    broker.UpdateEditorBridgeStatus(new EditorBridgeStatus(
        EditorBridgeState.Online,
        project.ProjectId,
        "editor_session_1",
        "2.0.0",
        true));
    broker.UpgradeSessionToEditorLive(scope);
    var liveSnapshot = broker.GetSessionCapabilities(scope);
    AssertEqual(CompanionMode.EditorLive, liveSnapshot.Session.Mode);
    AssertTrue(liveSnapshot.Capabilities.Contains(CompanionCapability.EditorSelection));
    AssertTrue(liveSnapshot.Capabilities.Contains(CompanionCapability.InspectorState));
    AssertTrue(liveSnapshot.Capabilities.Contains(CompanionCapability.DockState));
    AssertTrue(liveSnapshot.Capabilities.Contains(CompanionCapability.EditorScreenshot));
    AssertTrue(liveSnapshot.Capabilities.Contains(CompanionCapability.RuntimeValidation));

    broker.UpdateEditorBridgeStatus(EditorBridgeStatus.Disabled(project.ProjectId));
    var downgradedSnapshot = broker.GetSessionCapabilities(scope);
    AssertEqual(CompanionMode.StaticHeadless, downgradedSnapshot.Session.Mode);
    AssertFalse(downgradedSnapshot.Capabilities.Contains(CompanionCapability.EditorScreenshot));

    var stoppedProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var stoppedSession = broker.StartSession(stoppedProject.ProjectId);
    var stoppedScope = new ToolRequestScope(stoppedProject.ProjectId, stoppedSession.Identity.SessionId);
    AssertTrue(broker.StopSession(stoppedScope));
    AssertThrows<KeyNotFoundException>(() => broker.GetSessionCapabilities(stoppedScope));

    now = now.AddSeconds(11);
    var expiredSnapshot = broker.GetSessionCapabilities(scope);
    AssertEqual(0, expiredSnapshot.Capabilities.Count);
    AssertEqual(initialIdentity.ExpiresAtUtc, session.Identity.ExpiresAtUtc);
}

static void BrokerReportsSessionHealthWithoutRenewingLeases()
{
    var now = DateTimeOffset.Parse("2026-06-09T00:00:00Z");
    var broker = new CompanionBroker(TimeSpan.FromSeconds(10), () => now);
    var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var otherProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var session = broker.StartSession(project.ProjectId);
    var scope = new ToolRequestScope(project.ProjectId, session.Identity.SessionId);
    var initialIdentity = session.Identity;

    var missingProject = broker.EvaluateSessionHealth(new ToolRequestScope(string.Empty, session.Identity.SessionId));
    AssertFalse(missingProject.Available);
    AssertEqual(SessionHealthState.MissingProjectId, missingProject.State);
    AssertEqual<ProjectSessionIdentity?>(null, missingProject.Session);
    AssertEqual<EditorBridgeStatus?>(null, missingProject.BridgeStatus);

    var missingSession = broker.EvaluateSessionHealth(new ToolRequestScope(project.ProjectId, string.Empty));
    AssertFalse(missingSession.Available);
    AssertEqual(SessionHealthState.MissingSessionId, missingSession.State);

    var unknownProject = broker.EvaluateSessionHealth(new ToolRequestScope("project_missing", session.Identity.SessionId));
    AssertFalse(unknownProject.Available);
    AssertEqual(SessionHealthState.UnknownProjectId, unknownProject.State);
    AssertEqual<EditorBridgeStatus?>(null, unknownProject.BridgeStatus);

    var unknownSession = broker.EvaluateSessionHealth(new ToolRequestScope(project.ProjectId, "session_missing"));
    AssertFalse(unknownSession.Available);
    AssertEqual(SessionHealthState.UnknownSessionId, unknownSession.State);
    AssertEqual(EditorBridgeState.Disabled, unknownSession.BridgeStatus?.State);
    AssertEqual(project.ProjectId, unknownSession.BridgeStatus?.ProjectId);

    var crossProject = broker.EvaluateSessionHealth(new ToolRequestScope(otherProject.ProjectId, session.Identity.SessionId));
    AssertFalse(crossProject.Available);
    AssertEqual(SessionHealthState.ProjectSessionMismatch, crossProject.State);
    AssertEqual<ProjectSessionIdentity?>(null, crossProject.Session);
    AssertEqual(0, crossProject.Capabilities.Count);
    AssertEqual(EditorBridgeState.Disabled, crossProject.BridgeStatus?.State);
    AssertEqual(otherProject.ProjectId, crossProject.BridgeStatus?.ProjectId);

    var staticHealth = broker.EvaluateSessionHealth(scope);
    AssertTrue(staticHealth.Available);
    AssertEqual(SessionHealthState.StaticHeadless, staticHealth.State);
    AssertEqual(session.Identity.SessionId, staticHealth.Session?.SessionId);
    AssertEqual(EditorBridgeState.Disabled, staticHealth.BridgeStatus?.State);
    AssertFalse(staticHealth.EditorLiveUpgrade?.Eligible ?? true);
    AssertEqual(EditorLiveUpgradeEligibilityReason.BridgeNotOnline, staticHealth.EditorLiveUpgrade?.Reason);
    AssertTrue(staticHealth.Capabilities.Contains(CompanionCapability.StaticProjectAnalysis));
    AssertFalse(staticHealth.Capabilities.Contains(CompanionCapability.EditorScreenshot));
    AssertEqual(initialIdentity.LastUsedAtUtc, session.Identity.LastUsedAtUtc);
    AssertEqual(initialIdentity.ExpiresAtUtc, session.Identity.ExpiresAtUtc);

    broker.UpdateEditorBridgeStatus(new EditorBridgeStatus(
        EditorBridgeState.Online,
        project.ProjectId,
        "editor_session_1",
        "2.0.0",
        true));
    var eligibleHealth = broker.EvaluateSessionHealth(scope);
    AssertTrue(eligibleHealth.Available);
    AssertEqual(SessionHealthState.StaticHeadless, eligibleHealth.State);
    AssertTrue(eligibleHealth.EditorLiveUpgrade?.Eligible ?? false);
    AssertEqual(EditorLiveUpgradeEligibilityReason.Eligible, eligibleHealth.EditorLiveUpgrade?.Reason);
    AssertFalse(eligibleHealth.Capabilities.Contains(CompanionCapability.EditorScreenshot));
    AssertEqual(initialIdentity.LastUsedAtUtc, session.Identity.LastUsedAtUtc);
    AssertEqual(initialIdentity.ExpiresAtUtc, session.Identity.ExpiresAtUtc);

    broker.UpgradeSessionToEditorLive(scope);
    var liveHealth = broker.EvaluateSessionHealth(scope);
    AssertTrue(liveHealth.Available);
    AssertEqual(SessionHealthState.EditorLive, liveHealth.State);
    AssertEqual(CompanionMode.EditorLive, liveHealth.Session?.Mode);
    AssertEqual("editor_session_1", liveHealth.Session?.EditorSessionId);
    AssertTrue(liveHealth.Capabilities.Contains(CompanionCapability.EditorScreenshot));

    now = now.AddSeconds(11);
    var expiredHealth = broker.EvaluateSessionHealth(scope);
    AssertFalse(expiredHealth.Available);
    AssertEqual(SessionHealthState.ExpiredSession, expiredHealth.State);
    AssertEqual(session.Identity.SessionId, expiredHealth.Session?.SessionId);
    AssertEqual(0, expiredHealth.Capabilities.Count);
    AssertFalse(expiredHealth.EditorLiveUpgrade?.Eligible ?? true);
    AssertEqual(EditorLiveUpgradeEligibilityReason.SessionExpired, expiredHealth.EditorLiveUpgrade?.Reason);
}

static void BrokerManifestDeclaresSessionHealthSnapshot()
{
    var manifestPath = FindRepositoryFile(Path.Combine("companion", "contracts", "v2-broker-manifest.json"));
    using var manifest = JsonDocument.Parse(File.ReadAllText(manifestPath));
    var sessionHealth = manifest.RootElement.GetProperty("session_health");

    AssertTrue(sessionHealth.GetProperty("snapshot_supported").GetBoolean());
    AssertFalse(sessionHealth.GetProperty("snapshot_renews_sessions").GetBoolean());
    AssertTrue(sessionHealth.GetProperty("requires_project_id").GetBoolean());
    AssertTrue(sessionHealth.GetProperty("requires_session_id").GetBoolean());
    AssertTrue(sessionHealth.GetProperty("reports_bridge_status").GetBoolean());
    AssertTrue(sessionHealth.GetProperty("reports_editor_live_upgrade_eligibility").GetBoolean());
    AssertTrue(sessionHealth.GetProperty("reports_current_capabilities").GetBoolean());
    AssertTrue(sessionHealth.GetProperty("rejects_cross_project_session").GetBoolean());
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

static void SessionHealthUsesOneClockSnapshot()
{
    var reads = -1;
    var clockReads = new[]
    {
        DateTimeOffset.Parse("2026-06-09T00:00:00Z"),
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
    broker.UpdateEditorBridgeStatus(new EditorBridgeStatus(
        EditorBridgeState.Online,
        project.ProjectId,
        "editor_session_1",
        "2.0.0",
        true));
    AssertEqual(DateTimeOffset.Parse("2026-06-09T00:00:10Z"), session.Identity.ExpiresAtUtc);

    var health = broker.EvaluateSessionHealth(new ToolRequestScope(project.ProjectId, session.Identity.SessionId));

    AssertTrue(health.Available);
    AssertEqual(SessionHealthState.StaticHeadless, health.State);
    AssertTrue(health.EditorLiveUpgrade?.Eligible ?? false);
    AssertEqual(EditorLiveUpgradeEligibilityReason.Eligible, health.EditorLiveUpgrade?.Reason);
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

static void ToolAvailabilitySnapshotsStayConsistentUnderStopConcurrency()
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
        var availabilityTask = Task.Run(() =>
        {
            try
            {
                return broker.EvaluateToolAvailability(
                    scope,
                    "static.resource_graph",
                    CompanionCapability.ResourceGraphAnalysis);
            }
            catch (KeyNotFoundException)
            {
                return null;
            }
            catch (InvalidOperationException)
            {
                return null;
            }
        });

        Task.WaitAll(stopTask, availabilityTask);
        var availability = availabilityTask.Result;
        if (availability is not null && availability.Available)
        {
            AssertEqual(session.Identity.SessionId, availability.Session?.SessionId);
            AssertTrue(availability.Capabilities.Contains(CompanionCapability.ResourceGraphAnalysis));
        }

        AssertFalse(broker.Sessions.Any(current => current.SessionId == session.Identity.SessionId));
    }
}

static void EditorLiveUpgradeEligibilityDoesNotMutateSession()
{
    var now = DateTimeOffset.Parse("2026-06-09T00:00:00Z");
    var broker = new CompanionBroker(TimeSpan.FromSeconds(10), () => now);
    var project = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var otherProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var session = broker.StartSession(project.ProjectId);
    var initialIdentity = session.Identity;

    var eligibleBridge = new EditorBridgeStatus(
        EditorBridgeState.Online,
        project.ProjectId,
        "editor_session_1",
        "2.0.0",
        true);
    var eligible = session.EvaluateEditorLiveUpgrade(eligibleBridge);

    AssertTrue(eligible.Eligible);
    AssertEqual(EditorLiveUpgradeEligibilityReason.Eligible, eligible.Reason);
    AssertEqual(initialIdentity.SessionId, eligible.Session.SessionId);
    AssertEqual(eligibleBridge, eligible.BridgeStatus);
    AssertEqual(CompanionMode.StaticHeadless, session.Identity.Mode);
    AssertEqual<string?>(null, session.Identity.EditorSessionId);
    AssertEqual(initialIdentity.LastUsedAtUtc, session.Identity.LastUsedAtUtc);
    AssertEqual(initialIdentity.ExpiresAtUtc, session.Identity.ExpiresAtUtc);
    AssertThrows<InvalidOperationException>(() =>
        broker.RequireCapability(
            new ToolRequestScope(project.ProjectId, session.Identity.SessionId),
            CompanionCapability.EditorScreenshot));

    var offline = session.EvaluateEditorLiveUpgrade(EditorBridgeStatus.Disabled(project.ProjectId));
    AssertFalse(offline.Eligible);
    AssertEqual(EditorLiveUpgradeEligibilityReason.BridgeNotOnline, offline.Reason);
    AssertEqual(CompanionMode.StaticHeadless, session.Identity.Mode);

    var mismatch = session.EvaluateEditorLiveUpgrade(new EditorBridgeStatus(
        EditorBridgeState.Online,
        otherProject.ProjectId,
        "editor_session_2",
        "2.0.0",
        true));
    AssertFalse(mismatch.Eligible);
    AssertEqual(EditorLiveUpgradeEligibilityReason.ProjectMismatch, mismatch.Reason);

    var missingLiveState = session.EvaluateEditorLiveUpgrade(new EditorBridgeStatus(
        EditorBridgeState.Online,
        project.ProjectId,
        "editor_session_3",
        "2.0.0",
        false));
    AssertFalse(missingLiveState.Eligible);
    AssertEqual(EditorLiveUpgradeEligibilityReason.LiveEditorStateUnavailable, missingLiveState.Reason);

    var badVersion = session.EvaluateEditorLiveUpgrade(new EditorBridgeStatus(
        EditorBridgeState.Online,
        project.ProjectId,
        "editor_session_4",
        "1.4.0",
        true));
    AssertFalse(badVersion.Eligible);
    AssertEqual(EditorLiveUpgradeEligibilityReason.IncompatiblePluginVersion, badVersion.Reason);

    now = now.AddSeconds(11);
    var expired = session.EvaluateEditorLiveUpgrade(eligibleBridge);
    AssertFalse(expired.Eligible);
    AssertEqual(EditorLiveUpgradeEligibilityReason.SessionExpired, expired.Reason);

    var revokedProject = broker.RegisterProject(ProjectDescriptor.FromRoot(CreateTempProjectRoot()));
    var revokedSession = broker.StartSession(revokedProject.ProjectId);
    broker.StopSession(new ToolRequestScope(revokedProject.ProjectId, revokedSession.Identity.SessionId));
    var stopped = revokedSession.EvaluateEditorLiveUpgrade(new EditorBridgeStatus(
        EditorBridgeState.Online,
        revokedProject.ProjectId,
        "editor_session_5",
        "2.0.0",
        true));
    AssertFalse(stopped.Eligible);
    AssertEqual(EditorLiveUpgradeEligibilityReason.SessionStopped, stopped.Reason);
    AssertEqual(CompanionMode.StaticHeadless, revokedSession.Identity.Mode);
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

static string FindRepositoryFile(string relativePath)
{
    var current = new DirectoryInfo(AppContext.BaseDirectory);
    while (current is not null)
    {
        var candidate = Path.Combine(current.FullName, relativePath);
        if (File.Exists(candidate))
        {
            return candidate;
        }

        current = current.Parent;
    }

    throw new FileNotFoundException($"Could not find repository file '{relativePath}'.");
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
