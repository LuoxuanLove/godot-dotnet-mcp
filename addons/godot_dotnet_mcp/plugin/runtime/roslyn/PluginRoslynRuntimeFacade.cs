using Godot;
using Godot.Collections;

[Tool]
[GlobalClass]
public partial class PluginRoslynRuntimeFacade : RefCounted
{
    public Dictionary get_capabilities()
    {
        return RoslynFacadeRuntimeCore.get_capabilities();
    }

    public Dictionary parse_file(string scriptPath, string sourceText = "")
    {
        return RoslynFacadeRuntimeCore.parse_file(scriptPath, sourceText);
    }

    public Dictionary patch_file(string scriptPath, Dictionary request)
    {
        return RoslynFacadeRuntimeCore.patch_file(scriptPath, request);
    }
}
