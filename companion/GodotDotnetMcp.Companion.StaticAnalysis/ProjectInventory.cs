using GodotDotnetMcp.Companion;

namespace GodotDotnetMcp.Companion.StaticAnalysis;

public sealed record ProjectInventory(
    string ProjectRoot,
    string? ProjectId,
    bool IsGodotProject,
    string ProjectFilePath,
    IReadOnlyList<string> CSharpProjectFiles,
    IReadOnlyList<CSharpProjectScope> CSharpProjectScopes,
    CSharpProjectScope? DefaultCSharpProjectScope,
    ProjectScopeSelection ProjectScopeSelection,
    DotnetWorkspaceGraph DotnetWorkspace,
    ResourceReferenceGraph ResourceReferences,
    bool HasPluginDirectory,
    CompanionMode Mode,
    IReadOnlyList<ProjectCapabilityStatus> Capabilities)
{
    public bool HasCSharpProject => CSharpProjectFiles.Count > 0;

    public bool HasCapability(CompanionCapability capability)
    {
        return Capabilities.Any(status => status.Capability == capability && status.Available);
    }

    public ProjectCapabilityStatus GetCapability(CompanionCapability capability)
    {
        return Capabilities.Single(status => status.Capability == capability);
    }
}

public sealed record ProjectCapabilityStatus(
    CompanionCapability Capability,
    CompanionMode Mode,
    bool Available,
    string Reason);

public sealed record CSharpProjectScope(
    string ProjectFilePath,
    string ProjectId);

public sealed record ProjectScopeSelection(
    bool RequiresExplicitSelection,
    int CandidateCount,
    string Reason);
