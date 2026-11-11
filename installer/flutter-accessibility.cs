using System;
using System.Runtime.InteropServices;
using Accessibility;

public static class FlutterAccessibility
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr FindWindowEx(
        IntPtr parent, IntPtr after, string className, string title);

    [DllImport("oleacc.dll")]
    private static extern int AccessibleObjectFromWindow(
        IntPtr window, uint objectId, ref Guid interfaceId,
        [MarshalAs(UnmanagedType.Interface)] out IAccessible accessible);

    [DllImport("oleacc.dll")]
    private static extern int AccessibleChildren(
        IAccessible container, int start, int count,
        [Out, MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 2, ArraySubType = UnmanagedType.Struct)]
        object[] children, out int obtained);

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
    }

    public static Control Find(IntPtr window, string name)
    {
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
        if (accessible.get_accName(0) == name) return new Control(accessible, 0);

        var children = new object[accessible.accChildCount];
        if (children.Length == 0) return null;

        int count;
        AccessibleChildren(accessible, 0, children.Length, children, out count);
        for (var index = 0; index < count; index++)
        {
            var node = children[index] as IAccessible;
            if (node != null)
            {
                var found = FindIn(node, name);
                if (found != null) return found;
            }
            else if (children[index] is int &&
                     accessible.get_accName(children[index]) == name)
            {
                return new Control(accessible, (int)children[index]);
            }
        }
        return null;
    }
}
