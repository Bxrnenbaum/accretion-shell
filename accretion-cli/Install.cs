using System.Diagnostics;
using System.Text.Json;

public static class Install
{
    private static readonly string Home =
        Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

    private static readonly string ConfigDirectory =
        Path.Combine(Home, ".config");

    private static readonly string StateDirectory =
        Path.Combine(Home, ".local", "state", "accretion-shell");

    private static readonly string StateFile =
        Path.Combine(StateDirectory, "install.json");

    private static readonly string[] ConfigNames =
    [
        "hypr",
        "qs",
        "rofi"
    ];

    private static readonly string[] LocalFiles =
[
    ".config/hypr/hyprlandLocal.lua"
];

    public static void Run()
    {
        string repoRoot = FindRepoRoot();
        string sourceConfig = Path.Combine(repoRoot, ".config");

        InstallDependencies(repoRoot);

        if (!Directory.Exists(sourceConfig))
            throw new DirectoryNotFoundException(
                $"Missing config directory: {sourceConfig}");

        Directory.CreateDirectory(ConfigDirectory);
        Directory.CreateDirectory(StateDirectory);

        InstallState state = LoadState();
        state.Repository = repoRoot;

        string backupRoot = Path.Combine(
            StateDirectory,
            "backups",
            DateTime.Now.ToString("yyyyMMdd-HHmmss"));

        foreach (string name in ConfigNames)
        {
            string source = Path.Combine(sourceConfig, name);

            if (!Directory.Exists(source))
            {
                Console.WriteLine($"Skipping missing config: {source}");
                continue;
            }

            LinkWithBackup(
                state, source, Path.Combine(ConfigDirectory, name), backupRoot);
        }

        InstallFonts(repoRoot, state, backupRoot);

        EnsureLocalFiles(repoRoot);

        string previousDirectory = Directory.GetCurrentDirectory();

        try
        {
            Directory.SetCurrentDirectory(repoRoot);
            Config.Apply();
        }
        finally
        {
            Directory.SetCurrentDirectory(previousDirectory);
        }

        Console.WriteLine("Accretion Shell installed successfully.");
    }

    internal static void EnsureLocalFiles(string repoRoot)
    {
        foreach (string relative in LocalFiles)
        {
            string target = Path.Combine(repoRoot, relative);
            string example = target + ".example";

            if (File.Exists(target))
                continue; // never overwrite

            if (!File.Exists(example))
            {
                Console.WriteLine($"Warning: missing {relative} and no .example to create it from.");
                continue;
            }

            File.Copy(example, target, overwrite: false);
            Console.WriteLine($"Created local file: {target}");
        }
    }

    private static void LinkWithBackup(
    InstallState state, string source, string destination, string backupRoot)
    {
        if (IsCorrectLink(destination, source))
        {
            Console.WriteLine($"Already linked: {destination}");
            return;
        }

        string name = Path.GetFileName(destination);

        if (PathExists(destination))
        {
            Directory.CreateDirectory(backupRoot);

            string backup = Path.Combine(backupRoot, name);
            MovePath(destination, backup);

            Console.WriteLine($"Backed up: {destination} -> {backup}");

            state.Entries.RemoveAll(e => e.LinkPath == destination);
            state.Entries.Add(new InstallEntry
            {
                LinkPath = destination,
                SourcePath = source,
                BackupPath = backup
            });
        }
        else
        {
            state.Entries.RemoveAll(e => e.LinkPath == destination);
            state.Entries.Add(new InstallEntry
            {
                LinkPath = destination,
                SourcePath = source,
                BackupPath = null
            });
        }

        SaveState(state);

        try
        {
            Directory.CreateSymbolicLink(destination, source);
            Console.WriteLine($"Linked: {destination} -> {source}");
        }
        catch
        {
            InstallEntry? entry = state.Entries.Find(e => e.LinkPath == destination);

            if (entry?.BackupPath is not null &&
                PathExists(entry.BackupPath) &&
                !PathExists(destination))
            {
                MovePath(entry.BackupPath, destination);
                state.Entries.Remove(entry);
                SaveState(state);
            }

            throw;
        }

        SaveState(state);
    }

    private static void InstallFonts(
        string repoRoot, InstallState state, string backupRoot)
    {
        string source = Path.Combine(repoRoot, "fonts");

        if (!Directory.Exists(source))
        {
            Console.WriteLine($"Skipping fonts, missing directory: {source}");
            return;
        }

        string fontsRoot = Path.Combine(Home, ".local", "share", "fonts");
        Directory.CreateDirectory(fontsRoot);

        LinkWithBackup(
            state, source, Path.Combine(fontsRoot, "accretion-shell"), backupRoot);

        RefreshFontCache();
    }

