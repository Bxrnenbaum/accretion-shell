using System.ComponentModel;
using System.Diagnostics;

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

        if (changed.Contains("packages.txt"))
            Console.WriteLine("Note: packages.txt changed. Run 'accretion install' to install new dependencies.");

        if (changed.Any(f => f.StartsWith("accretion-cli/") && f.EndsWith(".cs")))
        {
            Console.Write("Rebuild the CLI binary now? [Y/n] ");
            string? answer = Console.ReadLine();

            if (string.IsNullOrWhiteSpace(answer) || answer.Equals("y", StringComparison.OrdinalIgnoreCase) || answer.Equals("yes", StringComparison.OrdinalIgnoreCase))
            {
                string projectPath = Path.Combine(repoRoot, "accretion-cli", "accretion-cli.csproj");
                var build = RunProcess("dotnet", "build", projectPath, "--nologo");

                if (build.Code != 0)
                {
                    Console.WriteLine("CLI rebuild failed.");
                    if (!string.IsNullOrWhiteSpace(build.Err))
                        Console.WriteLine(build.Err);
                }
                else
                {
                    Console.WriteLine("CLI rebuilt successfully.");
                }
            }
            else
            {
                Console.WriteLine("Skipping CLI rebuild. Run 'dotnet build accretion-cli/accretion-cli.csproj' later to update the binary.");
            }
        }

        Console.WriteLine("Update complete. Restart Quickshell/Hyprland components to pick up changes.");
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