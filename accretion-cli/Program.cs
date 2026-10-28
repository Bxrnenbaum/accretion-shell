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
            if (command.Length >= 2 &&
                command[1].Equals("apply", StringComparison.OrdinalIgnoreCase))
            {
                Config.Apply();
            }
            else
            {
                Console.WriteLine("Usage: accretion config apply");
            }
            break;

        case "install":
            Install.Run();
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

static void PrintHelp()
{
    Console.WriteLine("""
        Accretion Shell

        Usage:
          accretion config apply   Generate theme files
          accretion install        Install shell configuration
          accretion uninstall      Uninstall shell configuration
          accretion help           Show this help
        """);
}
