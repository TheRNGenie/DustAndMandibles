// Dust & Mandibles setup and launcher.
//
// Downloads the latest game build from the GitHub Releases page, installs it to
// %LOCALAPPDATA%\DustAndMandibles, adds Desktop and Start Menu shortcuts, and
// starts the game. Run it again (or use the shortcut) and it checks for a newer
// release first, so it doubles as the updater. The game is one .exe, its data
// (DustAndMandibles.pck, which the release splits into parts under GitHub's
// 2 GiB-per-file limit; they're joined back here) and any .dll files the
// release carries (the Epic Online Services libraries for online invites), all
// placed side by side; nothing else needs installing.
//
// "--safe" (the Start Menu's Safe Mode shortcut) starts the game on the OpenGL
// renderer with Low graphics, for old or integrated GPUs that can't run Vulkan.
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
    const string DataFile = "DustAndMandibles.pck";
    const string LauncherFile = "Dust & Mandibles Launcher.exe";
    const string Title = "Dust & Mandibles";

    static string InstallDir
    {
        get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DustAndMandibles"); }
    }

    static int Main(string[] args)
    {
        bool safe = Array.IndexOf(args, "--safe") >= 0;
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
            string[] libs = new string[0];
            string[] parts = new string[0];
            long dataSize = 0;
            try
            {
                Console.WriteLine("Checking GitHub for the latest version...");
                FindLatest(out tag, out url, out libs, out parts, out dataSize);
            }
            catch (Exception e)
            {
                if (!File.Exists(game))
                    throw new Exception("Couldn't reach GitHub to download the game. (" + e.Message + ")");
                Console.WriteLine("Couldn't reach GitHub, starting the installed version.");
            }

            bool libsMissing = false;
            foreach (string lib in libs)
                if (!File.Exists(Path.Combine(InstallDir, Path.GetFileName(lib)))) libsMissing = true;
            string data = Path.Combine(InstallDir, DataFile);
            bool dataMissing = parts.Length > 0 && (!File.Exists(data) || new FileInfo(data).Length != dataSize);
            if (tag != null && (tag != installed || !File.Exists(game) || libsMissing || dataMissing))
            {
                Console.WriteLine(installed == "" ? "Installing " + tag + "..." : "Updating " + installed + " -> " + tag + "...");
                // The game's data first (the big part), joined from its parts.
                if (parts.Length > 0)
                {
                    string joined = data + ".joining";
                    if (File.Exists(joined)) File.Delete(joined);
                    for (int i = 0; i < parts.Length; i++)
                    {
                        Console.WriteLine("  Game data, part " + (i + 1) + " of " + parts.Length + ":");
                        string piece = data + ".part";
                        Download(parts[i], piece);
                        using (var outS = new FileStream(joined, FileMode.Append, FileAccess.Write))
                        using (var inS = File.OpenRead(piece))
                            inS.CopyTo(outS, 1 << 20);
                        File.Delete(piece);
                    }
                    if (new FileInfo(joined).Length != dataSize)
                        throw new Exception("the game data came down the wrong size; run setup again");
                    if (File.Exists(data)) File.Delete(data);
                    File.Move(joined, data);
                }
                else if (File.Exists(data))
                {
                    File.Delete(data); // (an older build with its data inside the .exe)
                }
                Console.WriteLine("  The game:");
                Download(url, game);
                // Libraries next to the game (online play). The game still runs
                // without them, with direct invites only, so a failure isn't fatal.
                foreach (string lib in libs)
                {
                    try { Download(lib, Path.Combine(InstallDir, Uri.UnescapeDataString(Path.GetFileName(lib)))); }
                    catch (Exception e) { Console.WriteLine("  (skipped " + Path.GetFileName(lib) + ": " + e.Message + ")"); }
                }
                File.WriteAllText(versionFile, tag);
            }
            else if (tag != null)
            {
                Console.WriteLine("You have the latest version (" + tag + ").");
            }

            InstallLauncher();
            Console.WriteLine();
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine(safe ? "Saddle up. Starting the game in Safe Mode..." : "Saddle up. Starting the game...");
            Console.ResetColor();
            var start = new ProcessStartInfo(game) { WorkingDirectory = InstallDir, UseShellExecute = true };
            if (safe)
                start.Arguments = "--rendering-method gl_compatibility -- --safe";
            Process.Start(start);
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

    // Reads the latest release's tag, the game's download link, the links of the
    // game data's parts (in order) with their total size, and the links of any
    // .dll files to put next to it, from the GitHub API.
    static void FindLatest(out string tag, out string url, out string[] libs, out string[] parts, out long dataSize)
    {
        string json;
        using (var wc = Client())
        {
            wc.Headers[HttpRequestHeader.Accept] = "application/vnd.github+json";
            json = wc.DownloadString("https://api.github.com/repos/" + Repo + "/releases/latest");
        }
        var t = Regex.Match(json, @"""tag_name""\s*:\s*""([^""]+)""");
        var u = Regex.Match(json, @"""browser_download_url""\s*:\s*""([^""]*/" + Regex.Escape(GameFile) + @")""");
        if (!t.Success || !u.Success)
            throw new Exception("the latest release has no " + GameFile);
        tag = t.Groups[1].Value;
        url = u.Groups[1].Value;
        var found = new System.Collections.Generic.List<string>();
        foreach (Match m in Regex.Matches(json, @"""browser_download_url""\s*:\s*""([^""]*\.dll)"""))
            found.Add(m.Groups[1].Value);
        libs = found.ToArray();
        // Data parts: DustAndMandibles.pck.001, .002, ... Each asset's "size" comes
        // a little before its "browser_download_url" in the same asset object.
        var byNum = new System.Collections.Generic.SortedDictionary<int, string>();
        dataSize = 0;
        string pat = @"""size""\s*:\s*(\d+)[^{}]*?""browser_download_url""\s*:\s*""([^""]*/" + Regex.Escape(DataFile) + @"\.(\d+))""";
        foreach (Match m in Regex.Matches(json, pat))
        {
            byNum[int.Parse(m.Groups[3].Value)] = m.Groups[2].Value;
            dataSize += long.Parse(m.Groups[1].Value);
        }
        parts = new string[byNum.Count];
        byNum.Values.CopyTo(parts, 0);
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
        Shortcut(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), Title + ".lnk"), launcher, game, "");
        string menu = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), Title);
        Directory.CreateDirectory(menu);
        Shortcut(Path.Combine(menu, Title + ".lnk"), launcher, game, "");
        Shortcut(Path.Combine(menu, Title + " (Safe Mode).lnk"), launcher, game, "--safe");
    }

    static void Shortcut(string path, string target, string icon, string arguments)
    {
        try
        {
            Type shellType = Type.GetTypeFromProgID("WScript.Shell");
            object shell = Activator.CreateInstance(shellType);
            object lnk = shellType.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { path });
            Type t = lnk.GetType();
            t.InvokeMember("TargetPath", BindingFlags.SetProperty, null, lnk, new object[] { target });
            t.InvokeMember("Arguments", BindingFlags.SetProperty, null, lnk, new object[] { arguments });
            t.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, lnk, new object[] { InstallDir });
            t.InvokeMember("IconLocation", BindingFlags.SetProperty, null, lnk, new object[] { icon + ",0" });
            t.InvokeMember("Description", BindingFlags.SetProperty, null, lnk, new object[] { arguments == "" ? "Play " + Title
                : "Play " + Title + " with the OpenGL renderer and Low graphics (for old or integrated GPUs)" });
            t.InvokeMember("Save", BindingFlags.InvokeMethod, null, lnk, null);
        }
        catch (Exception)
        {
            // Shortcuts are a convenience; the game still runs without them.
        }
    }
}
