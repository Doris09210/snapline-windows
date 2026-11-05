using System;
using System.Collections.Generic;
using System.Windows.Media;

namespace Cardline
{
    // Single source of truth for every surface in the app: the line, cards, settings, file tools and the shelf.
    // Four flat palettes, each with a light and a dark variant. Keys are shared by every consumer.
    internal static class Palette
    {
        internal const string DefaultTheme = "Mint";
        internal static readonly string[] Themes = { "Mint", "Sky", "Sakura", "Lime" };
        internal static readonly string[] Labels = { "薄荷", "天空", "樱花", "青柠" };
        internal static readonly string[] Keys = { "Paper", "Surface", "Sidebar", "Tint", "Ink", "Muted", "Line", "Accent", "AccentSoft", "Track", "NavSelected", "PrimaryFill", "PrimaryText", "Success" };

        private static readonly Dictionary<string, string[]> Light = new Dictionary<string, string[]> {
            { "Mint",   new[] { "#F4FAF7", "#FFFFFF", "#E9F5EF", "#E3F6EE", "#1F3A33", "#6B8A80", "#D6E8E0", "#2BB68A", "#E3F6EE", "#CFE3DA", "#D4F0E4", "#2BB68A", "#FFFFFF", "#2BB68A" } },
            { "Sky",    new[] { "#F3F8FD", "#FFFFFF", "#E8F1FB", "#E4F0FC", "#1E3148", "#6A8199", "#D5E3F0", "#3B8BEB", "#E4F0FC", "#CBDCEC", "#D4E6F9", "#3B8BEB", "#FFFFFF", "#2BB68A" } },
            { "Sakura", new[] { "#FDF6F8", "#FFFFFF", "#FAEBF0", "#FBE6EE", "#3B2A33", "#8C7480", "#F0DCE3", "#E8739A", "#FBE6EE", "#ECD3DB", "#F8D9E4", "#E8739A", "#FFFFFF", "#2BB68A" } },
            { "Lime",   new[] { "#F8FBEF", "#FFFFFF", "#EFF6DF", "#EEF6DA", "#2B3522", "#78846A", "#E0E8CD", "#7CB518", "#EEF6DA", "#D4DFBE", "#E3EFC6", "#7CB518", "#FFFFFF", "#7CB518" } }
        };
        private static readonly Dictionary<string, string[]> Dark = new Dictionary<string, string[]> {
            { "Mint",   new[] { "#16211E", "#1E2B27", "#132019", "#22332D", "#E6F2EC", "#93AFA5", "#2E423B", "#4FD1A5", "#1F3D33", "#3A5047", "#24413A", "#4FD1A5", "#0F2A22", "#4FD1A5" } },
            { "Sky",    new[] { "#15202C", "#1D2A38", "#111B26", "#22323F", "#E4EEF8", "#8FA6BE", "#2C3E52", "#6FAEF5", "#1E3550", "#3A4F66", "#243B55", "#6FAEF5", "#0D1F33", "#4FD1A5" } },
            { "Sakura", new[] { "#241B1F", "#2E2328", "#1E161A", "#362A30", "#F4E8EC", "#B597A3", "#45343B", "#F19AB8", "#4A2C38", "#5A434C", "#4A3038", "#F19AB8", "#2E141F", "#4FD1A5" } },
            { "Lime",   new[] { "#1C2117", "#252C1E", "#161B12", "#2C3524", "#ECF2E0", "#A1AE8F", "#3A4530", "#A4D65E", "#2F4320", "#4A583A", "#35462A", "#A4D65E", "#172310", "#A4D65E" } }
        };

        private static string current = DefaultTheme;
        private static string appearance = "Light";

        // The theme the whole application currently shows. Set once at startup and again whenever settings are saved.
        internal static string Current { get { return current; } }
        internal static string Appearance { get { return appearance; } }
        internal static bool CurrentDark { get { return IsDark(appearance); } }

        internal static void Set(string theme, string mode)
        {
            current = Normalize(theme);
            appearance = mode == "Dark" || mode == "System" ? mode : "Light";
        }

        internal static string Normalize(string theme)
        { return Array.IndexOf(Themes, theme) >= 0 ? theme : DefaultTheme; }

        internal static string Label(string theme)
        { int index = Array.IndexOf(Themes, Normalize(theme)); return Labels[index]; }

        internal static bool IsDark(string mode)
        {
            return mode == "Dark" || (mode == "System" && Equals(Microsoft.Win32.Registry.GetValue(
                @"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme", 1), 0));
        }

        internal static string Hex(string theme, bool dark, string key)
        {
            int index = Array.IndexOf(Keys, key);
            if (index < 0) throw new ArgumentException("Unknown palette key " + key);
            return (dark ? Dark : Light)[Normalize(theme)][index];
        }

        internal static Color Color(string theme, bool dark, string key)
        { return (Color)ColorConverter.ConvertFromString(Hex(theme, dark, key)); }

        internal static Color Color(string key) { return Color(current, CurrentDark, key); }

        internal static SolidColorBrush Brush(string theme, bool dark, string key)
        { var brush = new SolidColorBrush(Color(theme, dark, key)); brush.Freeze(); return brush; }

        internal static SolidColorBrush Brush(string key) { return Brush(current, CurrentDark, key); }

        // Linear blend used for hover / pressed derivatives so every theme stays a single table.
        internal static Color Mix(Color from, Color to, double amount)
        {
            amount = Math.Max(0, Math.Min(1, amount));
            return System.Windows.Media.Color.FromRgb(
                (byte)Math.Round(from.R + (to.R - from.R) * amount),
                (byte)Math.Round(from.G + (to.G - from.G) * amount),
                (byte)Math.Round(from.B + (to.B - from.B) * amount));
        }

        internal static string MixHex(string theme, bool dark, string fromKey, string toKey, double amount)
        {
            var color = Mix(Color(theme, dark, fromKey), Color(theme, dark, toKey), amount);
            return "#" + color.R.ToString("X2") + color.G.ToString("X2") + color.B.ToString("X2");
        }
    }
}
