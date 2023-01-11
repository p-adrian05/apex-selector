# Dynamic Apex Repository Layer

Provides a flexible and dynamic extensible Repository layer for SObjects. 

A repository layer is a design pattern in software architecture that provides an abstraction between the data access code and the rest of the application. The repository pattern allows for the encapsulation of data access logic. It help to maintain the clean separation of concerns between the business logic and data access logic making the codebase more robust and maintainable.

<a href="https://login.salesforce.com/packaging/installPackage.apexp?p0=04t7Q000000YxnPQAS">
<img alt="Deploy to Salesforce"
src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
</a>

# Object Repository
Provides a generic service class with basic queries for using itself or 
creating extended specific SObject repository classes using with the SOQLBuilder class.

Having a separate ObjectRepository class for every SObject in Salesforce provides a maintainable and reusable solution for data access logic, improves scalability, performance and testability of the application.

```Apex
ObjectRepository accountRepository = new ObjectRepository(Account.getSObjectType());

Optional accountOptional = accountRepository.findById('0017Q00000KefG7QAJ');

if(accountOptional.isPresent()){
    Account account =  (Account) accountOptional.get();
}

Map<Id,SObject> accountMap = accountRepository.findAllById(new List<Id>{'0017Q00000KefG7QAJ'});
List<Account> accounts = accountMap.values();

```

# SOQL Builder

A dynamic SOQL Builder class in Apex is a class that is used to construct SOQL (Salesforce Object Query Language) queries at runtime, allowing for a greater degree of flexibility in querying data from Salesforce.

There are several reasons why it is important to have a dynamic SOQL Builder class in Apex:

- Dynamic querying: A dynamic SOQL Builder class allows for the construction of queries at runtime, which can be useful in situations where the specific query needed is not known until runtime. This is especially useful for situations where a user needs to search for data based on certain criteria, as the specific search criteria are not known until the user inputs them.

- Improved readability and maintainability: A dynamic SOQL Builder class can make the code more readable and maintainable. Because the query is constructed programmatically, it can be more easily understood and modified, rather than having a large, complex string of query text.

- Flexibility and reusability: Dynamic SOQL Builder class allows for greater flexibility and reusability in the code. By encapsulating the logic for building SOQL queries into a single class, it can be reused throughout the application, which can save development time and help ensure consistency in how data is queried.


## Examples

### Select a record by ID
```Apex
  SOQLQueryBuilder accountQuery = new SOQLQueryBuilder(Account.getSObjectType())
        .selectStandardFields()
        .whereClause(Account.Id)
        .equals(id);

    Account account = (Account) accountQuery.getSingleResult();
    //if the value is null, an SObjectException will be thrown with the given message
    Account account = (Account) accountQuery.getSingleResult('Account not found!');
```
### Select fields
```Apex
    //get standard fields 
    new SOQLQueryBuilder(Account.getSObjectType())
        .selectStandardFields();
    //get custom fields passing a boolean value for include large text fields
    new SOQLQueryBuilder(Account.getSObjectType())
        .selectCustomFields(true);
    //get all fields passing a boolean value for include large text fields
    new SOQLQueryBuilder(Account.getSObjectType())
        .selectAllFields(true);
    //get specific fields 
    new SOQLQueryBuilder(Account.getSObjectType())
        .selectSpecificFields(new List<SObjectField>{Account.Name,Account.AccountSource});
```
### Results

```Apex
    Account account = (Account) accountQuery.getSingleResult();
    //if the value is null, an SObjectException will be thrown with the given message
    Account account = (Account) accountQuery.getSingleResult('Account not found!');

    List<Account> accounts = accountQuery.getResultList();

    Map<Id,SObject> accountMap = soqlQueryBuilder.getResultMap();

    Integer accountCount = soqlQueryBuilder.getIntegerResult();

    AggregateResult[] accountCountAggregate = soqlQueryBuilder.getAggregateResult();

```

