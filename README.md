# Dynamic Apex Selector Layer

Provides a flexible and dynamic extensible Selector layer for SObjects and an SOQL Query Builder implementation.

The Selector Pattern a layer of code that encapsulates logic responsible for querying information from standard objects and your custom objects. 
The selector layer feeds that data into your Domain layer and Service layer code. You can also reuse selector classes from other areas that require querying, such as Batch Apex and controllers.

<a href="https://login.salesforce.com/packaging/installPackage.apexp?p0=04t7Q000000Z0c5QAC">
<img alt="Deploy to Salesforce"
src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
</a>

# Object Selector
Provides a generic abstract class for implementing SObject selectors.
- Example:
```Apex
public class AccountsSelector extends ObjectSelectorImpl {
    
    public override SObjectType getSObjectType() {
        return Account.getSObjectType();
    }
    public override List<SObjectField> getSObjectFieldList() {
        return new List<SObjectField>{
                Account.Name,
                Account.Description,
                Account.AnnualRevenue
        };
    }
    //custom query methods
    public List<Account> getAccountsByIds(List<Id> ids) {
        return (List<Account>) selectByIds(ids);
    }
    public List<Account> findByName(String name){
        return new SOQLQueryBuilder(getSObjectType())
                .selectSpecificFields(getSObjectFieldList())
                .whereClause(Account.Name)
                .likeValue('%'+name+'%')
                .getResultList();
    }
}
```
```Apex
ObjectSelector accountsSelector = new AccountsSelector();

Account account = (Account) accountsSelector.selectById('0017Q00000KefG7QAJ');

List<Account> accounts = accountsSelector.selectByIds(new List<Id>{'0017Q00000KefG7QAJ'});
```

# SOQL Builder

A dynamic SOQL Builder class in Apex is a class that is used to construct SOQL (Salesforce Object Query Language) queries at runtime, allowing for a greater degree of flexibility in querying data from Salesforce.

There are several reasons why it is important to have a dynamic SOQL Builder class in Apex:

- Dynamic querying: A dynamic SOQL Builder class allows for the construction of queries at runtime, which can be useful in situations where the specific query needed is not known until runtime. This is especially useful for situations where a user needs to search for data based on certain criteria, as the specific search criteria are not known until the user inputs them.
- Improved readability and maintainability: A dynamic SOQL Builder class can make the code more readable and maintainable. Because the query is constructed programmatically, it can be more easily understood and modified, rather than having a large, complex string of query text.
- Flexibility and reusability: Dynamic SOQL Builder class allows for greater flexibility and reusability in the code. By encapsulating the logic for building SOQL queries into a single class, it can be reused throughout the application, which can save development time and help ensure consistency in how data is queried.
- Security: It can help to ensure that the queries being built are secure by using dynamic variable binding with the new <a href="https://help.salesforce.com/s/articleView?id=release-notes.rn_apex_bind_var_soql.htm&release=242&type=5">Database.queryWithBinds</a> method.

## Examples

### Select a record by ID
- The selectStandardFields method is used to retrieve all the standard fields for the Account object. This will include all the fields that come out of the box for an Account object in Salesforce.

- The whereClause method is used to add a WHERE clause to the query, with a condition that filters the results to only include records where the "Id" field is equal to the variable 'id'.

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
- There are several methods that can be used to retrieve the results of the query.
- It is possible to set the access level for every type of result query, the default level is SYSTEM_MODE.
```Apex
    Account account = (Account) accountQuery.getSingleResult();
    //if the value is null, an SObjectException will be thrown with the given message
    Account account = (Account) accountQuery.getSingleResult('Account not found!');

    List<Account> accounts = accountQuery.getResultList();
    // specify the access level to USER_MODE
    List<Account> accounts = accountQuery.getResultList(AccessLevel.USER_MODE);

    Map<Id,SObject> accountMap = soqlQueryBuilder.getResultMap();

    Integer accountCount = soqlQueryBuilder.getIntegerResult();

    AggregateResult[] accountCountAggregate = soqlQueryBuilder.getAggregateResult();
    
    //get the query string and the bind variables that is used to execute the query
    SOQLQueryBuilder.QueryStringResult queryStringResult = accountQuery.getQueryStringResult();
    //SELECT Name,NumberOfEmployees FROM Account WHERE Name LIKE :value0 AND NumberOfEmployees > :value1 
    String actualQueryString = queryStringResult.queryString;
    //Map<String,Object>{'value0' => '%test%','value1' => 20};
    Map<String,Object> actualBindVariables = queryStringResult.bindVariables;
```

