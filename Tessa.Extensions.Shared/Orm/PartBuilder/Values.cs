using System;
using System.Collections.Generic;
using Tessa.Extensions.Shared.Orm.Util;

namespace Tessa.Extensions.Shared.Orm.PartBuilder
{
    public class Values
    {
        private Dictionary<Enum, object> values=new Dictionary<Enum, object>();

        public string Get
        {
            get
            {
                var result = "SET ";
                bool first = true;
                foreach (var pair in this.values)
                {
                    if (!first)
                    {
                        result += ", ";
                    }
                    result += pair.Key.ToString() + "=" + OrmUtils.Stringify(pair.Value);
                    first = false;
                }
                return result + " ";
            }
        }

        public void Add(Enum field, object value)
        {
            this.values.Add(field,value);
        }
    }
}