using System.Collections.Generic;
using System.Linq;

namespace Tessa.Extensions.Shared.Orm.PartBuilder
{
    public class OrderBy
    {
        private readonly HashSet<string> fields=new HashSet<string>();
        
        public string Get =>
            this.fields.Any()
                ? "ORDER BY " + string.Join(", ", this.fields)+";"
                : ";";

        public void Asc<T>(T field)
        {
            this.fields.Add(field.ToString());
        }        
        
        public void Desc<T>(T field)
        {
            this.fields.Add(field+" DESC");
        }
    }
}