### Select records with complex conditions
- The whereOpenBracket method is used to open a bracket for a WHERE clause in the query. The likeValue method is then used to add a condition to the WHERE clause that filters for records where the "Name" field contains the given value.
- The andCloseBracket method is used to close the bracket, and the greaterThan method is used to add another condition to the WHERE clause that filters for records where the "NumberOfEmployees" field is greater than 20.
- Then, orCondition is used twice to add conditions that filter the results with lessThan which filters the "NumberOfEmployees" field is less than 10 and equals that filter the "AccountSource" field is equal to 'Web'
- Finally, the addLimit method is used to specify that the query should return a maximum of 4 records.
```Apex
  SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder('Account')
        .selectSpecificFields(new List<SObjectField>{Account.Name,
                Account.AccountSource,Account.NumberOfEmployees})
        .whereOpenBracket(Account.Name)
        .likeValue('%Test account name%')
        .andCloseBracket(Account.NumberOfEmployees)
        .greaterThan(20)
        .orCondition(Account.NumberOfEmployees)
        .lessThan(10)
        .orCondition(Account.AccountSource)
        .equals('Web')
        .addLimit(4);

    'SELECT Name,AccountSource,NumberOfEmployees FROM Account WHERE  ' +
    '(Name LIKE \'%Test account name%\'  AND  NumberOfEmployees > 20) OR  NumberOfEmployees < 10  ' +
    'OR  AccountSource = \'Web\' LIMIT 4';
```
### Select records with group by and having statements
- First, it creates an instance of the SOQLFunction class, representing COUNT function that can be used in a SOQL query. The countFunction will return the count of the Id field for all returned records.
- The groupBy method is used to group the query results by the AccountSource field.
- The havingOpenBracket method is used to filter the records based on the aggregate function (COUNT) results and open a bracket.
```Apex
   SOQLFunction countFunction = SOQLFunction.of(SOQLFunction.FunctionName.COUNT,Account.Id);
   SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
        .selectSpecificFields(new List<SObjectField>{Account.AccountSource})
        .addFunction(countFunction)
        .whereClause(Account.Name)
        .likeValue('%Test account name%')
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
- The addInnerQuery method is used to query child records using the child relationship name and creating new SOQLQueryBuilder instances for them. 
- If no relationships are specified, the SOQLQueryBuilder class automatically will use the only one relationship name,
otherwise if there are multiple relationships the setChildRelationshipName method is used to specify the child relationship name.
- If multiple relationships are specified, the SOQLQueryBuilder class will throw an exception and have to be specified the child relationship name with the setChildRelationshipName method.
- If only one relationship is specified, the SOQLQueryBuilder class will use it automatically.
```Apex
   SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
        .selectSpecificFields(new List<SObjectField>{Account.Name})
        .addInnerQuery(new SOQLQueryBuilder(Contact.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Contact.Name})
                .setChildRelationshipName('Contacts'))
        .addInnerQuery(new SOQLQueryBuilder(Case.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Case.SuppliedName}))
        .whereClause(Contact.Name)
        .likeValue('%Test account name%');

   'SELECT Name,(SELECT Name FROM Contacts ),' +
            '(SELECT SuppliedName FROM Cases ) ' + 
   'FROM Account WHERE Name LIKE \'%Test account name%\'';
```
### Select records with parent fields
- The addParentQuery is used to query parent records through a relationship creating new SOQLQueryBuilder instances for them.
- If the parent relationship is not specified, the query will use the SObjectType name as the relationship name otherwise, the setParentRelationshipName method is used to specify the relationship name.
```Apex
    SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Contact.getSObjectType())
        .selectSpecificFields(new List<SObjectField>{Contact.LastName})
        .addParentQuery(new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name}))
        .addParentQuery(new SOQLQueryBuilder(Contact.getSObjectType())
                            .setParentRelationshipName('ReportsTo')
                            .addParentQuery(new SOQLQueryBuilder(Account.getSObjectType())
                                            .selectSpecificFields(new List<SObjectField>{Account.Name})))
        .whereClause(Contact.LastName)
        .likeValue('%Contact lastName%')
        .andCondition('Account.Name')
        .likeValue('%Test account name%');

          'SELECT LastName,Account.Name,ReportsTo.Account.Name FROM Contact' +
          ' WHERE  LastName LIKE \'%Contact lastName%\' AND Account.Name LIKE \'%Test account name%\'';

```

### Select records with order by statements
- The orderBy method is used to sort the records by a certain field. in this example, the query will first sort the records by the "Name" field in ascending order with the nulls first and then by the "NumberOfEmployees" field in descending order with the nulls last.
- The methods ascending() and descending() specify the sort direction, while the nullsFirst() and nullsLast() specifies the null values handling.
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
- First, it creates three instances of the SOQLFunction class, representing three different functions-
- The convertTimeZoneFunction will convert the Opportunity's CreatedDate to the user's time zone.
- The hourInDayFunction will return the hour of the day as an integer for the converted time.
- The sumAmountFunction will return the sum of the Amount field for all returned records.

- Then, the addFunction method is used to add the function to the query twice, the first one is hourInDayFunction and second is sumAmountFunction.
- Finally, the groupBy method is used to group the query results by the hour of the day (hourInDayFunction) returned by the query.
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
