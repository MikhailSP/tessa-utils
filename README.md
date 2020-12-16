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

```c#
var ivanovs=PersonalRolesClass.SelectBuilder(dbScope)
                    .Select(PersonalRoles.ID, PersonalRoles.Name)
                    .WhereEq(PersonalRoles.LastName, "Иванов")
                    .ExecuteList();
```

```c#
var updatedColumnsCount = PersonalRolesClass.UpdateBuilder(dbScope)
                            .Set(PersonalRoles.LastName, "Петров")
                            .Set(PersonalRoles.MiddleName, "Петрович")
                            .WhereEq(PersonalRoles.FirstName, "Петр")
                            .Update();
    
```

Больше вариантов вызова можно посмотреть в комментарии к методам SelectBuilder и UpdateBuilder