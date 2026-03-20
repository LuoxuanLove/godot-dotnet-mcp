using GodotDotnetMcp.CentralServer;

try
{
    var exitCode = await CentralServerApplication.RunAsync(
        args,
        Console.OpenStandardInput(),
        Console.OpenStandardOutput(),
        Console.Error);
    Environment.ExitCode = exitCode;
}
catch (Exception ex)
{
    await Console.Error.WriteLineAsync("Fatal central server error:");
    await Console.Error.WriteLineAsync(ex.ToString());
    Environment.ExitCode = 1;
}
