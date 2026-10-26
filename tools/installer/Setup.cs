// Dust & Mandibles setup and launcher.
//
// Downloads the latest game build from the GitHub Releases page, installs it to
// %LOCALAPPDATA%\DustAndMandibles, adds Desktop and Start Menu shortcuts, and
// starts the game. Run it again (or use the shortcut) and it checks for a newer
// release first, so it doubles as the updater. The game is one self-contained
// .exe, so nothing else needs installing.
//
// Builds with the C# compiler that ships with Windows (.NET Framework 4):
//   C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /target:exe
//       /out:DustAndMandiblesSetup.exe /win32icon:icon.ico Setup.cs
using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Reflection;
using System.Text.RegularExpressions;
using System.Threading;

static class Setup
{
    const string Repo = "TheRNGenie/DustAndMandibles";
    const string GameFile = "DustAndMandibles.exe";
    const string LauncherFile = "Dust & Mandibles Launcher.exe";
    const string Title = "Dust & Mandibles";

    static string InstallDir
    {
        get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DustAndMandibles"); }
    }

    static int Main(string[] args)
    {
        Console.Title = Title + " setup";
        ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072; // TLS 1.2
        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine();
        Console.WriteLine("   DUST & MANDIBLES");
        Console.WriteLine("   ----------------");
        Console.ResetColor();
        Console.WriteLine();
        try
        {
            Directory.CreateDirectory(InstallDir);
            string game = Path.Combine(InstallDir, GameFile);
            string versionFile = Path.Combine(InstallDir, "version.txt");
            string installed = File.Exists(versionFile) ? File.ReadAllText(versionFile).Trim() : "";

            string tag = null, url = null;
            try
            {
                Console.WriteLine("Checking GitHub for the latest version...");
                FindLatest(out tag, out url);
            }
            catch (Exception e)
            {
                if (!File.Exists(game))
                    throw new Exception("Couldn't reach GitHub to download the game. (" + e.Message + ")");
                Console.WriteLine("Couldn't reach GitHub, starting the installed version.");
            }

            if (tag != null && (tag != installed || !File.Exists(game)))
            {
                Console.WriteLine(installed == "" ? "Installing " + tag + "..." : "Updating " + installed + " -> " + tag + "...");
                Download(url, game);
                File.WriteAllText(versionFile, tag);
            }
            else if (tag != null)
            {
                Console.WriteLine("You have the latest version (" + tag + ").");
            }

            InstallLauncher();
            Console.WriteLine();
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("Saddle up. Starting the game...");
            Console.ResetColor();
            Process.Start(new ProcessStartInfo(game) { WorkingDirectory = InstallDir, UseShellExecute = true });
            Thread.Sleep(1500);
            return 0;
        }
        catch (Exception e)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine();
            Console.WriteLine("Something went wrong: " + e.Message);
            Console.ResetColor();
            Console.WriteLine();
            Console.WriteLine("You can also download the game by hand from:");
            Console.WriteLine("  https://github.com/" + Repo + "/releases/latest");
            Console.WriteLine();
            Console.WriteLine("Press any key to close.");
            Console.ReadKey(true);
            return 1;
        }
    }

    static WebClient Client()
    {
        var wc = new WebClient();
        wc.Headers[HttpRequestHeader.UserAgent] = "DustAndMandiblesSetup";
        return wc;
    }

    // Reads the latest release's tag and the game's download link from the GitHub API.
    static void FindLatest(out string tag, out string url)
    {
        string json;
        using (var wc = Client())
        {
            wc.Headers[HttpRequestHeader.Accept] = "application/vnd.github+json";
            json = wc.DownloadString("https://api.github.com/repos/" + Repo + "/releases/latest");
        }
        var t = Regex.Match(json, "\"tag_name\"\\s*:\\s*\"([^\"]+)\"");
        var u = Regex.Match(json, "\"browser_download_url\"\\s*:\\s*\"([^\"]*/" + Regex.Escape(GameFile) + ")\"");
        if (!t.Success || !u.Success)
            throw new Exception("the latest release has no " + GameFile);
        tag = t.Groups[1].Value;
        url = u.Groups[1].Value;
    }

    // Downloads to a temporary file with a progress bar, then swaps it into place.
    static void Download(string url, string dest)
    {
        string tmp = dest + ".download";
        var done = new ManualResetEvent(false);
        Exception error = null;
        int lastPct = -1;
        using (var wc = Client())
        {
            wc.DownloadProgressChanged += (s, e) =>
            {
                int pct = e.ProgressPercentage;
                if (pct == lastPct) return;
                lastPct = pct;
                int bars = pct / 4;
                Console.Write("\r  [" + new string('#', bars) + new string('.', 25 - bars) + "] " + pct + "%  "
                    + (e.BytesReceived / 1048576) + " / " + (e.TotalBytesToReceive / 1048576) + " MB   ");
            };
            wc.DownloadFileCompleted += (s, e) => { error = e.Error; done.Set(); };
            wc.DownloadFileAsync(new Uri(url), tmp);
            done.WaitOne();
        }
        Console.WriteLine();
        if (error != null)
        {
            if (File.Exists(tmp)) File.Delete(tmp);
            throw new Exception("download failed (" + error.Message + ")");
        }
        if (File.Exists(dest)) File.Delete(dest);
        File.Move(tmp, dest);
    }

    // Copies this program next to the game and points the shortcuts at it, so
    // starting the game from a shortcut always checks for updates first.
    static void InstallLauncher()
    {
        string self = Assembly.GetExecutingAssembly().Location;
        string launcher = Path.Combine(InstallDir, LauncherFile);
        if (!string.Equals(Path.GetFullPath(self), Path.GetFullPath(launcher), StringComparison.OrdinalIgnoreCase))
        {
            try { File.Copy(self, launcher, true); } catch (IOException) { }
        }
        string game = Path.Combine(InstallDir, GameFile);
        Shortcut(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), Title + ".lnk"), launcher, game);
        string menu = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), Title);
        Directory.CreateDirectory(menu);
        Shortcut(Path.Combine(menu, Title + ".lnk"), launcher, game);
    }

    static void Shortcut(string path, string target, string icon)
    {
        try
        {
            Type shellType = Type.GetTypeFromProgID("WScript.Shell");
            object shell = Activator.CreateInstance(shellType);
            object lnk = shellType.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { path });
            Type t = lnk.GetType();
            t.InvokeMember("TargetPath", BindingFlags.SetProperty, null, lnk, new object[] { target });
            t.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, lnk, new object[] { InstallDir });
            t.InvokeMember("IconLocation", BindingFlags.SetProperty, null, lnk, new object[] { icon + ",0" });
            t.InvokeMember("Description", BindingFlags.SetProperty, null, lnk, new object[] { "Play " + Title });
            t.InvokeMember("Save", BindingFlags.InvokeMethod, null, lnk, null);
        }
        catch (Exception)
        {
            // Shortcuts are a convenience; the game still runs without them.
        }
    }
}
