using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

public static class Config
{
    private const string ThemePath = "theme.json";

    private static readonly (string Output, string Template)[] ThemeFiles =
    [
        (".config/qs/Theme.json", "templates/Theme.json.tpl"),
        (".config/hypr/hyprlandTheme.lua", "templates/hyprlandTheme.lua.tpl"),
        (".config/hypr/hyprlockTheme.conf", "templates/hyprlockTheme.conf.tpl"),
        (".config/kitty/kitty.conf", "templates/kitty.conf.tpl")
    ];

    private static readonly Regex PlaceholderRegex =
        new(@"\{\{(json|color|rgb|pango|image|theme)\.([a-zA-Z0-9_.]+)\}\}", RegexOptions.Compiled);

    private static readonly Regex HexColorRegex =
        new(@"^#[0-9a-fA-F]{6}$", RegexOptions.Compiled);



    public static void ListThemes()
    {
        string root = FindRepoRoot();
        JsonNode node = LoadThemeJson(root);

        string? active = node["activeTheme"]?.GetValue<string>();
        JsonObject themes = GetThemes(node);

        foreach (var (key, _) in themes)
        {
            bool isActive = key.Equals(active, StringComparison.OrdinalIgnoreCase);
            Console.WriteLine($"{(isActive ? "*" : " ")} {key}");
        }
    }

    public static void SetTheme(string themeName)
    {
        string root = FindRepoRoot();
        string jsonPath = GetThemeJsonPath(root);
        JsonNode node = LoadThemeJson(root);
        JsonObject themes = GetThemes(node);

        string? match = themes
            .Select(t => t.Key)
            .FirstOrDefault(k => k.Equals(themeName, StringComparison.OrdinalIgnoreCase));

        if (match is null)
        {
            string available = string.Join(", ", themes.Select(t => t.Key));
            throw new InvalidOperationException(
                $"Unknown theme '{themeName}'. Available: {available}");
        }

        node["activeTheme"] = match;

        File.WriteAllText(jsonPath, node.ToJsonString(new JsonSerializerOptions
        {
            WriteIndented = true,
            Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
        }));

        Console.WriteLine($"Active theme: {match}");
        Apply();
    }

    public static void Apply()
    {
        string root = FindRepoRoot();
        string cliDir = Path.Combine(root, "accretion-cli");

        Console.WriteLine($"Repository root: {root}");

        using JsonDocument document = JsonDocument.Parse(
            File.ReadAllText(GetThemeJsonPath(root)));

        JsonElement rootElement = document.RootElement;

        string activeName = rootElement.GetProperty("activeTheme").GetString()
            ?? throw new InvalidOperationException("activeTheme must be a string.");

        JsonElement themes = rootElement.GetProperty("themes");


        JsonElement? theme = null;
        foreach (var prop in themes.EnumerateObject())
        {
            if (prop.Name.Equals(activeName, StringComparison.OrdinalIgnoreCase))
            {
                theme = prop.Value;
                break;
            }
        }

        if (theme is null)
            throw new InvalidOperationException(
                $"activeTheme '{activeName}' not found in theme.json.");

        JsonElement colors = theme.Value.GetProperty("colors");

        JsonElement images = default;
        bool hasImages = theme.Value.TryGetProperty("images", out images);

        string displayName = theme.Value.TryGetProperty("name", out var n)
            ? n.GetString() ?? activeName
            : activeName;

        foreach (var (output, template) in ThemeFiles)
        {
            string templatePath = Path.Combine(cliDir, template);
            string outputPath = Path.GetFullPath(Path.Combine(root, output));

            if (!File.Exists(templatePath))
            {
                throw new FileNotFoundException(
                    $"Missing template: {template}", templatePath);
            }

            string content = File.ReadAllText(templatePath);

            content = PlaceholderRegex.Replace(content, match =>
            {
                string kind = match.Groups[1].Value;
                string name = match.Groups[2].Value;

                return kind switch
                {
                    "json" => ResolveJsonPlaceholder(
                        name, colors, images, hasImages, cliDir, displayName),
                    "color" => ResolveColor(colors, name),
                    "rgb" => $"rgb({ResolveColor(colors, name)[1..]})",
                    "pango" => $"##{ResolveColor(colors, name)[1..]}",
                    "image" => ResolveImage(images, hasImages, name, cliDir),
                    "theme" when name == "name" => displayName,
                    _ => throw new InvalidOperationException($"Unknown placeholder: {match.Value}")
                };
            });

            string? outputDirectory = Path.GetDirectoryName(outputPath);
            if (outputDirectory is not null)
                Directory.CreateDirectory(outputDirectory);

            WriteIfChanged(outputPath, content);
            Console.WriteLine($"Applied: {outputPath}");
        }

        Console.WriteLine("Theme applied successfully.");
    }

