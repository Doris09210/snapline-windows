using System;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Effects;
using System.Windows.Shapes;
using System.Windows.Threading;

namespace Cardline
{
    internal sealed class ShotCard : Grid
    {
        internal readonly Shot Shot;
        private readonly Controller controller;
        private readonly RotateTransform rotation;
        private readonly ScaleTransform scale = new ScaleTransform(1, 1);
        private readonly TranslateTransform ropeOffset = new TranslateTransform();
        private readonly RotateTransform ropeTilt = new RotateTransform();
        internal readonly PhysicalCard Physics;
        private readonly Border badge;
        private readonly Button remove;
        private readonly DispatcherTimer hold;
        private readonly DispatcherTimer click;
        private Point? down;
        private bool held;

        internal ShotCard(Shot shot, Controller controller)
        {
            Shot = shot;
            this.controller = controller;
            Width = 160;
            shot.GetThumbnail();
            double fit = Math.Min(136.0 / shot.Thumbnail.Width, 104.0 / shot.Thumbnail.Height);
            double photoWidth = shot.Thumbnail.Width * fit;
            double photoHeight = shot.Thumbnail.Height * fit;
            Height = photoHeight + 48;
            Focusable = false;
            Cursor = Cursors.Hand;
            RenderTransformOrigin = new Point(0.5, 0.02);
            rotation = new RotateTransform(shot.Tilt);
            var transforms = new TransformGroup();
            transforms.Children.Add(scale);
            transforms.Children.Add(rotation);
            transforms.Children.Add(ropeTilt);
            transforms.Children.Add(ropeOffset);
            RenderTransform = transforms;
            Physics = new PhysicalCard(this, ropeTilt, null);
            AutomationProperties.SetName(this, "截图 " + System.IO.Path.GetFileName(shot.Path));
            ToolTip = "单击 / C 复制 · 双击预览 · 长按 / A 编辑 · D 或 Delete 取下 · 拖出使用";

            var image = new Image { Source = shot.Thumbnail, Width = photoWidth, Height = photoHeight, Stretch = Stretch.Uniform,
                Clip = new RectangleGeometry(new Rect(0, 0, photoWidth, photoHeight), 6, 6) };
            RenderOptions.SetBitmapScalingMode(image, BitmapScalingMode.HighQuality);
            // Flat card: a solid surface with rounded corners and a 2px border in the theme accent. No glass, no shadow.
            var frame = new Border {
                Name = "CardFrame",
                Width = photoWidth + 20, Height = photoHeight + 20,
                CornerRadius = new CornerRadius(12), Padding = new Thickness(8),
                Background = Ui.Brush("Surface"), BorderBrush = Ui.Brush("Accent"), BorderThickness = new Thickness(2),
                Child = image,
                HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Top,
                Margin = new Thickness(0, 14, 0, 0)
            };
            Children.Add(frame);
            Children.Add(Peg());

            remove = new Button {
                Content = "×", FontFamily = new FontFamily("Segoe UI"), FontSize = 15, Width = 22, Height = 22,
                Foreground = Ui.Brush("PrimaryText"), Background = Ui.Brush("Accent"), Style = (Style)Application.Current.FindResource(typeof(Button)),
                BorderBrush = Ui.Brush("Surface"), BorderThickness = new Thickness(2),
                Padding = new Thickness(0), HorizontalAlignment = HorizontalAlignment.Left, VerticalAlignment = VerticalAlignment.Top,
                Margin = new Thickness((Width - frame.Width) / 2 + 3, 17, 0, 0), Opacity = 0, Focusable = false,
                ToolTip = controller.Store.Owns(shot.Path) ? "取下截图：收件夹图片进入回收站" : "取下截图：保留外部原文件"
            };
            AutomationProperties.SetName(remove, "取下截图");
            remove.Click += delegate { controller.Discard(Shot); };
            Children.Add(remove);
            badge = new Border {
                Child = new TextBlock { Text = "✓ 已复制", FontFamily = Ui.Font, Foreground = Ui.Brush("PrimaryText"), FontSize = 11 },
                Background = Ui.Brush("Accent"), CornerRadius = new CornerRadius(11),
                Padding = new Thickness(10, 4, 10, 4), VerticalAlignment = VerticalAlignment.Bottom,
                HorizontalAlignment = HorizontalAlignment.Center, Visibility = Visibility.Hidden, IsHitTestVisible = false
            };
            Children.Add(badge);

            hold = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(450) };
            hold.Tick += delegate { hold.Stop(); if (down != null) { held = true; EndPress(); controller.Edit(Shot); } };
            click = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(System.Windows.Forms.SystemInformation.DoubleClickTime) };
            click.Tick += delegate { click.Stop(); controller.Copy(Shot); };
            PreviewMouseLeftButtonDown += Press;
            PreviewMouseLeftButtonUp += Release;
            PreviewMouseMove += Move;
            LostMouseCapture += delegate { hold.Stop(); down = null; controller.Busy = false; };
            MouseEnter += delegate { remove.Opacity = 1; ScaleTo(1.035); };
            MouseLeave += delegate { remove.Opacity = 0; if (down == null) ScaleTo(1); };
            ContextMenu = Menu();
            ContextMenu.Opened += delegate { controller.Busy = true; };
            ContextMenu.Closed += delegate { controller.Busy = false; };
        }

        // A small cartoon peg: a soft pill body with a slit and a round hook, all in the theme colors.
        private static Canvas Peg()
        {
            var peg = new Canvas { Name = "CardPeg", Width = 16, Height = 28,
                HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Top, IsHitTestVisible = false };
            var body = new Rectangle { Width = 16, Height = 24, RadiusX = 8, RadiusY = 8, Fill = Ui.Brush("AccentSoft"), Stroke = Ui.Brush("Accent"), StrokeThickness = 2 };
            Canvas.SetLeft(body, 0); Canvas.SetTop(body, 4); peg.Children.Add(body);
            var slit = new Rectangle { Width = 6, Height = 2, RadiusX = 1, RadiusY = 1, Fill = Ui.Brush("Accent") };
            Canvas.SetLeft(slit, 5); Canvas.SetTop(slit, 14); peg.Children.Add(slit);
            var hook = new Ellipse { Width = 8, Height = 8, Fill = Ui.Brush("Surface"), Stroke = Ui.Brush("Accent"), StrokeThickness = 2 };
            Canvas.SetLeft(hook, 4); Canvas.SetTop(hook, 0); peg.Children.Add(hook);
            return peg;
        }

        private ContextMenu Menu()
        {
            var menu = new ContextMenu();
            Add(menu, "复制图片", delegate { controller.Copy(Shot); });
            Add(menu, "打开预览", delegate { controller.Open(Shot); });
            Add(menu, "用画图编辑", delegate { controller.Edit(Shot); });
            Add(menu, "另存为…", delegate { controller.Export(Shot); });
            Add(menu, "转格式 / PDF…", delegate { Dispatcher.BeginInvoke(new Action(delegate { controller.OpenFileTools(FileTool.Convert, new[] { Shot.Path }); })); });
            Add(menu, "在文件夹中显示", delegate { controller.Reveal(Shot); });
            menu.Items.Add(new Separator());
            Add(menu, "取下截图", delegate { controller.Discard(Shot); });
            return menu;
        }

        private static void Add(ContextMenu menu, string label, Action action)
        {
            var item = new MenuItem { Header = label };
            item.Click += delegate { action(); };
            menu.Items.Add(item);
        }

        private void Press(object sender, MouseButtonEventArgs e)
        {
            if (e.Handled || FromRemove(e.OriginalSource as DependencyObject)) return;
            e.Handled = true;
            if (e.ClickCount == 2) { click.Stop(); EndPress(); controller.Open(Shot); return; }
            down = e.GetPosition(controller.Line);
            held = false;
            controller.Busy = true;
            CaptureMouse();
            hold.Start();
            ScaleTo(0.95);
        }

        private void Release(object sender, MouseButtonEventArgs e)
        {
            if (e.Handled || FromRemove(e.OriginalSource as DependencyObject)) return;
            bool shouldCopy = down != null && !held;
            EndPress();
            if (shouldCopy) { click.Stop(); click.Start(); }
            e.Handled = true;
        }

        private bool FromRemove(DependencyObject source)
        {
            while (source != null && source != this)
            {
                if (source == remove) return true;
                source = VisualTreeHelper.GetParent(source);
            }
            return false;
        }

        private void Move(object sender, MouseEventArgs e)
        {
            if (down == null || held || e.LeftButton != MouseButtonState.Pressed) return;
            var position = e.GetPosition(controller.Line);
            if (Math.Abs(position.X - down.Value.X) < SystemParameters.MinimumHorizontalDragDistance &&
                Math.Abs(position.Y - down.Value.Y) < SystemParameters.MinimumVerticalDragDistance) return;
            var origin = down.Value;
            click.Stop();
            EndPress();
            controller.Busy = true;
            Opacity = 0.45;
            controller.Files.Window.ExternalDragStarted();
            bool released = false, canceled = false;
            QueryContinueDragEventHandler query = delegate(object source, QueryContinueDragEventArgs args) {
                if (args.EscapePressed || args.Action == DragAction.Cancel) { canceled = true; return; }
                if ((args.KeyStates & DragDropKeyStates.LeftMouseButton) == 0) released = true;
            };
            QueryContinueDrag += query;
            controller.Line.BeginRopeDrag(this, origin);
            try {
                // Receivers get a copy, leaving the original available on the line.
                var result = DragDrop.DoDragDrop(this, controller.Data(Shot), DragDropEffects.Copy);
                CompleteDrag(result, released, canceled, controller.Line.PixelBounds.Contains(Native.Cursor()));
            }
            finally {
                QueryContinueDrag -= query;
                controller.Line.EndRopeDrag();
                controller.Files.Window.ExternalDragEnded(); Opacity = 1; controller.Busy = false; controller.Store.Prune();
            }
        }

        internal void CompleteDrag(DragDropEffects result, bool released, bool canceled, bool overLine)
        {
            if (controller.Store.Settings.RemoveOnBlankDrop && result == DragDropEffects.None && released && !canceled && !overLine)
                controller.Detach(Shot);
        }

        internal void FollowRope(Vector offset)
        {
            ropeOffset.X = offset.X; ropeOffset.Y = offset.Y;
            Physics.Pull(-offset.X * .4);
        }

        private void EndPress()
        {
            hold.Stop();
            down = null;
            if (IsMouseCaptured) ReleaseMouseCapture();
            controller.Busy = false;
            ScaleTo(IsMouseOver ? 1.035 : 1);
        }

        private void ScaleTo(double value)
        {
            if (!SystemParameters.ClientAreaAnimation) { scale.ScaleX = scale.ScaleY = value; return; }
            var animation = new DoubleAnimation(value, TimeSpan.FromMilliseconds(160));
            scale.BeginAnimation(ScaleTransform.ScaleXProperty, animation);
            scale.BeginAnimation(ScaleTransform.ScaleYProperty, animation);
        }

        internal void Sway(double amount)
        {
            if (!SystemParameters.ClientAreaAnimation || down != null) return;
            Physics.Kick(amount);
        }

        internal void Copied()
        {
            badge.Visibility = Visibility.Visible;
            Sway(3);
            var timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(1200) };
            timer.Tick += delegate { timer.Stop(); badge.Visibility = Visibility.Hidden; };
            timer.Start();
        }
    }
}
