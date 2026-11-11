using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Accessibility;

public static class FlutterAccessibility
{
    private static readonly List<string> names = new List<string>();
    public static string LastNames { get { return string.Join(" | ", names); } }

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr FindWindowEx(
        IntPtr parent, IntPtr after, string className, string title);

    [DllImport("oleacc.dll")]
    private static extern int AccessibleObjectFromWindow(
        IntPtr window, uint objectId, ref Guid interfaceId,
        [MarshalAs(UnmanagedType.Interface)] out IAccessible accessible);

    public sealed class Control
    {
        private readonly IAccessible accessible;
        private readonly int child;

        internal Control(IAccessible accessible, int child)
        {
            this.accessible = accessible;
            this.child = child;
        }

        public void Invoke()
        {
            accessible.accDoDefaultAction(child);
        }

        public bool IsChecked
        {
            get { return (Convert.ToInt32(accessible.get_accState(child)) & 0x10) != 0; }
        }

        public bool IsSelected
        {
            get { return (Convert.ToInt32(accessible.get_accState(child)) & 0x02) != 0; }
        }

    }

    public static Control Find(IntPtr window, string name, bool matchSuffix = false,
        int role = 0)
    {
        return FindControl(window, (accessible, child) =>
        {
            var candidate = NameOf(accessible, child);
            return candidate != null &&
                (matchSuffix ? candidate.EndsWith(name, StringComparison.Ordinal) : candidate == name) &&
                (role == 0 || Convert.ToInt32(accessible.get_accRole(child)) == role);
        });
    }

    public static Control FindValue(IntPtr window, string value)
    {
        return FindControl(window, (accessible, child) => accessible.get_accValue(child) == value);
    }

    private static Control FindControl(IntPtr window, Func<IAccessible, int, bool> matches)
    {
        names.Clear();
        var view = FindWindowEx(window, IntPtr.Zero, "FLUTTERVIEW", null);
        if (view == IntPtr.Zero) return null;

        var id = typeof(IAccessible).GUID;
        IAccessible root;
        if (AccessibleObjectFromWindow(view, unchecked((uint)-4), ref id, out root) != 0)
            return null;

        return FindIn(root, matches);
    }

    private static Control FindIn(IAccessible accessible, Func<IAccessible, int, bool> matches)
    {
        var currentName = NameOf(accessible, 0);
        if (!string.IsNullOrEmpty(currentName)) names.Add(currentName);
        if (Matches(accessible, 0, matches)) return new Control(accessible, 0);

        int count;
        try { count = accessible.accChildCount; }
        catch (COMException) { return null; }
        catch (ArgumentException) { return null; }
        for (var child = 1; child <= count; child++)
        {
            IAccessible node = null;
            try { node = accessible.get_accChild(child) as IAccessible; }
            catch (ArgumentException) { }
            catch (COMException) { }
            if (node != null)
            {
                var found = FindIn(node, matches);
                if (found != null) return found;
            }
            else if (Matches(accessible, child, matches))
            {
                return new Control(accessible, child);
            }
        }
        return null;
    }

    private static bool Matches(IAccessible accessible, int child, Func<IAccessible, int, bool> matches)
    {
        try { return matches(accessible, child); }
        catch (ArgumentException) { return false; }
        catch (COMException) { return false; }
    }

    private static string NameOf(IAccessible accessible, int child)
    {
        try { return accessible.get_accName(child); }
        catch (ArgumentException) { return null; }
        catch (COMException) { return null; }
    }
}

public static class ApehTrayCheck
{
    [StructLayout(LayoutKind.Sequential)]
    private struct IconIdentifier
    {
        public int Size;
        public IntPtr Window;
        public uint Id;
        public Guid Guid;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Rect
    {
        public int Left, Top, Right, Bottom;
    }

    [DllImport("shell32.dll")]
    private static extern int Shell_NotifyIconGetRect(ref IconIdentifier icon, out Rect rect);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr window);

    [DllImport("user32.dll")]
    private static extern bool PostMessage(IntPtr window, uint message, IntPtr wparam, IntPtr lparam);

    public static bool HasIcon(IntPtr window)
    {
        var icon = new IconIdentifier
        {
            Size = Marshal.SizeOf(typeof(IconIdentifier)),
            Window = window,
            Id = 1
        };
        Rect rect;
        return Shell_NotifyIconGetRect(ref icon, out rect) == 0;
    }

    public static bool Minimize(IntPtr window)
    {
        return PostMessage(window, 0x0112, new IntPtr(0xf020), IntPtr.Zero);
    }

    public static bool ActivateIcon(IntPtr window)
    {
        return PostMessage(window, 0x8001, IntPtr.Zero, new IntPtr(0x10000 | 0x0400));
    }
}
