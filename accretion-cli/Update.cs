using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;

public static class Update
{
    public static void Run()
    {
        string repoRoot = Install.FindRepoRoot();
        Console.WriteLine($"Repository: {repoRoot}");

        if (Git(repoRoot, "rev-parse", "--is-inside-work-tree").Code != 0)
            throw new InvalidOperationException($"{repoRoot} is not a git repository.");

        var upstream = Git(repoRoot, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}");
        if (upstream.Code != 0)
            throw new InvalidOperationException(
                "The current branch has no upstream. Set one with: " +
                "git branch --set-upstream-to=origin/<branch>");

        Console.WriteLine($"Fetching {upstream.Out}...");
        var fetch = Git(repoRoot, "fetch");
        if (fetch.Code != 0)
            throw new InvalidOperationException($"git fetch failed: {fetch.Err}");

        string behind = Git(repoRoot, "rev-list", "--count", "HEAD..@{u}").Out;

        Install.EnsureLocalFiles(repoRoot);

        if (behind == "0")
        {
            Console.WriteLine("Already up to date.");
            return;
        }

        Console.WriteLine($"{behind} new commit(s). Pulling...");

        string oldHead = Git(repoRoot, "rev-parse", "HEAD").Out;

        var pull = Git(repoRoot, "pull", "--ff-only", "--autostash");
        if (pull.Code != 0)
        {
            throw new InvalidOperationException(
                "git pull failed. Your local files were not overwritten.\n" +
                pull.Err + "\n" +
                "If your branch has diverged, resolve it manually with git.");
        }

        string newHead = Git(repoRoot, "rev-parse", "HEAD").Out;

        string[] changed = Git(repoRoot, "diff", "--name-only", oldHead, newHead).Out
            .Split('\n', StringSplitOptions.RemoveEmptyEntries);

        Console.WriteLine($"Updated {oldHead[..7]} -> {newHead[..7]} ({changed.Length} files changed)");

        Install.EnsureLocalFiles(repoRoot);

        Environment.SetEnvironmentVariable("ACCRETION_REPO_DIR", repoRoot);
        Config.Apply();

        if (changed.Any(f => f.StartsWith("fonts/")))
            Install.RefreshFontCache();

        if (changed.Any(f => f.StartsWith("packages/") && f.EndsWith(".txt")))
            Console.WriteLine("Note: the package list changed. Run 'accretion install' to install new dependencies.");

        bool cliSourceChanged = changed.Any(f =>
            f.StartsWith("accretion-cli/", StringComparison.Ordinal) &&
            (f.EndsWith(".cs", StringComparison.OrdinalIgnoreCase) ||
             f.EndsWith(".csproj", StringComparison.OrdinalIgnoreCase)));

        if (cliSourceChanged)
        {
            Console.WriteLine("CLI source changed. Rebuilding the binary...");

            try
            {
                RebuildCli(repoRoot);
                Console.WriteLine("CLI binary rebuilt successfully.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"CLI rebuild failed: {ex.Message}");
            }
        }

        Console.WriteLine("Update complete. Restart Quickshell/Hyprland components to pick up changes.");
    }

    private static void RebuildCli(string repoRoot)
    {
        string rid = RuntimeInformation.ProcessArchitecture switch
        {
            Architecture.X64 => "linux-x64",
            Architecture.Arm64 => "linux-arm64",
            _ => throw new InvalidOperationException(
                $"Unsupported architecture: {RuntimeInformation.ProcessArchitecture}")
        };

        string projectPath = Path.Combine(repoRoot, "accretion-cli", "accretion-cli.csproj");
        string publishDirectory = Path.Combine(
            Path.GetTempPath(),
            $"accretion-cli-publish-{Guid.NewGuid():N}");

        Directory.CreateDirectory(publishDirectory);

        try
        {
            var publish = RunProcess(
                "dotnet",
                "publish",
                projectPath,
                "-c", "Release",
                "-r", rid,
                "--self-contained", "true",
                "-p:PublishSingleFile=true",
                "-p:IncludeNativeLibrariesForSelfExtract=true",
                "--nologo",
                "-o", publishDirectory);

            if (publish.Code != 0)
            {
                throw new InvalidOperationException(
                    string.IsNullOrWhiteSpace(publish.Err)
                        ? "dotnet publish failed."
                        : publish.Err);
            }

            string publishedBinary = Path.Combine(publishDirectory, "accretion-cli");
            if (!File.Exists(publishedBinary))
                throw new InvalidOperationException(
                    $"Published CLI binary was not found at {publishedBinary}.");

            string home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            string binDirectory = Path.Combine(home, ".local", "bin");
            string installedBinary = Path.Combine(binDirectory, "accretion");

            Directory.CreateDirectory(binDirectory);
            File.Copy(publishedBinary, installedBinary, overwrite: true);

            if (!OperatingSystem.IsWindows())
            {
                File.SetUnixFileMode(
                    installedBinary,
                    UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute |
                    UnixFileMode.GroupRead | UnixFileMode.GroupExecute |
                    UnixFileMode.OtherRead | UnixFileMode.OtherExecute);
            }

            Console.WriteLine($"Installed rebuilt CLI at {installedBinary}");
        }
        finally
        {
            if (Directory.Exists(publishDirectory))
                Directory.Delete(publishDirectory, recursive: true);
        }
    }

    private static (int Code, string Out, string Err) Git(string repo, params string[] args)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = "git",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };

        startInfo.ArgumentList.Add("-C");
        startInfo.ArgumentList.Add(repo);
        foreach (string arg in args)
            startInfo.ArgumentList.Add(arg);

        try
        {
            using Process process = Process.Start(startInfo)
                ?? throw new InvalidOperationException("Failed to start git.");

            var errTask = process.StandardError.ReadToEndAsync();
            string output = process.StandardOutput.ReadToEnd();
            process.WaitForExit();

            return (process.ExitCode, output.Trim(), errTask.Result.Trim());
        }
        catch (Win32Exception)
        {
            throw new InvalidOperationException("git is not installed or not in PATH.");
        }
    }

    private static (int Code, string Out, string Err) RunProcess(string fileName, params string[] args)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = fileName,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };

        foreach (string arg in args)
            startInfo.ArgumentList.Add(arg);

        try
        {
            using Process process = Process.Start(startInfo)
                ?? throw new InvalidOperationException($"Failed to start {fileName}.");

            var errTask = process.StandardError.ReadToEndAsync();
            string output = process.StandardOutput.ReadToEnd();
            process.WaitForExit();

            return (process.ExitCode, output.Trim(), errTask.Result.Trim());
        }
        catch (Win32Exception)
        {
            throw new InvalidOperationException($"{fileName} is not installed or not in PATH.");
        }
    }
}