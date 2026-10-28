string[] command = args;

if (command.Length == 0)
{
    PrintHelp();
    return;
}

try
{
    switch (command[0].ToLowerInvariant())
    {
        case "config":
            HandleConfig(command);
            break;

        case "install":
            Install.Run();
            break;

        case "update":
            Update.Run();
            break;

        case "uninstall":
            Uninstall.Run();
            break;

        case "help":
        case "--help":
        case "-h":
            PrintHelp();
            break;

        default:
            Console.WriteLine($"Unknown command: {command[0]}");
            PrintHelp();
            Environment.ExitCode = 1;
            break;
    }
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
    Environment.ExitCode = 1;
}

static void HandleConfig(string[] command)
{
    string sub = command.Length >= 2 ? command[1].ToLowerInvariant() : "";

    switch (sub)
    {
        case "apply":
            Config.Apply();
            break;

        case "theme":
            if (command.Length >= 3)
                Config.SetTheme(command[2]);
            else
                Config.ListThemes();
            break;

        default:
            Console.WriteLine("Usage: accretion config <apply|theme [name]>");
            break;
    }
}

static void PrintHelp()
{
    Console.WriteLine("""
        Accretion Shell

        Usage:
          accretion config apply          Regenerate theme files
          accretion config theme          List themes
          accretion config theme <name>   Switch theme and apply it
          accretion install               Install shell configuration
          accretion update                Pull the latest version and regenerate themes
          accretion uninstall             Uninstall shell configuration
          accretion help                  Show this help
        """);
}