using System;
using System.Collections.Generic;
using System.Linq;
using Tessa.Cards;
using Tessa.Platform.Data;

namespace Tessa.Extensions.Shared
{
    public static class CardExtensions 
    {
        private const string GetNumberOfFilesInDB = @"
            SELECT COUNT(*) FROM Files WHERE ID=@ID";

        /// <summary>
        /// Заполнить секцию значением без уведомления об изменении (выполнит RemoveChanges после изменения)
        /// </summary>
        /// <param name="card">Исходная карточка</param>
        /// <param name="param">Enum указывающий секцию + параметр для заполнения, например MntContracts.ID заполниет поле ID секции MntContracts</param>
        /// <param name="value">Значение</param>
        /// <typeparam name="T">Enum по которому выбирается секция</typeparam>
        public static void FillSectionSilently<T>(this Card card, T param, Object value) where T : Enum
        {
            var cardSection = card.Sections.GetOrAdd(typeof(T).Name);
            cardSection.Fields[param.ToString()] = value;
            cardSection.RemoveChanges();
        }

        /// <summary>
        /// Заполнить секцию значениями без уведомления об изменении (выполнит RemoveChanges после изменения)
        /// </summary>
        /// <param name="card">Исходная карточка</param>
        /// <param name="values">Пары ключ-значение. Ключ - еnum указывающий секцию + параметр для заполнения, например MntContracts.ID заполниет поле ID секции MntContracts. Значение - значение поля</param>
        /// <typeparam name="T">Enum по которому выбирается секция</typeparam>
        public static void FillSectionSilently<T>(this Card card, Dictionary<T, Object> values) where T : Enum
        {
            var cardSection = card.Sections.GetOrAdd(typeof(T).Name);
            foreach (var keyValuePair in values)
            {
                cardSection.Fields[keyValuePair.Key.ToString()] = keyValuePair.Value;
            }
            cardSection.RemoveChanges();
        }

        /// <summary>
        /// Заполнить секцию значением
        /// </summary>
        /// <param name="card">Исходная карточка</param>
        /// <param name="param">Enum указывающий секцию + параметр для заполнения, например MntContracts.ID заполниет поле ID секции MntContracts</param>
        /// <param name="value">Значение</param>
        /// <typeparam name="T">Enum (по названию которого выбирается секция)</typeparam>
        public static void FillSection<T>(this Card card, T param, Object value) where T : Enum
        {
            var cardSection = card.Sections.GetOrAdd(typeof(T).Name);
            cardSection.Fields[param.ToString()] = value;
        }
        
        /// <summary>
        /// Заполнить секцию значениями
        /// </summary>
        /// <param name="card">Исходная карточка</param>
        /// <param name="values">Пары ключ-значение. Ключ - еnum указывающий секцию + параметр для заполнения, например MntContracts.ID заполниет поле ID секции MntContracts. Значение - значение поля</param>
        /// <typeparam name="T">Enum по которому выбирается секция</typeparam>
        public static void FillSection<T>(this Card card, Dictionary<T, Object> values) where T : Enum
        {
            var cardSection = card.Sections.GetOrAdd(typeof(T).Name);
            foreach (var keyValuePair in values)
            {
                cardSection.Fields[keyValuePair.Key.ToString()] = keyValuePair.Value;
            }
        }       

        /// <summary>
        /// Скопировать поля из секции другой карточки
        /// </summary>
        /// <param name="card">Текущая карточка</param>
        /// <param name="other">Карточка поля которой надо скопировать</param>
        /// <param name="fieldsToCopy">Поля, значения которых надо скопировать</param>
        /// <param name="useNullForGuidEmpty">true - использовать null для пустого поля Guid вместе Guid.Empty (0000-...-0000), false - использовать Guid.Empty</param>
        /// <typeparam name="T">Enum (по названию которого выбирается секция)</typeparam>
        public static void CopyFieldsFrom<T>(this Card card, Card other, T[] fieldsToCopy, bool useNullForGuidEmpty=false) where T : Enum
        {
            foreach (T fieldToCopy in fieldsToCopy)
            {
                var value = other.GetSectionValueOrNull(fieldToCopy);
                if (useNullForGuidEmpty && Guid.Empty.Equals(value))
                {
                    value = null;
                }
                card.FillSection(fieldToCopy,value);
            }
        }

