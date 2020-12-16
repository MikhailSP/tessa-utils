using System;
using System.Collections.Generic;
using System.Text;

namespace Tessa.Extensions.Shared.Orm.Util
{
    public static class OrmUtils
    {
        private const string SectionClassSuffix = "Class";


        public static string Stringify<T>(IEnumerable<T> values, bool ignoreNull)
        {
            var sb = new StringBuilder();
            var needComma = false;
            foreach (var value in values)
            {
                if (ignoreNull && value==null) continue;
                if (needComma)
                {
                    sb.Append(",");
                }
                sb.Append(Stringify(value));
                needComma = true;
            }

            return sb.ToString();
        }
        
        public static string Stringify(object value)
        {
            if (value == null) return "NULL";
            if (value is Guid) return $"'{value}'";
            if (value is string) return $"'{value}'";
            if (value is DateTime) return $"'{(DateTime)value:yyyy-MM-dd HH:mm:ss}'"; 
            return value.ToString();
        }

        public static string GetTableNameByType(Type type)
        {
            var name = type.Name;
            return name.EndsWith(SectionClassSuffix) 
                ? name.Substring(0, name.Length - SectionClassSuffix.Length) 
                : name;
        }
    }
}