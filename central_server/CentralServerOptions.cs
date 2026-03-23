namespace GodotDotnetMcp.CentralServer;

internal enum CentralServerMode
{
    Stdio,
    AttachOnly,
    ProxyCall,
    SmokeSystemSession,
    InstallPlugin,
    Health,
    Version,
    Help,
}

internal sealed record CentralServerOptions(CentralServerMode Mode, string[] RemainingArguments)
{
    public static CentralServerOptions Parse(string[] args)
    {
        if (args.Length == 0)
        {
            return new CentralServerOptions(CentralServerMode.Stdio, []);
        }

        var remaining = new List<string>();
        var mode = CentralServerMode.Stdio;

        foreach (var arg in args)
        {
            switch (arg)
            {
                case "--stdio":
                    mode = CentralServerMode.Stdio;
                    break;
                case "--attach-only":
                    mode = CentralServerMode.AttachOnly;
                    break;
                case "--proxy-call":
                    mode = CentralServerMode.ProxyCall;
                    break;
                case "--smoke-system-session":
                    mode = CentralServerMode.SmokeSystemSession;
                    break;
                case "--install-plugin":
                    mode = CentralServerMode.InstallPlugin;
                    break;
                case "--health":
                    mode = CentralServerMode.Health;
                    break;
                case "--version":
                case "-v":
                    mode = CentralServerMode.Version;
                    break;
                case "--help":
                case "-h":
                case "/?":
                    mode = CentralServerMode.Help;
                    break;
                default:
                    remaining.Add(arg);
                    break;
            }
        }

        return new CentralServerOptions(mode, remaining.ToArray());
    }
}
