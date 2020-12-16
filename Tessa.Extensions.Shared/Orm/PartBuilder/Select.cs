using System;
using System.Collections.Generic;
using System.Linq;

namespace Tessa.Extensions.Shared.Orm.PartBuilder
{
    /// <summary>
    /// Формирователь части SELECT SQL-запроса
    /// </summary>
    public class Select
    {
        private readonly HashSet<string> fields = new HashSet<string>();
        private int top;

        public string Get
        {
            get
            {
                var topStr = this.top == 0 ? "" : $"TOP {this.top}";
                if (this.fields.Any()) return $"SELECT {topStr} " + string.Join(",", this.fields) + " ";
                return $"SELECT {topStr} * ";
            }
        }

        public void Add(string field)
        {
            this.fields.Add(field);
        }

        public void Add<T>(T field) where T : Enum 
        {
            this.fields.Add(field.ToString());
        }

        public void Top(int top)
        {
            this.top = top;
        }
    }
}