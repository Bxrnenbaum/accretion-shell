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

        if (!File.Exists(jsonPath))
        {
            throw new FileNotFoundException(
                $"Could not find {ThemePath}", jsonPath);
        }

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

                    if (!Regex.IsMatch(
                        color, @"^#[0-9a-fA-F]{6}$"))
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
                bool hasGit =
                    Directory.Exists(Path.Combine(directory.FullName, ".git"))
                    || File.Exists(Path.Combine(directory.FullName, ".git"));

                bool hasReadme = File.Exists(
                    Path.Combine(directory.FullName, "README.md"));

                bool hasCliProject = File.Exists(
                    Path.Combine(directory.FullName,
                        "accretion-cli", "accretion-cli.csproj"));

                if (hasGit && hasReadme && hasCliProject)
                    return directory.FullName;

                directory = directory.Parent;
            }
        }

        throw new DirectoryNotFoundException(
            "Could not find the Accretion Shell repository root.");
    }
}