    private static string ResolveJsonPlaceholder(
        string name,
        JsonElement colors,
        JsonElement images,
        bool hasImages,
        string baseDir,
        string displayName)
    {
        int separator = name.IndexOf('.');
        if (separator <= 0 || separator == name.Length - 1)
            throw new InvalidOperationException($"Invalid JSON placeholder: {name}");

        string kind = name[..separator];
        string key = name[(separator + 1)..];

        string value = kind switch
        {
            "color" => ResolveColor(colors, key),
            "image" => ResolveImage(images, hasImages, key, baseDir),
            "theme" when key == "name" => displayName,
            _ => throw new InvalidOperationException($"Unknown JSON placeholder: {name}")
        };

        return JsonSerializer.Serialize(value);
    }

    private static void WriteIfChanged(string path, string content)
    {
        if (File.Exists(path) && File.ReadAllText(path) == content)
            return;

        string temporaryPath = path + "." + Guid.NewGuid().ToString("N") + ".tmp";

        try
        {
            File.WriteAllText(temporaryPath, content);
            File.Move(temporaryPath, path, overwrite: true);
        }
        finally
        {
            if (File.Exists(temporaryPath))
                File.Delete(temporaryPath);
        }
    }

    private static string ResolveColor(JsonElement colors, string name)
    {
        if (!colors.TryGetProperty(name, out JsonElement value))
            throw new InvalidOperationException($"Missing color in theme.json: {name}");

        if (value.ValueKind != JsonValueKind.String)
            throw new InvalidOperationException($"Color '{name}' must be a string.");

        string color = value.GetString()!;

        if (!HexColorRegex.IsMatch(color))
            throw new InvalidOperationException(
                $"Invalid color '{name}': {color}. Use #RRGGBB.");

        return color;
    }

    private static string ResolveImage(
        JsonElement images, bool hasImages, string name, string baseDir)
    {
        if (!hasImages || !images.TryGetProperty(name, out JsonElement value))
            throw new InvalidOperationException($"Missing image in theme.json: {name}");

        if (value.ValueKind != JsonValueKind.String)
            throw new InvalidOperationException($"Image '{name}' must be a string.");

        string path = value.GetString()!;

        if (path == "~" || path.StartsWith("~/"))
        {
            string home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            path = Path.Combine(home, path.Length > 2 ? path[2..] : "");
        }

        if (!Path.IsPathRooted(path))
            path = Path.Combine(baseDir, path);

        path = Path.GetFullPath(path);

        if (!File.Exists(path))
            throw new FileNotFoundException(
                $"Image '{name}' does not exist: {path}", path);

        return path;
    }

    private static string GetThemeJsonPath(string root) =>
        Path.Combine(root, "accretion-cli", ThemePath);

    private static JsonNode LoadThemeJson(string root) =>
        JsonNode.Parse(File.ReadAllText(GetThemeJsonPath(root)))
            ?? throw new InvalidOperationException("theme.json is empty.");

    private static JsonObject GetThemes(JsonNode node) =>
        node["themes"]?.AsObject()
            ?? throw new InvalidOperationException("theme.json has no 'themes' object.");


    public static string FindRepoRoot()
    {
        string home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

        var candidates = new List<string>();

        string? configuredRoot = Environment.GetEnvironmentVariable("ACCRETION_REPO_DIR");
        if (!string.IsNullOrWhiteSpace(configuredRoot))
            candidates.Add(configuredRoot);

        candidates.Add(Path.Combine(home, ".local", "share", "accretion-shell"));

        foreach (string start in new[]
        {
            Directory.GetCurrentDirectory(),
            AppContext.BaseDirectory
        })
        {
            DirectoryInfo? directory = new DirectoryInfo(Path.GetFullPath(start));

            while (directory is not null)
            {
                candidates.Add(directory.FullName);
                directory = directory.Parent;
            }
        }

        foreach (string candidate in candidates.Distinct())
        {
            string root = Path.GetFullPath(candidate);
            if (IsRepoRoot(root))
                return root;
        }

        throw new DirectoryNotFoundException(
            "Could not find the Accretion Shell repository. " +
            "Expected it at ~/.local/share/accretion-shell, " +
            "in a parent directory, or at ACCRETION_REPO_DIR.");
    }

    private static bool IsRepoRoot(string path)
    {
        return
            File.Exists(Path.Combine(path, "accretion-cli", "accretion-cli.csproj"))
            && File.Exists(Path.Combine(path, "accretion-cli", "theme.json"))
            && Directory.Exists(Path.Combine(path, "accretion-cli", "templates"))
            && Directory.Exists(Path.Combine(path, ".config"));
    }
}