### Select records with complex conditions
```Apex
  SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder('Account')
        .selectSpecificFields(new List<SObjectField>{Account.Name,
                Account.AccountSource,Account.NumberOfEmployees})
        .whereOpenBracket(Account.Name)
        .likeValue('%'+ACCOUNT_NAME+'%')
        .andCloseBracket(Account.NumberOfEmployees)
        .greaterThan(20)
        .orCondition(Account.NumberOfEmployees)
        .lessThan(10)
        .orCondition(Account.AccountSource)
        .equals('Web')
        .addLimit(4);

    'SELECT Name,AccountSource,NumberOfEmployees FROM Account WHERE  ' +
    '(Name LIKE \'%Test account name%\'  AND  NumberOfEmployees > 20) OR  NumberOfEmployees < 10  ' +
    'OR  AccountSource = \'Web\'   LIMIT 4';
```
### Select records with group by and having statements
```Apex
   SOQLFunction countFunction = SOQLFunction.of(SOQLFunction.FunctionName.COUNT,Account.Id);
   SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
        .selectSpecificFields(new List<SObjectField>{Account.AccountSource})
        .addFunction(countFunction)
        .whereClause(Account.Name)
        .likeValue('%'+ACCOUNT_NAME+'%')
        .orOpenBracket(Account.Name)
        .notLikeValue('%builder%')
        .orCloseBracket(Account.NumberOfEmployees)
        .greaterOrEquals(12)
        .groupBy(Account.AccountSource)
        .havingOpenBracket(countFunction)
        .greaterThan(1)
        .orCloseBracket(countFunction.toString())
        .lessThan(100)
        .andOpenBracket(countFunction.toString())
        .greaterOrEquals(100)
        .orCloseBracket(countFunction.toString())
        .lessOrEquals(10);

    'SELECT AccountSource,COUNT(Id) FROM Account WHERE ' +
    'Name LIKE \'%Test account name%\' OR ((NOT Name LIKE\'%builder%\') OR  NumberOfEmployees >= 12) ' +
    'GROUP BY AccountSource ' +
    'HAVING  (COUNT(Id) > 1  OR  COUNT(Id) < 100) AND (COUNT(Id) >= 100  OR  COUNT(Id) <= 10)';
```

### Select records with child records
```Apex
   SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
        .selectSpecificFields(new List<SObjectField>{Account.Name})
        .addInnerQuery(new SOQLQueryBuilder(Contact.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Contact.Name}))
        .addInnerQuery(new SOQLQueryBuilder(Case.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Case.SuppliedName}))
        .whereClause(Contact.Name)
        .likeValue('%'+ACCOUNT_NAME+'%');

   'SELECT Name,(SELECT Name FROM Contacts ),' +
            '(SELECT SuppliedName FROM Cases ) ' + 
   'FROM Account WHERE Name LIKE \'%Test account name%\'';
```
### Select records with parent fields
```Apex
    SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Contact.getSObjectType())
              .selectSpecificFields(new List<SObjectField>{Contact.LastName})
                .addParentQuery(new SOQLQueryBuilder(Account.getSObjectType())
                        .selectSpecificFields(new List<SObjectField>{Account.Name}))
                 .addParentQuery(new SOQLQueryBuilder(Contact.getSObjectType())
                         .selectSpecificFields(new List<SObjectField>{Contact.Name})
                         .setParentSObjectTypeName('ReportsTo'))
                .whereClause(Contact.LastName)
                .likeValue('%'+CONTACT_LAST_NAME+'%');

    'SELECT LastName,Account.Name,ReportsTo.Name FROM Contact ' +
    'WHERE LastName LIKE \'%Contact lastName%\'';
```

### Select records with order by statements
```Apex
      SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name,
                        Account.NumberOfEmployees})
                .whereClause(Account.NumberOfEmployees)
                .notInside(discounts)
                .orderBy(Account.Name).ascending().nullsFirst()
                .orderBy(Account.NumberOfEmployees).descending().nullsLast();

      'SELECT Name,NumberOfEmployees FROM Account WHERE ' +
      'NumberOfEmployees NOT IN (10,40,22,23) ' +
      'ORDER BY Name ASC NULLS FIRST, NumberOfEmployees DESC NULLS LAST';
```
### Select records with nested functions

```Apex
   SOQLFunction convertTimeZoneFunction = SOQLFunction.of(SOQLFunction.FunctionName.convertTimezone,
                Opportunity.CreatedDate);
        SOQLFunction hourInDayFunction = SOQLFunction.of(SOQLFunction.FunctionName.HOUR_IN_DAY,
                convertTimeZoneFunction);
        SOQLFunction sumAmountFunction = SOQLFunction.of(SOQLFunction.FunctionName.SUM,
                Opportunity.Amount);

        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Opportunity.getSObjectType())
                .addFunction(hourInDayFunction)
                .addFunction(sumAmountFunction)
                .groupBy(hourInDayFunction);

   'SELECT HOUR_IN_DAY(convertTimezone(CreatedDate)),SUM(Amount) FROM Opportunity ' +
   'GROUP BY HOUR_IN_DAY(convertTimezone(CreatedDate))';
```
### Select records using alias
```Apex
   SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
        .selectSpecificFields(new List<SObjectField>{Lead.LeadSource,Lead.Rating})
        .addFunction(SOQLFunction.of(SOQLFunction.FunctionName.GROUPING,Lead.LeadSource).setAlias('grpLS'))
        .addFunction(SOQLFunction.of(SOQLFunction.FunctionName.GROUPING,Lead.Rating).setAlias('grpRating'))
        .addFunction(SOQLFunction.of(SOQLFunction.FunctionName.COUNT,Lead.Name).setAlias('cnt'))
        .groupBy(SOQLFunction.of(SOQLFunction.FunctionName.ROLLUP,Lead.LeadSource).addFieldName(Lead.Rating));

   'SELECT LeadSource,Rating,GROUPING(LeadSource) grpLS,GROUPING(Rating) grpRating,' +
   'COUNT(Name) cnt FROM Lead GROUP BY ROLLUP(LeadSource,Rating)';

```