    internal static void RefreshFontCache()
    {
        try
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = "fc-cache",
                UseShellExecute = false
            };
            startInfo.ArgumentList.Add("-f");

            using Process? process = Process.Start(startInfo);
            process?.WaitForExit();

            Console.WriteLine("Font cache refreshed.");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Warning: could not run fc-cache: {ex.Message}");
        }
    }

    internal static InstallState LoadState()
    {
        if (!File.Exists(StateFile))
            return new InstallState();

        return JsonSerializer.Deserialize<InstallState>(
            File.ReadAllText(StateFile)) ?? new InstallState();
    }

    internal static void SaveState(InstallState state)
    {
        Directory.CreateDirectory(StateDirectory);

        File.WriteAllText(
            StateFile,
            JsonSerializer.Serialize(
                state,
                new JsonSerializerOptions { WriteIndented = true }));
    }

    internal static bool PathExists(string path)
    {
        try
        {
            File.GetAttributes(path);
            return true;
        }
        catch (FileNotFoundException)
        {
            return false;
        }
        catch (DirectoryNotFoundException)
        {
            return false;
        }
    }

    internal static bool IsCorrectLink(string link, string target)
    {
        if (!PathExists(link))
            return false;

        FileSystemInfo info = Directory.Exists(link)
            ? new DirectoryInfo(link)
            : new FileInfo(link);

        if (info.LinkTarget is null)
            return false;

        string? resolvedTarget = Path.GetFullPath(
            Path.Combine(Path.GetDirectoryName(link)!, info.LinkTarget));

        return string.Equals(
            resolvedTarget,
            Path.GetFullPath(target),
            StringComparison.Ordinal);
    }

    internal static void MovePath(string source, string destination)
    {
        if (Directory.Exists(source))
            Directory.Move(source, destination);
        else
            File.Move(source, destination);
    }

    internal static string FindRepoRoot()
    {
        foreach (string start in new[]
        {
            Directory.GetCurrentDirectory(),
            AppContext.BaseDirectory,
            Path.Combine(Home, ".local", "share", "accretion-shell")
        })
        {
            DirectoryInfo? directory =
                new DirectoryInfo(Path.GetFullPath(start));

            while (directory is not null)
            {
                bool hasProject = File.Exists(Path.Combine(
                    directory.FullName,
                    "accretion-cli",
                    "accretion-cli.csproj"));

                bool hasConfig = Directory.Exists(
                    Path.Combine(directory.FullName, ".config"));

                if (hasProject && hasConfig)
                    return directory.FullName;

                directory = directory.Parent;
            }
        }

        throw new DirectoryNotFoundException(
            "Could not find the Accretion Shell repository. " +
            "Clone it to ~/.local/share/accretion-shell first.");
    }

    private static void InstallDependencies(string repoRoot)
    {
        string packageFile = Path.Combine(repoRoot, "packages.txt");

        if (!File.Exists(packageFile))
            throw new FileNotFoundException(
                "Could not find packages.txt.", packageFile);

        string[] packages = File.ReadAllLines(packageFile)
            .Select(line => line.Split('#')[0].Trim())
            .Where(line => !string.IsNullOrWhiteSpace(line))
            .Distinct()
            .ToArray();

        if (packages.Length == 0)
        {
            Console.WriteLine("No dependencies to install.");
            return;
        }

        if (!File.Exists("/usr/bin/pacman"))
            throw new PlatformNotSupportedException(
                "Automatic dependency installation currently supports Arch Linux.");

        Console.WriteLine("Installing Accretion Shell dependencies...");

        var startInfo = new ProcessStartInfo
        {
            FileName = "sudo",
            UseShellExecute = false
        };

        startInfo.ArgumentList.Add("pacman");
        startInfo.ArgumentList.Add("-S");
        startInfo.ArgumentList.Add("--needed");

        foreach (string package in packages)
            startInfo.ArgumentList.Add(package);

        using Process process = Process.Start(startInfo)
            ?? throw new InvalidOperationException(
                "Failed to start the package manager.");

        process.WaitForExit();

        if (process.ExitCode != 0)
            throw new InvalidOperationException(
                "Dependency installation failed. Accretion was not installed.");
    }
}

public sealed class InstallState
{
    public string Repository { get; set; } = "";
    public List<InstallEntry> Entries { get; set; } = [];
}

public sealed class InstallEntry
{
    public string LinkPath { get; set; } = "";
    public string SourcePath { get; set; } = "";
    public string? BackupPath { get; set; }
}
