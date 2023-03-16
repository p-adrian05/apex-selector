# Dynamic Apex Repository Layer

Provides a flexible and dynamic extensible Repository layer for SObjects.

A repository layer is a design pattern in software architecture that provides an abstraction between the data access code and the rest of the application. The repository pattern allows for the encapsulation of data access logic. It help to maintain the clean separation of concerns between the business logic and data access logic making the codebase more robust and maintainable.

<a href="https://login.salesforce.com/packaging/installPackage.apexp?p0=04t7Q000000YymtQAC">
<img alt="Deploy to Salesforce"
src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
</a>

# Object Repository
Provides a generic repository implementation with basic queries.

```Apex
ObjectRepository accountRepository = new ObjectRepositoryImpl(Account.getSObjectType());

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
The selectStandardFields method is used to retrieve all the standard fields for the Account object. This will include all the fields that come out of the box for an Account object in Salesforce.

The whereClause method is used to add a WHERE clause to the query, with a condition that filters the results to only include records where the "Id" field is equal to the variable 'id'.

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
The whereOpenBracket method is used to open a bracket for a WHERE clause in the query. The likeValue method is then used to add a condition to the WHERE clause that filters for records where the "Name" field contains the value of the variable ACCOUNT_NAME.

The andCloseBracket method is used to close the bracket, and the greaterThan method is used to add another condition to the WHERE clause that filters for records where the "NumberOfEmployees" field is greater than 20.

Then, orCondition is used twice to add conditions that filter the results with lessThan which filters the "NumberOfEmployees" field is less than 10 and equals that filter the "AccountSource" field is equal to 'Web'

Finally, the addLimit method is used to specify that the query should return a maximum of 4 records.
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
First, it creates an instance of the SOQLFunction class, representing COUNT function that can be used in a SOQL query. The countFunction will return the count of the Id field for all returned records.
The groupBy method is used to group the query results by the AccountSource field.
The havingOpenBracket method is used to filter the records based on the aggregate function (COUNT) results and open a bracket.
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
Using addInnerQuery method twice which is used to query child records through a related object creating new SOQLQueryBuilder instances for them. The first time it's used to add a query for the Contact object, and the second time it's used to query the child records of the Account object with the Case object.
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
Using class also uses addParentQuery method twice which is used to query parent records through a relationship creating new SOQLQueryBuilder instances for them. The first time it's used to add a query for the Account object, and the second time it's used to query the parent records of the Contact object with the ReportsTo relationship.
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
The orderBy method is used to sort the records by a certain field. in this example, the query will first sort the records by the "Name" field in ascending order with the nulls first and then by the "NumberOfEmployees" field in descending order with the nulls last.

The methods ascending() and descending() specify the sort direction, while the nullsFirst() and nullsLast() specifies the null values handling.
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
First, it creates three instances of the SOQLFunction class, representing three different functions-
The convertTimeZoneFunction will convert the Opportunity's CreatedDate to the user's time zone.
The hourInDayFunction will return the hour of the day as an integer for the converted time.
The sumAmountFunction will return the sum of the Amount field for all returned records.

Then, the addFunction method is used to add the function to the query twice, the first one is hourInDayFunction and second is sumAmountFunction.
Finally, the groupBy method is used to group the query results by the hour of the day (hourInDayFunction) returned by the query.
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
