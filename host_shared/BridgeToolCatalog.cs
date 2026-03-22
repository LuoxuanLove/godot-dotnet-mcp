namespace GodotDotnetMcp.HostShared;

internal static class BridgeToolCatalog
{
    public static IReadOnlyList<object> GetTools()
    {
        return
        [
            CreateDotnetBuildTool(),
            CreateCsprojReadTool(),
            CreateCsFileReadTool(),
            CreateCsDiagnosticsTool(),
            CreateSolutionAnalyzeTool(),
            CreateCsprojWriteTool(),
            CreateCsFilePatchTool(),
        ];
    }

    private static object CreateDotnetBuildTool()
    {
        return new
        {
            name = "dotnet_build",
            description = "Run dotnet restore/build/test for a project or solution and return structured diagnostics.",
            inputSchema = new
            {
                type = "object",
                properties = new
                {
                    path = new { type = "string", description = "Path to a .csproj or .sln file." },
                    operation = new { type = "string", @enum = new[] { "restore", "build", "test" }, description = "dotnet operation to run. Defaults to build." },
                    configuration = new { type = "string", description = "MSBuild configuration, such as Debug or Release." },
                    framework = new { type = "string", description = "Optional target framework override." },
                    verbosity = new { type = "string", @enum = new[] { "quiet", "minimal", "normal", "detailed", "diagnostic" }, description = "dotnet verbosity. Defaults to minimal." },
                },
                required = new[] { "path" },
                additionalProperties = false,
            },
        };
    }

    private static object CreateCsprojReadTool()
    {
        return new
        {
            name = "csproj_read",
            description = "Read a .csproj file and return target framework, references, and property groups.",
            inputSchema = new
            {
                type = "object",
                properties = new
                {
                    path = new { type = "string", description = "Path to a .csproj file." },
                },
                required = new[] { "path" },
                additionalProperties = false,
            },
        };
    }

    private static object CreateCsFileReadTool()
    {
        return new
        {
            name = "cs_file_read",
            description = "Read a C# source file and return namespaces, types, methods, and using directives.",
            inputSchema = new
            {
                type = "object",
                properties = new
                {
                    path = new { type = "string", description = "Path to a .cs file." },
                },
                required = new[] { "path" },
                additionalProperties = false,
            },
        };
    }

    private static object CreateCsDiagnosticsTool()
    {
        return new
        {
            name = "cs_diagnostics",
            description = "Build the nearest project and return structured diagnostics for the requested C# file or project.",
            inputSchema = new
            {
                type = "object",
                properties = new
                {
                    path = new { type = "string", description = "Path to a .cs, .csproj, or .sln file." },
                    projectPath = new { type = "string", description = "Optional explicit project file path to build." },
                },
                required = new[] { "path" },
                additionalProperties = false,
            },
        };
    }

    private static object CreateSolutionAnalyzeTool()
    {
        return new
        {
            name = "solution_analyze",
            description = "Analyze a .sln file and its referenced projects to produce a dependency graph.",
            inputSchema = new
            {
                type = "object",
                properties = new
                {
                    path = new { type = "string", description = "Path to a .sln file, or a directory containing one." },
                },
                required = new[] { "path" },
                additionalProperties = false,
            },
        };
    }

