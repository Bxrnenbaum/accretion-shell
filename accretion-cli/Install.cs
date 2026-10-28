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



    /// <summary>
    /// Describes how to install packages with one package manager.
    /// Package lists live in packages/&lt;Id&gt;.txt in the repository.
    /// </summary>
    private sealed record PackageManager(
        string Id,                      // also the package list name: packages/<Id>.txt
        string Binary,                  // executable used for detection
        string[] Command,               // command + fixed arguments
        bool NeedsRoot,
        string PackagePrefix = "");     // prepended to every package name (nix)

    private static readonly PackageManager[] PackageManagers =
    [
        new("pacman", "pacman",       ["pacman", "-S", "--needed"],                 NeedsRoot: true),
        new("dnf",    "dnf",          ["dnf", "install"],                           NeedsRoot: true),
        new("zypper", "zypper",       ["zypper", "install"],                        NeedsRoot: true),
        new("nix",    "nix",
            ["nix", "--extra-experimental-features", "nix-command flakes",
             "profile", "install"],
            NeedsRoot: false, PackagePrefix: "nixpkgs#"),
    ];

    // /etc/os-release ID / ID_LIKE -> package manager id
    private static readonly Dictionary<string, string> DistroToManager =
        new(StringComparer.OrdinalIgnoreCase)
        {
            ["arch"] = "pacman",
            ["manjaro"] = "pacman",
            ["endeavouros"] = "pacman",
            ["cachyos"] = "pacman",
            ["garuda"] = "pacman",

            ["fedora"] = "dnf",
            ["nobara"] = "dnf",
            ["rhel"] = "dnf",

            ["opensuse"] = "zypper",
            ["opensuse-tumbleweed"] = "zypper",
            ["opensuse-leap"] = "zypper",
            ["suse"] = "zypper",

            ["nixos"] = "nix",
        };

    public static void Run(string? packageManagerOverride = null)
    {
        string repoRoot = FindRepoRoot();
        string sourceConfig = Path.Combine(repoRoot, ".config");

        InstallDependencies(repoRoot, packageManagerOverride);

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



    private static void InstallDependencies(string repoRoot, string? overrideId)
    {
        PackageManager manager = DetectPackageManager(overrideId);
        Console.WriteLine($"Using package manager: {manager.Id}");

        if (manager.Id == "nix" && ReadOsRelease().GetValueOrDefault("ID") == "nixos")
        {
            Console.WriteLine(
                "Note: on NixOS, imperative installs go into your user profile, but " +
                "Hyprland itself (session, portals, graphics) should be enabled in your " +
                "system configuration with programs.hyprland.enable = true;");
        }

        string packageFile = ResolvePackageFile(repoRoot, manager);

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

        if (FindOnPath(manager.Binary) is null)
            throw new PlatformNotSupportedException(
                $"'{manager.Binary}' was not found on PATH.");

        Console.WriteLine("Installing Accretion Shell dependencies...");

        var startInfo = new ProcessStartInfo { UseShellExecute = false };


        if (manager.NeedsRoot && !Environment.IsPrivilegedProcess)
        {
            startInfo.FileName = "sudo";
            foreach (string part in manager.Command)
                startInfo.ArgumentList.Add(part);
        }
        else
        {
            startInfo.FileName = manager.Command[0];
            foreach (string part in manager.Command.Skip(1))
                startInfo.ArgumentList.Add(part);
        }

        foreach (string package in packages)
            startInfo.ArgumentList.Add(manager.PackagePrefix + package);

        using Process process = Process.Start(startInfo)
            ?? throw new InvalidOperationException(
                "Failed to start the package manager.");

        process.WaitForExit();

        if (process.ExitCode != 0)
            throw new InvalidOperationException(
                "Dependency installation failed. Accretion was not installed.");
    }

    private static string ResolvePackageFile(string repoRoot, PackageManager manager)
    {
        string packageFile = Path.Combine(repoRoot, "packages", $"{manager.Id}.txt");

        if (File.Exists(packageFile))
            return packageFile;

        // Backwards compatibility: the old single packages.txt was pacman-only.
        string legacy = Path.Combine(repoRoot, "packages.txt");
        if (manager.Id == "pacman" && File.Exists(legacy))
            return legacy;

        string available = Directory.Exists(Path.Combine(repoRoot, "packages"))
            ? string.Join(", ", Directory
                .GetFiles(Path.Combine(repoRoot, "packages"), "*.txt")
                .Select(Path.GetFileNameWithoutExtension))
            : "none";

        throw new FileNotFoundException(
            $"No package list for '{manager.Id}'. Expected packages/{manager.Id}.txt " +
            $"(available: {available}). Add one, or install the dependencies manually.",
            packageFile);
    }


    private static PackageManager DetectPackageManager(string? overrideId)
    {
        overrideId ??= Environment.GetEnvironmentVariable("ACCRETION_PACKAGE_MANAGER");

        if (!string.IsNullOrWhiteSpace(overrideId))
        {
            return PackageManagers.FirstOrDefault(m =>
                       string.Equals(m.Id, overrideId.Trim(), StringComparison.OrdinalIgnoreCase))
                   ?? throw new ArgumentException(
                       $"Unknown package manager '{overrideId}'. Supported: " +
                       string.Join(", ", PackageManagers.Select(m => m.Id)));
        }

        Dictionary<string, string> osRelease = ReadOsRelease();

        IEnumerable<string> distroIds =
            new[] { osRelease.GetValueOrDefault("ID") }
                .Concat((osRelease.GetValueOrDefault("ID_LIKE") ?? "")
                    .Split(' ', StringSplitOptions.RemoveEmptyEntries))
                .Where(id => !string.IsNullOrWhiteSpace(id))!;

        foreach (string id in distroIds)
        {
            if (DistroToManager.TryGetValue(id, out string? managerId))
                return PackageManagers.First(m => m.Id == managerId);
        }


        PackageManager? found = PackageManagers.FirstOrDefault(
            m => FindOnPath(m.Binary) is not null);

        return found ?? throw new PlatformNotSupportedException(
            "Could not detect a supported package manager. Supported: " +
            string.Join(", ", PackageManagers.Select(m => m.Id)) +
            ". Set ACCRETION_PACKAGE_MANAGER to force one.");
    }

    private static Dictionary<string, string> ReadOsRelease()
    {
        var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        foreach (string path in new[] { "/etc/os-release", "/usr/lib/os-release" })
        {
            if (!File.Exists(path))
                continue;

            foreach (string line in File.ReadAllLines(path))
            {
                int eq = line.IndexOf('=');
                if (eq <= 0 || line.TrimStart().StartsWith('#'))
                    continue;

                values[line[..eq].Trim()] = line[(eq + 1)..].Trim().Trim('"', '\'');
            }

            break;
        }

        return values;
    }

    private static string? FindOnPath(string executable)
    {
        string? path = Environment.GetEnvironmentVariable("PATH");
        if (path is null)
            return null;

        foreach (string dir in path.Split(':', StringSplitOptions.RemoveEmptyEntries))
        {
            string candidate = Path.Combine(dir, executable);
            if (File.Exists(candidate))
                return candidate;
        }

        return null;
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