// This source code is a part of project violet-server.
// Copyright (C)2020-2021. violet-team. Licensed under the MIT Licence.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;

namespace hsync
{
    public class Internals
    {
        public static DateTime GetBuildDate()
        {
            const string BuildVersionMetadataPrefix = "+build";

            var attribute = Assembly.GetExecutingAssembly().GetCustomAttribute<AssemblyInformationalVersionAttribute>();
            if (attribute?.InformationalVersion != null)
            {
                var value = attribute.InformationalVersion;
                var index = value.IndexOf(BuildVersionMetadataPrefix);
                if (index > 0)
                {
                    value = value.Substring(index + BuildVersionMetadataPrefix.Length);
                    if (DateTime.TryParseExact(value, "yyyyMMddHHmmss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var result))
                    {
                        return result;
                    }
                }
            }

            return default;
        }

        #region Low Level

        public const BindingFlags DefaultBinding = BindingFlags.NonPublic |
                         BindingFlags.Instance | BindingFlags.IgnoreCase | BindingFlags.Public | BindingFlags.FlattenHierarchy;

        public const BindingFlags CommonBinding = BindingFlags.Instance | BindingFlags.Public;

        public static List<FieldInfo> get_all_fields(Type t, BindingFlags flags)
        {
            if (t == null)
                return new List<FieldInfo>();

            var list = t.GetFields(flags).ToList();
            list.AddRange(get_all_fields(t.BaseType, flags));
            return list;
        }

        public static List<FieldInfo> enum_recursion(object obj, string[] bb, int ptr)
        {
            if (bb.Length == ptr)
            {
                return get_all_fields(obj.GetType(), DefaultBinding);
            }
            return enum_recursion(obj.GetType().GetField(bb[ptr], DefaultBinding).GetValue(obj), bb, ptr + 1);
        }

        public static List<FieldInfo> enum_recursion(object obj, string[] bb, int ptr, BindingFlags option)
        {
            if (bb.Length == ptr)
            {
                return obj.GetType().GetFields(option).ToList();
            }
            var x = obj.GetType().GetField(bb[ptr], DefaultBinding);
            return enum_recursion(obj.GetType().GetField(bb[ptr], DefaultBinding).GetValue(obj), bb, ptr + 1, option);
        }

        public static object get_recursion(object obj, string[] bb, int ptr)
        {
            if (bb.Length == ptr)
            {
                return obj;
            }
            return get_recursion(obj.GetType().GetField(bb[ptr], DefaultBinding).GetValue(obj), bb, ptr + 1);
        }

        public static void set_recursion(object obj, string[] bb, int ptr, object val)
        {
            if (bb.Length - 1 == ptr)
            {
                obj.GetType().GetField(bb[ptr]).SetValue(obj,
                    Convert.ChangeType(val, obj.GetType().GetField(bb[ptr], DefaultBinding).GetValue(obj).GetType()));
                return;
            }
            set_recursion(obj.GetType().GetField(bb[ptr]).GetValue(obj), bb, ptr + 1, val);
        }

        public static List<MethodInfo> enum_methods(object obj, string[] bb, int ptr, BindingFlags option)
        {
            if (bb.Length == ptr)
            {
                return obj.GetType().GetMethods(option).ToList();
            }
            var x = obj.GetType().GetField(bb[ptr], DefaultBinding);
            return enum_methods(obj.GetType().GetField(bb[ptr], DefaultBinding).GetValue(obj), bb, ptr + 1, option);
        }

        public static object call_method(object obj, string[] bb, int ptr, BindingFlags option, object[] param)
        {
            if (bb.Length - 1 == ptr)
            {
                return obj.GetType().GetMethods(option | BindingFlags.Static).Where(y => y.Name == bb[ptr]).ToList()[0].Invoke(obj, param);
            }
            var x = obj.GetType().GetField(bb[ptr], DefaultBinding | BindingFlags.Static);
            return call_method(obj.GetType().GetField(bb[ptr], DefaultBinding | BindingFlags.Static).GetValue(obj), bb, ptr + 1, option, param);
        }

        public static ParameterInfo[] get_method_paraminfo(object obj, string[] bb, int ptr, BindingFlags option)
        {
            if (bb.Length - 1 == ptr)
            {
                return obj.GetType().GetMethods(option).Where(y => y.Name == bb[ptr]).ToList()[0].GetParameters();
            }
            var x = obj.GetType().GetField(bb[ptr], DefaultBinding);
            return get_method_paraminfo(obj.GetType().GetField(bb[ptr], DefaultBinding).GetValue(obj), bb, ptr + 1, option);
        }

        #endregion
    }
}
