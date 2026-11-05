using System.Globalization;
using System.Text.Json;

public static class Location
{
    private const string LocalLocationFile = ".config/qs/weather-location.json";

    public static void Configure(string[] args)
    {
        if (args.Length == 0)
        {
            PrintCurrent();
            return;
        }

        if (args.Length != 2)
        {
            throw new ArgumentException("Usage: accretion config location <lat> <lon>");
        }

        (double latitude, double longitude) = ParseExplicitCoordinates(args[0], args[1]);
        WriteLocation(latitude, longitude);

        Console.WriteLine(
            $"Weather location updated: {latitude.ToString(CultureInfo.InvariantCulture)}, " +
            longitude.ToString(CultureInfo.InvariantCulture));
    }

    private static (double latitude, double longitude) ParseExplicitCoordinates(string latitudeText, string longitudeText)
    {
        if (!double.TryParse(latitudeText, NumberStyles.Float, CultureInfo.InvariantCulture, out double latitude) ||
            !double.TryParse(longitudeText, NumberStyles.Float, CultureInfo.InvariantCulture, out double longitude))
        {
            throw new FormatException("Latitude and longitude must be valid floating-point numbers.");
        }

        if (latitude < -90 || latitude > 90)
        {
            throw new ArgumentOutOfRangeException(nameof(latitude), "Latitude must be between -90 and 90.");
        }

        if (longitude < -180 || longitude > 180)
        {
            throw new ArgumentOutOfRangeException(nameof(longitude), "Longitude must be between -180 and 180.");
        }

        return (latitude, longitude);
    }

    public static void PrintCurrent()
    {
        string path = Path.Combine(Config.FindRepoRoot(), LocalLocationFile);

        if (!File.Exists(path))
        {
            Console.WriteLine("No saved weather location found.");
            return;
        }

        using JsonDocument document = JsonDocument.Parse(File.ReadAllText(path));
        if (!document.RootElement.TryGetProperty("latitude", out JsonElement latitudeElement) ||
            !document.RootElement.TryGetProperty("longitude", out JsonElement longitudeElement))
        {
            Console.WriteLine("Saved weather location is invalid.");
            return;
        }

        Console.WriteLine(
            $"Current weather location: {latitudeElement.GetDouble().ToString(CultureInfo.InvariantCulture)}, " +
            longitudeElement.GetDouble().ToString(CultureInfo.InvariantCulture));
    }

    public static void WriteLocation(double latitude, double longitude)
    {
        string root = Config.FindRepoRoot();
        string path = Path.Combine(root, LocalLocationFile);
        string? directory = Path.GetDirectoryName(path);

        if (!string.IsNullOrEmpty(directory))
        {
            Directory.CreateDirectory(directory);
        }

        File.WriteAllText(
            path,
            $$"""
            {
              "latitude": {{latitude.ToString(CultureInfo.InvariantCulture)}},
              "longitude": {{longitude.ToString(CultureInfo.InvariantCulture)}}
            }
            """
            .Replace("\r\n", "\n"));
    }
}
