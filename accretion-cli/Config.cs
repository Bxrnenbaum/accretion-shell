
using System.Text.Json;
using System.Text.RegularExpressions;

public static class Config
{
    private const string ThemePath = "theme.json";

    private static readonly (string Output, string Template)[] ThemeFiles =
    [
        (".config/qs/Theme.qml", "templates/Theme.qml.tpl"),
        (".config/rofi/colors.rasi", "templates/config.rasi.tpl"),
        (".config/hypr/hyprlandTheme.lua", "templates/hyprlandTheme.lua.tpl")
    ];

    public static void Apply()
    {
        string root = FindRepoRoot();
        string cliDir = Path.Combine(root, "accretion-cli");
        string jsonPath = Path.Combine(cliDir, ThemePath);

        Console.WriteLine($"Repository root: {root}");

        using JsonDocument document = JsonDocument.Parse(
            File.ReadAllText(jsonPath));

        JsonElement colors = document.RootElement
            .GetProperty("theme")
            .GetProperty("colors");

        foreach (var (output, template) in ThemeFiles)
        {
            string templatePath = Path.Combine(cliDir, template);
            string outputPath = Path.GetFullPath(
                Path.Combine(root, output));

            if (!File.Exists(templatePath))
            {
                throw new FileNotFoundException(
                    $"Missing template: {template}", templatePath);
            }

            string content = File.ReadAllText(templatePath);

            content = Regex.Replace(
                content,
                @"\{\{color\.([a-zA-Z0-9_]+)\}\}",
                match =>
                {
                    string name = match.Groups[1].Value;

                    if (!colors.TryGetProperty(
                        name, out JsonElement value))
                    {
                        throw new InvalidOperationException(
                            $"Missing color in theme.json: {name}");
                    }

                    if (value.ValueKind != JsonValueKind.String)
                    {
                        throw new InvalidOperationException(
                            $"Color '{name}' must be a string.");
                    }

                    string color = value.GetString()!;

                    if (!Regex.IsMatch(color, @"^#[0-9a-fA-F]{6}$"))
                    {
                        throw new InvalidOperationException(
                            $"Invalid color '{name}': {color}. Use #RRGGBB.");
                    }

                    return color;
                });

            string? outputDirectory = Path.GetDirectoryName(outputPath);

            if (outputDirectory is not null)
                Directory.CreateDirectory(outputDirectory);

            File.WriteAllText(outputPath, content);
            Console.WriteLine($"Applied: {outputPath}");
        }

        Console.WriteLine("Theme applied successfully.");
    }

    private static string FindRepoRoot()
    {
        string home = Environment.GetFolderPath(
            Environment.SpecialFolder.UserProfile);

        // Check explicit locations first, regardless of the current directory.
        var candidates = new List<string>();

        string? configuredRoot =
            Environment.GetEnvironmentVariable("ACCRETION_REPO_DIR");

        if (!string.IsNullOrWhiteSpace(configuredRoot))
            candidates.Add(configuredRoot);

        candidates.Add(Path.Combine(
            home, ".local", "share", "accretion-shell"));

        // Also support running the CLI from a cloned development repository.
        foreach (string start in new[]
        {
            Directory.GetCurrentDirectory(),
            AppContext.BaseDirectory
        })
        {
            DirectoryInfo? directory =
                new DirectoryInfo(Path.GetFullPath(start));

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
            File.Exists(Path.Combine(
                path, "accretion-cli", "accretion-cli.csproj"))
            && File.Exists(Path.Combine(
                path, "accretion-cli", "theme.json"))
            && Directory.Exists(Path.Combine(
                path, "accretion-cli", "templates"))
            && Directory.Exists(Path.Combine(path, ".config"));
    }
}