    private static object CreateCsprojWriteTool()
    {
        return new
        {
            name = "csproj_write",
            description = "Safely update a .csproj file with property, package reference, and project reference changes.",
            inputSchema = new
            {
                type = "object",
                properties = new
                {
                    path = new { type = "string", description = "Path to a .csproj file." },
                    dryRun = new { type = "boolean", description = "Preview changes without writing. Defaults to true." },
                    properties = new
                    {
                        type = "object",
                        description = "Project properties to add or update.",
                        additionalProperties = new { type = "string" },
                    },
                    removeProperties = new { type = "array", items = new { type = "string" }, description = "Project properties to remove." },
                    packageReferences = new
                    {
                        type = "object",
                        properties = new
                        {
                            add = new
                            {
                                type = "array",
                                items = new
                                {
                                    type = "object",
                                    properties = new
                                    {
                                        include = new { type = "string" },
                                        version = new { type = "string" },
                                    },
                                    required = new[] { "include" },
                                    additionalProperties = false,
                                },
                            },
                            update = new
                            {
                                type = "array",
                                items = new
                                {
                                    type = "object",
                                    properties = new
                                    {
                                        include = new { type = "string" },
                                        version = new { type = "string" },
                                        condition = new { type = "string" },
                                        metadata = new { type = "object", additionalProperties = new { type = "string" } },
                                    },
                                    required = new[] { "include" },
                                    additionalProperties = false,
                                },
                            },
                            remove = new { type = "array", items = new { type = "string" } },
                        },
                        additionalProperties = false,
                    },
                    projectReferences = new
                    {
                        type = "object",
                        properties = new
                        {
                            add = new
                            {
                                type = "array",
                                items = new
                                {
                                    type = "object",
                                    properties = new
                                    {
                                        include = new { type = "string" },
                                    },
                                    required = new[] { "include" },
                                    additionalProperties = false,
                                },
                            },
                            update = new
                            {
                                type = "array",
                                items = new
                                {
                                    type = "object",
                                    properties = new
                                    {
                                        include = new { type = "string" },
                                        condition = new { type = "string" },
                                        metadata = new { type = "object", additionalProperties = new { type = "string" } },
                                    },
                                    required = new[] { "include" },
                                    additionalProperties = false,
                                },
                            },
                            remove = new { type = "array", items = new { type = "string" } },
                        },
                        additionalProperties = false,
                    },
                    targetFramework = new { type = "string", description = "Set TargetFramework and clear TargetFrameworks when used alone." },
                    targetFrameworks = new { type = "array", items = new { type = "string" }, description = "Set TargetFrameworks for multi-targeting." },
                },
                required = new[] { "path" },
                additionalProperties = false,
            },
        };
    }

    private static object CreateCsFilePatchTool()
    {
        return new
        {
            name = "cs_file_patch",
            description = "Apply conservative text patches to a C# file with dry-run and conflict detection support.",
            inputSchema = new
            {
                type = "object",
                properties = new
                {
                    path = new { type = "string", description = "Path to a .cs file." },
                    dryRun = new { type = "boolean", description = "Preview changes without writing. Defaults to true." },
                    patches = new
                    {
                        type = "array",
                        items = new
                        {
                            type = "object",
                            properties = new
                            {
                                kind = new { type = "string", @enum = new[] { "replace", "remove", "insert_before", "insert_after", "method_upsert", "method_remove", "field_upsert", "field_remove" } },
                                find = new { type = "string", description = "Text to find for replace/remove operations." },
                                replacement = new { type = "string", description = "Replacement text for replace operations." },
                                anchor = new { type = "string", description = "Anchor text for insert operations." },
                                text = new { type = "string", description = "Text to insert for insert operations." },
                                occurrence = new { type = "string", @enum = new[] { "first", "last", "all" }, description = "Which match to use. Defaults to first." },
                                expectedCount = new { type = "integer", description = "Optional expected number of matches for conflict detection." },
                                typeName = new { type = "string", description = "Type name for semantic member patches." },
                                memberName = new { type = "string", description = "Method or field name for semantic member patches." },
                                modifiers = new { type = "array", items = new { type = "string" }, description = "Modifiers such as public/private/static." },
                                returnType = new { type = "string", description = "Return type for method_upsert." },
                                parameters = new { type = "array", items = new { type = "string" }, description = "Method parameter fragments for semantic matching." },
                                body = new { type = "string", description = "Method body for method_upsert." },
                                fieldType = new { type = "string", description = "Field type for field_upsert." },
                                initializer = new { type = "string", description = "Field initializer for field_upsert." },
                                signatureHint = new { type = "string", description = "Optional extra text used to disambiguate semantic member matches." },
                            },
                            required = new[] { "kind" },
                            additionalProperties = false,
                        },
                    },
                },
                required = new[] { "path", "patches" },
                additionalProperties = false,
            },
        };
    }
}
