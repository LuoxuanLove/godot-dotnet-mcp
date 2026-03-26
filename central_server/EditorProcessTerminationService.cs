namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorProcessTerminationService
{
    private readonly EditorProcessResidencyService _residencyService;

    public EditorProcessTerminationService(EditorProcessResidencyService residencyService)
    {
        _residencyService = residencyService;
    }

    public async Task<EditorProcessService.EditorProcessStatus> WaitForExitAsync(
        string projectId,
        string? projectRoot,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        var startedAt = DateTimeOffset.UtcNow;
        while (DateTimeOffset.UtcNow - startedAt < timeout)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var status = _residencyService.GetStatus(projectId, projectRoot);
            if (!status.Running)
            {
                return status;
            }

            await Task.Delay(500, cancellationToken);
        }

        return _residencyService.GetStatus(projectId, projectRoot);
    }

    public async Task<EditorProcessService.EditorForceStopResult> ForceStopTrackedProcessAsync(
        string projectId,
        string? projectRoot,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        var entry = _residencyService.GetResidency(projectId, projectRoot);
        if (entry is null)
        {
            return new EditorProcessService.EditorForceStopResult
            {
                Success = false,
                ErrorType = "editor_process_not_found",
                Message = "No host-managed editor process is tracked for this project.",
                Process = EditorProcessService.EditorProcessStatus.Empty(projectId, _residencyService.StorePath),
            };
        }

        if (!EditorProcessSupport.TryGetLiveProcess(entry.ProcessId, out var process))
        {
            _residencyService.RemoveResidency(entry.ProjectId);
            return new EditorProcessService.EditorForceStopResult
            {
                Success = true,
                Process = EditorProcessService.EditorProcessStatus.Empty(projectId, _residencyService.StorePath),
            };
        }

        using (process!)
        {
            process!.Kill(entireProcessTree: true);
        }

        var finalStatus = await WaitForExitAsync(projectId, projectRoot, timeout, cancellationToken);
        if (finalStatus.Running)
        {
            return new EditorProcessService.EditorForceStopResult
            {
                Success = false,
                ErrorType = "editor_close_timeout",
                Message = $"Timed out waiting for the tracked editor process to exit after {timeout.TotalMilliseconds:F0} ms.",
                Process = finalStatus,
            };
        }

        _residencyService.RemoveResidency(entry.ProjectId);
        return new EditorProcessService.EditorForceStopResult
        {
            Success = true,
            Process = finalStatus,
        };
    }
}
