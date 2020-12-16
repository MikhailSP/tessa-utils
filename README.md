# tessa-utils
Неофициальный репозиторий утилит для работы с СЭД Тесса https://mytessa.ru/

Содержит:
1. Скрипт подготовки Windows, IIS и прочего для установки Тессы на голую винду + установка Тессы и Chronos.
2. ORM. Генерирует классы по схеме данных, и упрощает запросы к карточкам и БД.


### Скрипт подготовки Windows, IIS и прочего для установки Тессы на голую винду + установка Тессы и Chronos

Информация о скрипте:
- Добавляет расскладку клавиатуры (например русскую);
- Устанавливает нужную тайм-зону;
- Делает все шаги из руководства по установке Тесса с 3.1 по 3.9;
- Ставит SQL Server 2019
- Ставит SQL Server Management Studio последней версии
- Ставит Total Commander, Notepad++

Инструкция по запуску (запускать на чистой винде):
- Подготовить папку с дистрибутивом и скриптами (например на файловой шаре для удобства доступа с разных машин). Содержимое папки:
  - папка с дистрибутивом нужной версии Тесса (например, tessa-3.5.0);
  - файл лицензии (например, mycompany.tlic);
  - ISO образ с дистрибутивом MS SQL Server (при необходимости его автоустановки). Например, en_sql_server_2019_developer_x64_dvd_e5ade34a.iso;
  - папка Script, содержащая данный проект.
- Поправить в Copy-TessaInstaller.ps1 переменные $tessaVersion и $remotePath (путь к папке с дистрибутивом из предыдущего пункта);
- Запустить в PowerShell Copy-TessaInstaller.ps1. Скрипт скопирует дистрибутивы в локальную папку c:\Dev и запустит под админом PowerShell ISE с Install-Tessa.ps1.  
- Исправить настройки в config\prereq\prerequisites.json;
- При необходимости поправить параметры запуска Install-TessaPrerequisites в 
    

## ORM

Для тестовой генерации классов необходимо
1. Экспортировать схему данных с помощью TessaAdmin в папку Configuration\Scheme проекта;
2. Запустить скрипт New-TessaSchemeClasses.ps1. Скрипт сгенерирует нужные классы в Tessa.Extensions.Shared\Generated\Tables.

При реальном использовании необходимо поправить $SchemeFolder и $OutputBaseFolder скрипт New-TessaSchemeClasses.ps1 так, чтобы они смотрели на папки реального проекта.
Также потребуется в папку $OutputBaseFolder скопировать содержимое Tessa.Extensions.Shared.

После генерации классов необходимо использовать SelectBuilder и UpdateBuilder из сгенерированных классов для запросов к БД примерно следующим образом:

#### Получение всех персональных ролей в виде списка объектов типа PesonalRoleClass 
```c#
var allPersonalRoles=PersonalRolesClass.SelectBuilder(dbScope)
                    .ExecuteList();
```

#### Получение списка пользователей с фамилией Иванов. В объектах будут заполнены только поля ID и Name
```c#
var ivanovs=PersonalRolesClass.SelectBuilder(dbScope)
                    .Select(PersonalRoles.ID, PersonalRoles.Name)
                    .WhereEq(PersonalRoles.LastName, "Иванов")
                    .ExecuteList();
```

#### Обновление фамилии и отчества пользователей с именем "Петр"
```c#
var updatedColumnsCount = PersonalRolesClass.UpdateBuilder(dbScope)
                            .Set(PersonalRoles.LastName, "Петров")
                            .Set(PersonalRoles.MiddleName, "Петрович")
                            .WhereEq(PersonalRoles.FirstName, "Петр")
                            .Update();
    
```

### Пример использования методов расширения карточки из CardExtensions.cs

#### Например, можно получить значение имени пользователя из загруженной карточки карточки.  

```c#
var name=card.GetSectionValueOrNull(PersonalRoles.Name);
```

#### Метод ниже позволяет получить значение из карточки или БД. 

Его удобно использовать, например, в StoreExtension, когда в карточке видна только дельта и приходится вручную собирать значения из карточки и БД.

```c#
var name=GetSectionValueFromCardOrDbOrNull(PersonalRoles.Name);
```

#### Получение количества файлов, которые будут доступны после сохранения карточки (мерж карточки  БД)
```c#
var filesCount=card.GetFilesCountInDB(context.DbScope);
```

#### Заполнение поля карточки
```c#
card.FillSection(PersonalRoles.FirstName,"Иван");
```

Также доступен метод "тихого" заполнения FillSectionSilently. Он выполняет RemoveChanges после изменения. И заполнение сразу нескольких полей.

#### Копирование секции одной карточки в другую за исключением набора полей
```c#
sourceCard.CopySection(targetCard,PersonalRoles.ID,PersonalRoles.Login);
```

Также есть метод копирования только нескольких полей или таблицы из секции другой карточки - CopyFieldsFrom / CopyTable


#### IntelliSense подсказывает доступные поля. 
Например, не получится по ошибке запросить PersonalRoles.Account, т.к. такого поля нет, но есть PersonalRoles.Login.

Все доступные поля имеют комментарии, которые берутся из схемы БД. Например, вызвав подсказку по PersonalRoles.Login прямо в коде можно увидеть, что 
- описание: "Логин пользователя или имя доменного аккаунта";
  
- физическая колонка; 

- тип String(256) Null;

- ID, библиотеку и прочие параметры колонки.

Nullable поля классов генерируются в виде T? для исключения ошибок неинициализации всех нужны полей в коде.  [C#8. Типы, допускающие значение NULL](https://docs.microsoft.com/ru-ru/dotnet/csharp/language-reference/builtin-types/nullable-reference-types)

#### Больше вариантов вызова можно посмотреть в комментарии к методам классов SelectBuilder, UpdateBuilder и CardExtensions. 

Документация дополняется.