        /// <summary>
        /// Скопировать секцию в другую карточку, за исключением указанных полей
        /// </summary>
        /// <param name="card">Текущая карточка</param>
        /// <param name="targetCard">Карточка-назначение (куда скопировать поля из секции)</param>
        /// <param name="excludeFields">Поля, которые необходимо исключить при копировании</param>
        /// <typeparam name="T">Enum (по названию которого выбирается копируемая секция)</typeparam>
        public static void CopySection<T>(this Card card, Card targetCard, params T[] excludeFields) where T : Enum
        {
            var cardSection = card.Sections.GetOrAdd(typeof(T).Name);
            var targetSection = targetCard.Sections.GetOrAdd(typeof(T).Name);
            foreach (var field in Enum.GetValues(typeof(T)))
            {
                if (IsInArray(excludeFields, field)) continue;
                if (cardSection.Fields.ContainsKey(field.ToString()))
                {
                    targetSection.Fields[field.ToString()] = cardSection.Fields[field.ToString()];
                }
                else
                {
                    targetSection.Fields[field.ToString()] = null;
                }
            }
        }
        
        /// <summary>
        /// Скопировать строковую секцию в карточку TargetCard. ГЛЮЧИТ! выдает ошибку, если у карточки стало больше строк, но обновляет!!! 
        /// </summary>
        /// <param name="card">Текущая карточка</param>
        /// <param name="targetCard">Карточка-назначение (в которую надо скопировать строковую секцию)</param>
        /// <param name="excludeFields">Поля, которые надо исключить при копировании</param>
        /// <typeparam name="T">Enum (по названию которого выбирается копируемая секция)</typeparam>
        public static void CopyTable<T>(this Card card, Card targetCard, params T[] excludeFields) where T : Enum
        {
            var sourceSection = card.Sections.GetOrAddTable(typeof(T).Name);
            var targetSection = targetCard.Sections.GetOrAddTable(typeof(T).Name);
 
            /*
             //Подход глючит
             targetSection.Set(sourceSection);
            foreach (var row in targetSection.Rows)
            {
                row.RowID = Guid.NewGuid();
                row.State = CardRowState.Inserted;
            }*/
            
            
            var sourceCount = sourceSection.Rows.Count;
            var targetCount = targetSection.Rows.Count;
            
            //Обязательно помечать Modified. Просто Clear с последующим добавлением ругается на дублирующиеся значения
            for (var index = 0; index < targetCount; index++)
            {
                if (index < sourceCount)
                {
                    CopyRowValues(sourceSection.Rows[index], targetSection.Rows[index], excludeFields);
                    targetSection.Rows[index].State = CardRowState.Modified;
                }
                else
                {
                    targetSection.Rows[index].State = CardRowState.Deleted;
                }
            }

            //ГЛЮЧИТ здесь. При добавлении новой строки падает
            for (var index = targetCount; index < sourceCount; index++)
            {
                var targetRow = targetSection.Rows.Add();
                CopyRowValues(sourceSection.Rows[index], targetRow, excludeFields);
                targetRow.RowID = Guid.NewGuid();
                targetRow.State = CardRowState.Inserted; 
            }
        }

        /// <summary>
        /// Добавить поля в строковую секцию без уведомлений  об изменении (выполнит RemoveChanges после изменения)
        /// </summary>
        /// <param name="card">Текущая карточка</param>
        /// <param name="rows">Массив строк (пар ключ-значение)</param>
        /// <typeparam name="T">Enum (по названию которого выбирается заполняемая строковая секция)</typeparam>
        public static void AddSectionRowsSilently<T>(this Card card, List<Dictionary<T, Object>> rows) where T : Enum
        {
            var cardSection = card.Sections.GetOrAddTable(typeof(T).Name);
            foreach (var row in rows)
            {
                var newRow = cardSection.Rows.Add();
                foreach (var keyValuePair in row)
                {
                    newRow.Fields[keyValuePair.Key.ToString()] = keyValuePair.Value;
                }
            }
            cardSection.RemoveChanges();
        }

