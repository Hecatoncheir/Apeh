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

        public bool IsEnabled
        {
            get { return (Convert.ToInt32(accessible.get_accState(child)) & 1) == 0; }
        }
    }

    public static Control Find(IntPtr window, string name)
    {
        names.Clear();
        var view = FindWindowEx(window, IntPtr.Zero, "FLUTTERVIEW", null);
        if (view == IntPtr.Zero) return null;

        var id = typeof(IAccessible).GUID;
        IAccessible root;
        if (AccessibleObjectFromWindow(view, unchecked((uint)-4), ref id, out root) != 0)
            return null;

        return FindIn(root, name);
    }

    private static Control FindIn(IAccessible accessible, string name)
    {
        var currentName = NameOf(accessible, 0);
        if (!string.IsNullOrEmpty(currentName)) names.Add(currentName);
        if (currentName == name) return new Control(accessible, 0);

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
                var found = FindIn(node, name);
                if (found != null) return found;
            }
            else if (NameOf(accessible, child) == name)
            {
                return new Control(accessible, child);
            }
        }
        return null;
    }

    private static string NameOf(IAccessible accessible, int child)
    {
        try { return accessible.get_accName(child); }
        catch (ArgumentException) { return null; }
        catch (COMException) { return null; }
    }
}
