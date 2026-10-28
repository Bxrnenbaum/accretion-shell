
public static class Uninstall
{
    public static void Run()
    {
        InstallState state = Install.LoadState();

        if (state.Entries.Count == 0)
        {
            Console.WriteLine("No managed configuration links found.");
            return;
        }

        foreach (InstallEntry entry in state.Entries.AsEnumerable().Reverse())
        {
            if (Install.IsCorrectLink(entry.LinkPath, entry.SourcePath))
            {
                if (Directory.Exists(entry.LinkPath))
                    Directory.Delete(entry.LinkPath);
                else
                    File.Delete(entry.LinkPath);

                Console.WriteLine($"Removed link: {entry.LinkPath}");
            }
            else if (Install.PathExists(entry.LinkPath))
            {
                Console.WriteLine(
                    $"Keeping modified path: {entry.LinkPath}");
            }

            if (entry.BackupPath is not null &&
                Install.PathExists(entry.BackupPath))
            {
                if (Install.PathExists(entry.LinkPath))
                {
                    Console.WriteLine(
                        $"Cannot restore backup because destination exists: " +
                        entry.LinkPath);
                    continue;
                }

                Install.MovePath(entry.BackupPath, entry.LinkPath);
                Console.WriteLine($"Restored: {entry.LinkPath}");
            }
        }

        state.Entries.Clear();
        Install.SaveState(state);

        Console.WriteLine(
            "Accretion configuration uninstalled. " +
            "The repository and CLI were left untouched.");
    }
}