        /// <summary>
        /// Добавить поле в строковую секцию без уведомлений  об изменении (выполнит RemoveChanges после изменения)
        /// </summary>
        /// <param name="card">Текущая карточка</param>
        /// <param name="values">Массив строк (пары ключ-значение)</param>
        /// <typeparam name="T">Enum (по названию которого выбирается заполняемая строковая секция)</typeparam>
        public static void AddSectionRowSilently<T>(this Card card, Dictionary<T, Object> values) where T : Enum
        {
            var cardSection = card.Sections.GetOrAddTable(typeof(T).Name); 
            var newRow = cardSection.Rows.Add();
            foreach (var keyValuePair in values)
            {
                newRow.Fields[keyValuePair.Key.ToString()] = keyValuePair.Value;
            }
            cardSection.RemoveChanges();
        }
        
        /// <summary>
        /// Добавить поле в строковую секцию
        /// </summary>
        /// <param name="card">Текущая карточка</param>
        /// <param name="values">Массив строк (пары ключ-значение)</param>
        /// <typeparam name="T">Enum (по названию которого выбирается заполняемая строковая секция)</typeparam>
        public static void AddSectionRow<T>(this Card card, Dictionary<T, Object> values) where T : Enum
        {
            var cardSection = card.Sections.GetOrAddTable(typeof(T).Name); 
            var newRow = cardSection.Rows.Add();
            foreach (var keyValuePair in values)
            {
                newRow.Fields[keyValuePair.Key.ToString()] = keyValuePair.Value;
            }
            newRow.State=CardRowState.Inserted;
        }

        /// <summary>
        /// Получить значение поля секции.
        /// Если необходимо получить значение поля из карточки или из БД - необходимо использовать GetSectionValueFromCardOrDbOrNull
        /// </summary>
        /// <param name="card">Текущая карточка</param>
        /// <param name="param">Поле, значение которого надо получить</param>
        /// <typeparam name="T">Enum (по названию которого выбирается секция)</typeparam>
        /// <returns>Значения поля или null, если оно не найдено</returns>
        public static object GetSectionValueOrNull<T>(this Card card, T param) where T : Enum
        {
            if (!card.Sections.TryGetValue(typeof(T).Name,out CardSection section)) return null;
            var fields = section.Fields;
            return fields.ContainsKey(param.ToString())?fields[param.ToString()]:null;
        }

        /// <summary>
        /// Получить знание из карточки (если есть) или из БД
        /// </summary>
        /// <param name="card">Карточка</param>
        /// <param name="param">Параметр, значение которого надо получить</param>
        /// <param name="dbScope">Скоуп БД</param>
        /// <typeparam name="T">Тип значения (секция карточки)</typeparam>
        /// <returns>Значение из карточки (если есть) или значение из БД или null</returns>
        public static object GetSectionValueFromCardOrDbOrNull<T>(this Card card, T param, IDbScope dbScope) where T : Enum
        {
            var valueExistOnCard = card.Sections.TryGetValue(typeof(T).Name, out CardSection section)
                                   && section.RawFields.ContainsKey(param.ToString());
            if (valueExistOnCard)
            {
                return section.Fields[param.ToString()];
            }

            using (dbScope.Create())
            {
                var db = dbScope.Db;
                var command = $"SELECT {param.ToString()} FROM {typeof(T).Name} WHERE ID=@ID";
                return db.SetCommand(command, new[] {db.Parameter("ID", card.ID)}).ExecuteScalar();
            }
        }

        /// <summary>
        /// Получить количество файлов, которое будет после сохранения карточки в БД (мерж карточки с БД)
        /// </summary>
        /// <param name="card">Карточка</param>
        /// <param name="dbScope">Скоуп БД</param>
        /// <returns>Количество файлов после сохранения карточки</returns>
        public static int GetFilesCountInDB(this Card card, IDbScope dbScope)
        {
            using (dbScope.Create())
            {
                var db = dbScope.Db;
                return (int) db.SetCommand(GetNumberOfFilesInDB, new[] {db.Parameter("ID", card.ID)}).ExecuteScalar();
            }
        }

        private static void CopyRowValues<T>(CardRow sourceRow, CardRow targetRow, T[] excludeFields)
            where T : Enum
        {
            foreach (var field in Enum.GetValues(typeof(T)))
            {
                if (IsInArray(excludeFields, field)) continue;
                var sourceRowField = sourceRow[field.ToString()];
                targetRow[field.ToString()] = sourceRowField;
            }
        }


        private static bool IsInArray<T>(T[] fields, object field) where T : Enum
        {
            if (fields == null || field == null) return false;
            return fields.Any(excludeField => excludeField.Equals(field));
        }
    }
}