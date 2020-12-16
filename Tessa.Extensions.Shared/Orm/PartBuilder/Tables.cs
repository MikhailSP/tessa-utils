using System;
using System.Collections.Generic;
using System.Linq;
using Tessa.Extensions.Shared.Orm.Util;

namespace Tessa.Extensions.Shared.Orm.PartBuilder
{
    /// <summary>
    /// Формирователь части со списком таблиц для FROM/UPDATE SQL-запроса
    /// </summary>
    public class Tables
    {
        private readonly HashSet<string> tables=new HashSet<string>();
        
        public string GetFrom => "FROM " + this.tables.First() + " ";
        public string GetUpdate => "UPDATE " + this.tables.First() + " ";

        public void Add(string table)
        {
            this.tables.Add(table);
        }
        
        public void Add<T>(T field) where T : Enum 
        {
            this.tables.Add(typeof(T).Name);
        }

        public void Add(Type type)
        {
            this.tables.Add(OrmUtils.GetTableNameByType(type));
        }
    }
}