using System;
using System.Reflection;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Markup;
using System.Windows.Media;

namespace Cardline
{
    internal static class Ui
    {
        internal static readonly FontFamily Font = new FontFamily("Microsoft YaHei UI");

        internal static void Initialize()
        {
            if (Application.Current.Resources.Contains("Surface")) return;
            using (var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("Cardline.Theme.xaml"))
                Application.Current.Resources.MergedDictionaries.Add((ResourceDictionary)XamlReader.Load(stream));
            ApplyTheme(Palette.Current, Palette.CurrentDark);
        }

        // Rewrites the shared application brushes so the line, toolbar, dialogs and announcement follow the chosen theme.
        internal static void ApplyTheme(string theme, bool dark)
        {
            foreach (string key in Palette.Keys) Application.Current.Resources[key] = Palette.Brush(theme, dark, key);
        }

        internal static T Load<T>(string name) where T : class
        {
            Initialize();
            using (var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("Cardline." + name + ".xaml"))
                return (T)XamlReader.Load(stream);
        }

        internal static Brush Brush(string name) { return (Brush)Application.Current.FindResource(name); }
        internal static TextBlock Text(string text, double size, bool muted)
        { return new TextBlock { Text = text, FontFamily = Font, FontSize = size, Foreground = Brush(muted ? "Muted" : "Ink") }; }

        internal static Button Button(string text, Action action)
        {
            var button = new Button { Content = text, Style = (Style)Application.Current.FindResource(typeof(Button)), FontFamily = Font };
            button.Click += delegate { action(); };
            return button;
        }
    }
}
