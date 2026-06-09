using System.Collections.Frozen;

namespace GodotDotnetMcp.Companion;

public enum CompanionMode
{
    StaticHeadless,
    EditorLive,
}

public enum CompanionCapability
{
    StaticProjectAnalysis,
    DotnetWorkspaceAnalysis,
    ResourceGraphAnalysis,
    EditorSelection,
    InspectorState,
    DockState,
    EditorScreenshot,
    RuntimeValidation,
}

public static class CompanionCapabilityCatalog
{
    private static readonly FrozenSet<CompanionCapability> StaticCapabilities =
        new[]
        {
            CompanionCapability.StaticProjectAnalysis,
            CompanionCapability.DotnetWorkspaceAnalysis,
            CompanionCapability.ResourceGraphAnalysis,
        }.ToFrozenSet();

    private static readonly FrozenSet<CompanionCapability> EditorLiveCapabilities =
        StaticCapabilities.Concat(
        [
            CompanionCapability.EditorSelection,
            CompanionCapability.InspectorState,
            CompanionCapability.DockState,
            CompanionCapability.EditorScreenshot,
            CompanionCapability.RuntimeValidation,
        ]).ToFrozenSet();

    public static IReadOnlySet<CompanionCapability> ForMode(CompanionMode mode)
    {
        return mode switch
        {
            CompanionMode.StaticHeadless => StaticCapabilities,
            CompanionMode.EditorLive => EditorLiveCapabilities,
            _ => throw new ArgumentOutOfRangeException(nameof(mode), mode, "Unknown companion mode."),
        };
    }
}
