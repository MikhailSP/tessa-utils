using System;
using System.Collections.Generic;
using System.Linq;
using Tessa.Extensions.Shared.Orm.Util;

namespace Tessa.Extensions.Shared.Orm.PartBuilder
{
    /// <summary>
    /// Формирователь части WHERE SQL-запроса
    /// </summary>
    public class Where
    {
        private readonly HashSet<string> conditions=new HashSet<string>();
        
        public string Get =>
            this.conditions.Any()
                ? "WHERE " + string.Join(" AND ", this.conditions)
                : "";

        public void Eq(string field, object value)
        {
            if (value == null)
            {
                this.conditions.Add(field + " IS NULL");
            }
            else
            {
                this.conditions.Add(field+"="+OrmUtils.Stringify(value));
            }
        }
        
        public void Eq<T>(T field, object value) where T : Enum 
        {
            this.Eq(field.ToString(),value);
        }

        public void In<T,TK>(T field, List<TK> values) where T : Enum
        {
            if (values==null || !values.Any()) return;
            this.conditions.Add($"{field.ToString()} IN ({OrmUtils.Stringify(values, true)})");
        }
    }
}