# tessa-utils
Неофициальный репозиторий утилит для работы с СЭД Тесса https://mytessa.ru/

Содержит:
1. Скрипт установки Тессы на голую винду
2. ORM. Генерирует классы по схеме данных, и упрощает запросы к карточкам и БД.
3. Деплой. Создание архива со всем, что нужно для развертывания кастомизации (конфигурация, код) и его деплой.


### Скрипт установки Тессы на голую винду

Информация о скрипте:
- Добавляет расскладку клавиатуры (например русскую);
- Устанавливает нужную тайм-зону;
- Делает все шаги из руководства по установке Тесса с 3.1 по 3.9;
- Ставит SQL Server 2019
- Ставит SQL Server Management Studio последней версии
- Ставит Total Commander, Notepad++

Инструкция по запуску (запускать на чистой винде):
- Поправить Settings\install-settings\install-settings.json (общие параметры установки) и Settings\environments\\[environment].json (настройки конкретной среды) под свои нужды. Для удобства правки в папке json-schemas есть схемы JSON-файлов; 
- Подготовить папку с дистрибутивом и скриптами (например на файловой шаре для удобства доступа с разных машин). Содержимое папки:
  - папка с дистрибутивом нужной версии Тесса (например, tessa-3.5.0);
  - файл лицензии (например, mycompany.tlic);
  - ISO образ с дистрибутивом MS SQL Server (при необходимости его автоустановки). Например, en_sql_server_2019_developer_x64_dvd_e5ade34a.iso;
  - папка Script, содержащая папки Install и Settings данного проекта.
- Поправить в Copy-TessaInstaller.ps1 переменные $tessaVersion и $remotePath (путь к папке с дистрибутивом из предыдущего пункта);
- Запустить в PowerShell Copy-TessaInstaller.ps1. Скрипт скопирует дистрибутивы в локальную папку c:\Dev и запустит под админом PowerShell ISE с Install-Tessa.ps1.
- При необходимости поправить параметры запуска Install-Tessa;
- Если нужно пропустить некоторые шаги установки - можно отключить их в json файлах. Либо можно закомментировать строки с добавлением шагов в массив $steps (в самом низу файла MikhailSP.Tessa.Utils);
- Запустить скрипт на выполнение. Результаты отработки шагов установки будут отображены в консоли.
    

## ORM

#### Для генерации классов необходимо
1. Экспортировать схему данных с помощью TessaAdmin в папку Configuration\Scheme проекта;
2. Запустить скрипт New-TessaSchemeClasses.ps1. Скрипт сгенерирует нужные классы в Tessa.Extensions.Shared\Generated\Tables.

При реальном использовании на проекте необходимо поправить $SchemeFolder и $OutputBaseFolder скрипт New-TessaSchemeClasses.ps1 так, чтобы они смотрели на папки реального проекта.
Также потребуется в папку $OutputBaseFolder скопировать содержимое Tessa.Extensions.Shared.

### Использование SelectBuilder и UpdateBuilder из сгенерированных классов для запросов к БД

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

### Использование методов расширения карточки из CardExtensions.cs

#### Получение имени пользователя из загруженной карточки.  

```c#
var name=card.GetSectionValueOrNull(PersonalRoles.Name);
```

#### Получение значения из карточки или БД. 

Метод удобно использовать, например, в StoreExtension, когда в карточке видна только дельта и приходится вручную собирать измененные значения из карточки и неизмененные из БД.

```c#
var name=GetSectionValueFromCardOrDbOrNull(PersonalRoles.Name);
```

#### Получение количества файлов, которые будут доступны после сохранения карточки (мерж количества файлов в карточке и БД)
```c#
var filesCount=card.GetFilesCountInDB(context.DbScope);
```

#### Заполнение поля карточки
```c#
card.FillSection(PersonalRoles.FirstName,"Иван");
```

У метода есть перегруженный вариант для одновременного заполнения нескольких полей.

Также доступен метод "тихого" заполнения - FillSectionSilently. Он выполняет RemoveChanges после изменения. 

#### Копирование секции одной карточки в другую за исключением набора полей
```c#
sourceCard.CopySection(targetCard,PersonalRoles.ID,PersonalRoles.Login);
```

Также есть метод копирования только нескольких полей или таблицы из секции другой карточки - CopyFieldsFrom / CopyTable

#### Больше вариантов вызова можно посмотреть в комментарии к методам классов SelectBuilder, UpdateBuilder и CardExtensions.

### IntelliSense подсказывает доступные поля. 
Например, не получится по ошибке запросить PersonalRoles.Account, т.к. такого поля нет в схеме данных, но есть PersonalRoles.Login.

Все доступные поля имеют комментарии, которые берутся из схемы БД. Например, вызвав подсказку по PersonalRoles.Login прямо в коде можно увидеть, что 
- описание поля: "Логин пользователя или имя доменного аккаунта";
  
- физическая колонка; 

- тип String(256) Null;

- ID, библиотеку и прочие параметры поля.

Nullable поля классов генерируются в виде T? для исключения ошибок неинициализации всех нужны полей в коде.  [C#8. Типы, допускающие значение NULL](https://docs.microsoft.com/ru-ru/dotnet/csharp/language-reference/builtin-types/nullable-reference-types)

## Деплой

### Создание пакета деплоя

Пакет деплоя создается с помощью функции New-TessaSolutionPackage из модуля MikhailSP.Tessa.Deploy.psm1. Для удобства запуска (в т.ч. при настройке конвеера деплоя) можно вызывать New-TessaSolutionPackageProxy с нужными параметрами.

- Описание параметров можно посмотреть в комментарии в коде New-TessaSolutionPackage. 

- Файл Settings\deploy-settings\all.json содержит пример настройки пакета деплоя. При реальном использовании можно хранить JSON файлы с корректными путями в репозитории с другим проектом расширений Тессы. Путь к этому файлу можно указать в параметре DeployJsonsPath New-TessaSolutionPackage.  

- Для удобства правки файлов настроек деплоя в IDE можно подключить схему файла, находящуюся в Settings\json-schemasdeploy.schema.json.



### В документации пока описана только часть функционала. Документация дополняется.