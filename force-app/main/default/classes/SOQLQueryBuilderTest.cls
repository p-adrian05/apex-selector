@IsTest
public with sharing class SOQLQueryBuilderTest {

    private final static String ACCOUNT_NAME= 'Test account name';
    private final static String CONTACT_LAST_NAME= 'Contact lastName';
    private final static String CONTACT_FIRST_NAME= 'Contact firstName';

    @TestSetup
    public static void testSetup(){
        List<Account> accounts = new List<Account>();
        List<Contact> contacts = new List<Contact>();
        for(Integer i = 1; i<=10; i++){
            Account account = new Account();
            account.Name = ACCOUNT_NAME +' '+i;
            account.AccountSource = 'Web';
            account.NumberOfEmployees = 10*i;
            accounts.add(account);
        }
        insert accounts;
        for(Integer i = 0; i<accounts.size(); i++){
            Contact contact = new Contact();
            contact.LastName = CONTACT_LAST_NAME+i;
            contact.FirstName = CONTACT_FIRST_NAME+i;
            contact.Email = 'testemail@gmail.com';
            contact.AccountId = accounts.get(i).Id;
            contacts.add(contact);
        }
        insert contacts;

    }
    private static void assertQueryStringResult(SOQLQueryBuilder soqlQueryBuilder,Map<String,Object> expectedValues, String expectedQueryString){
        SOQLQueryBuilder.QueryStringResult queryStringResult = soqlQueryBuilder.getQueryStringResult();
        String actualQueryString = queryStringResult.queryString;
        Map<String,Object> actualValues = queryStringResult.objectBinds;

        System.debug(actualValues);
        System.debug(actualQueryString);
        //assert actual actualValues to expectedValues
        Assert.areEqual(expectedValues.size(),actualValues.size(),'Expected values size is '+expectedValues.size()+' but actual values size is '+actualValues.size());
        for(String key: expectedValues.keySet()){
            Assert.isTrue(actualValues.containsKey(key),'Actual values does not contain key '+key );
            Assert.areEqual(expectedValues.get(key),actualValues.get(key),'Expected value for key '+key+' is '+expectedValues.get(key)+' but actual value is '+actualValues.get(key));
        }
        //assert actual query string to expected query string
        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }

    @IsTest
    public static void testQueryAccountsByNameShouldReturnAccounts(){
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectStandardFields()
                .whereClause(Account.Name)
                .likeValue('%'+ACCOUNT_NAME+'%');

        Map<Id,SObject> accountMap = soqlQueryBuilder.getResultMap(AccessLevel.SYSTEM_MODE);
        List<Account> accounts = accountMap.values();

        Assert.areEqual(10,accounts.size());
        for(Account account: accounts){
            Assert.isTrue(account.Name.contains(ACCOUNT_NAME));
        }
    }
    @IsTest
    public static void testQuerySingeResultWithExceptionThrownWhenResultIsNull(){
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectAllFields(false)
                .whereClause(Account.Id)
                .equals('000000000000000002');

        String exceptionMessage;
        String errorMessageToThrow = 'Account Not found';

        try{
            Account account = (Account) soqlQueryBuilder.getSingleResult(errorMessageToThrow);
        }catch (SObjectException e){
            exceptionMessage  = e.getMessage();
        }
        Assert.isTrue(exceptionMessage.contains(errorMessageToThrow));

    }
    @IsTest
    public static void testQueryAccountsWithInvalidSobjectTypeNameShouldThrowException(){
        String exceptionMessage;
        try{
            List<Account> accounts = new SOQLQueryBuilder('AccounttInvalidType')
                    .selectStandardFields()
                    .whereClause(Account.Name)
                    .likeValue('%'+ACCOUNT_NAME+'%').getResultList(AccessLevel.SYSTEM_MODE);
        }catch (Exception e){
           exceptionMessage  = e.getMessage();
        }
        Assert.isNotNull(exceptionMessage);
    }
    @IsTest
    public static void testQueryAccountsByIdShouldReturnAccounts(){
        List<Account> accounts = [SELECT Id,Name  FROM Account WHERE Name LIKE '%Test account name%'];
        List<Id> accountIds = new List<Id>();
        for(Account account:accounts){
            accountIds.add(account.Id);
        }

        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectAllFields(true)
                .whereClause('Id')
                .inside(accountIds);
        List<Account> accountsById = soqlQueryBuilder.getResultList();

        Assert.areEqual(accountIds.size(),accountsById.size());
        for(Account account:  accountsById){
            Assert.isTrue(accountIds.contains(account.Id));
        }
    }
    @IsTest
    public static void testQueryAccountByIdShouldReturnAccount(){
        List<Account> accounts = [SELECT Id,Name  FROM Account WHERE Name LIKE '%Test account name%' LIMIT 1];
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectAllFields(true)
                .whereClause('Id')
                .equals(accounts.get(0).Id);
        Account actualAccount = (Account) soqlQueryBuilder.getSingleResult();

       Assert.areEqual(accounts.get(0).Id,actualAccount.Id);
    }
    @IsTest
    public static void testQueryAccountsWithCustomFieldsShouldContainsIdField(){
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectCustomFields(true)
                .whereClause(Account.Name)
                .likeValue('%'+ACCOUNT_NAME+'%');

        Account account = (Account) soqlQueryBuilder.getSingleResult();

        String queryString = soqlQueryBuilder.toString();

        String exceptionMessage;
        try{
            String name =  account.Name;
        }catch (SObjectException e){
            exceptionMessage  = e.getMessage();
        }
        Assert.isNotNull(exceptionMessage);
        Assert.isTrue(queryString.contains('Id'));
    }
    @IsTest
    public static void testQueryAccountsByNameAndAccountLevelDiscountShouldReturnAccounts(){
        Map<String,Object> expectedValues = new Map<String,Object>{'value0' => '%'+ACCOUNT_NAME+'%','value1' => 20,'value2' => 10,'value3' => 'Web'};

        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder('Account')
                .selectSpecificFields(new List<SObjectField>{Account.Name,Account.AccountSource,Account.NumberOfEmployees})
                .whereOpenBracket(Account.Name)
                .likeValue((String) expectedValues.get('value0'))
                .andCloseBracket(Account.NumberOfEmployees)
                .greaterThan((Integer) expectedValues.get('value1'))
                .orCondition(Account.NumberOfEmployees)
                .lessThan((Integer) expectedValues.get('value2'))
                .orCondition(Account.AccountSource)
                .equals((String) expectedValues.get('value3'))
                .addLimit(4);

        String expectedQueryString = 'SELECT Name,AccountSource,NumberOfEmployees FROM Account WHERE ' +
                ' (Name LIKE :value0 AND NumberOfEmployees > :value1) ' +
                'OR NumberOfEmployees < :value2 OR AccountSource = :value3  LIMIT 4';

        List<Account> accounts = soqlQueryBuilder.getResultList();


        assertQueryStringResult(soqlQueryBuilder,expectedValues,expectedQueryString);
        Assert.areEqual(4,accounts.size());
        for(Account account:  accounts){
            Assert.isTrue(account.Name.contains(ACCOUNT_NAME));
            Assert.areEqual('Web',account.AccountSource);
        }
    }


    @IsTest
    public static void testQueryAccountsByAccountLevelDiscountShouldReturnAccounts(){
       List<Integer> numberOfEmployees = new List<Integer>{10,40,22,23};
       Map<String,Object> expectedValues = new Map<String,Object>{'value0' => numberOfEmployees ,'value1' => Date.newInstance(2022,02,1)};

       SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name,Account.NumberOfEmployees})
                .whereClause(Account.NumberOfEmployees)
                .inside((List<Integer>) expectedValues.get('value0'))
                .andCondition(Account.CreatedDate)
                .greaterThan((Date) expectedValues.get('value1'))
                .addLimit(100)
                .addOffset(10);

       String expectedQueryString =  'SELECT Name,NumberOfEmployees FROM Account WHERE ' +
               'NumberOfEmployees IN :value0 AND CreatedDate > :value1 LIMIT 100 OFFSET 10';

       List<Account> accounts = soqlQueryBuilder.getResultList();
       assertQueryStringResult(soqlQueryBuilder,expectedValues,expectedQueryString);

       for(Account account: accounts){
            Assert.isTrue(numberOfEmployees.contains(account.NumberOfEmployees));
       }
    }
    @IsTest
    public static void testCountAccountsByIdShouldReturnInteger(){
       SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .addFunction(SOQLFunction.of(SOQLFunction.FunctionName.COUNT));

        Integer accountCount = soqlQueryBuilder.getIntegerResult();
        String expectedQueryString = 'SELECT COUNT() FROM Account';

        Assert.areEqual(10,accountCount);
        assertQueryStringResult(soqlQueryBuilder,new Map<String,Object>(),expectedQueryString);
    }
    @IsTest
    public static void testCountAccountsByAccountSourceFieldShouldReturnAggregateResult(){
       Map<String,Object> expectedValues = new Map<String,Object>{'value0' => '%'+ACCOUNT_NAME+'%', 'value1' => '%builder%',
                                     'value2' => 12, 'value3' => 1, 'value4' => 100, 'value5' => 100,'value6' => 10};

        SOQLFunction countFunction = SOQLFunction.of(SOQLFunction.FunctionName.COUNT,Account.Id);
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.AccountSource})
                .addFunction(countFunction)
                .whereClause(Account.Name)
                .likeValue( (String) expectedValues.get('value0'))
                .orOpenBracket(Account.Name)
                .notLikeValue( (String) expectedValues.get('value1'))
                .orCloseBracket(Account.NumberOfEmployees)
                .greaterOrEquals(  (Integer) expectedValues.get('value2'))
                .groupBy(Account.AccountSource)
                .havingOpenBracket(countFunction)
                .greaterThan( (Integer) expectedValues.get('value3'))
                .orCloseBracket(countFunction.toString())
                .lessThan( (Integer) expectedValues.get('value4'))
                .andOpenBracket(countFunction.toString())
                .greaterOrEquals( (Integer) expectedValues.get('value5'))
                .orCloseBracket(countFunction.toString())
                .lessOrEquals( (Integer) expectedValues.get('value6'));

        String expectedQueryString = 'SELECT AccountSource,COUNT(Id) FROM Account WHERE ' +
                ' Name LIKE :value0 OR ((NOT Name LIKE :value1) OR NumberOfEmployees >= :value2)  ' +
                ' GROUP BY AccountSource ' +
                ' HAVING  (COUNT(Id) > :value3 OR COUNT(Id) < :value4)' +
                ' AND (COUNT(Id) >= :value5 OR COUNT(Id) <= :value6)';

        assertQueryStringResult(soqlQueryBuilder,expectedValues,expectedQueryString);
        AggregateResult[] accountCountAggregate = soqlQueryBuilder.getAggregateResult();
        Assert.isTrue((Integer) accountCountAggregate.get(0).get('expr0')>1);
    }
    @IsTest
    public static void testLeadsGroupByName(){
        Map<String,Object> expectedValues = new Map<String,Object>{'value0'=>new List<Date>{Date.newInstance(2022,02,01)},'value1'=>'%San%'};
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.City,Lead.CreatedDate})
                .whereClause(Lead.CreatedDate)
                .inside((List<Date>) expectedValues.get('value0'))
                .groupBy(Lead.City)
                .havingClause(Lead.City)
                .likeValue((String) expectedValues.get('value1'));

        String expectedQueryString = 'SELECT City,CreatedDate FROM Lead ' +
                'WHERE CreatedDate IN :value0 GROUP BY City HAVING City LIKE :value1';

        assertQueryStringResult(soqlQueryBuilder,expectedValues,expectedQueryString);
    }
    @IsTest
    public static void testCountLeadsNameGroupByLeadSource(){
        Map<String,Object> expectedValues = new Map<String,Object>{'value0' => 23};
        SOQLFunction countFunction = SOQLFunction.of(SOQLFunction.FunctionName.COUNT,Lead.Name);
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .addFunction(countFunction)
                .groupBy(Lead.LeadSource)
                .havingClause(countFunction)
                .greaterThan(23);

        String expectedQueryString =  'SELECT LeadSource,COUNT(Name) FROM Lead GROUP BY LeadSource ' +
                'HAVING COUNT(Name) > :value0';

        assertQueryStringResult(soqlQueryBuilder,expectedValues,expectedQueryString);
    }
    @IsTest
    public static void testCountLeadsByNameGroupByCity(){
        Map<String,Object> expectedValues = new Map<String,Object>{'value0' => '%San%' , 'value1' => 1};

        SOQLFunction countFunction = SOQLFunction.of(SOQLFunction.FunctionName.COUNT,Lead.Name);
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.City})
                .addFunction(countFunction)
                .groupBy(Lead.City)
                .havingOpenBracket(Lead.City)
                .likeValue( (String) expectedValues.get('value0'))
                .andCloseBracket(countFunction.toString())
                .greaterThan( (Integer) expectedValues.get('value1'));

        String expectedQueryString = 'SELECT City,COUNT(Name) FROM Lead GROUP BY City ' +
                                        'HAVING (City LIKE :value0 AND COUNT(Name) > :value1)';

        assertQueryStringResult(soqlQueryBuilder,expectedValues,expectedQueryString);
    }
    @IsTest
    public static void testAverageAccountsAccountLevelDiscountFieldShouldReturnAggregateResult(){
         SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .addFunction(SOQLFunction.of(SOQLFunction.FunctionName.AVG,Account.NumberOfEmployees));

        String expectedQueryString = 'SELECT AVG(NumberOfEmployees) FROM Account';

        AggregateResult[] accountAverageAggregate = soqlQueryBuilder.getAggregateResult();


        Assert.areEqual(55,accountAverageAggregate.get(0).get('expr0')) ;
        assertQueryStringResult(soqlQueryBuilder,new Map<String,Object>(),expectedQueryString);

    }
    @IsTest
    public static void testInnerContactQueryWithAccountShouldReturnAccountWithContacts(){
        Map<String,Object> expectedValues = new Map<String,Object>{'value0'=>'%'+CONTACT_LAST_NAME+'%','value1'=>'%'+CONTACT_FIRST_NAME+'%','value2'=>'%'+ACCOUNT_NAME+'%'};
       SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
               .selectSpecificFields(new List<SObjectField>{Account.Name})
                .addInnerQuery(new SOQLQueryBuilder(Contact.getSObjectType())
                        .selectSpecificFields(new List<SObjectField>{Contact.LastName,Contact.FirstName})
                        .whereClause(Contact.LastName)
                        .likeValue( (String) expectedValues.get('value0'))
                        .andCondition(Contact.FirstName)
                        .likeValue( (String) expectedValues.get('value1')))
                .whereClause(Account.Name)
                .likeValue( (String) expectedValues.get('value2'));

        String expectedQueryString =  'SELECT Name,' +
                '(SELECT LastName,FirstName FROM Contacts WHERE LastName LIKE :value0 AND FirstName LIKE :value1  ) ' +
                'FROM Account WHERE  Name LIKE :value2';

        List<Account> accounts = soqlQueryBuilder.getResultList();

        for(Account account: accounts){
           Assert.isFalse(account.Contacts.isEmpty());
        }
       assertQueryStringResult(soqlQueryBuilder,expectedValues,expectedQueryString);
    }
    @IsTest
    public static void testInnerContactAndContractQueryWithAccountShouldReturnAccountWithContactsAndContracts(){
      Map<String,Object> expectedValues = new Map<String,Object>{'value0'=>'%'+ACCOUNT_NAME+'%'};
      SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
              .selectSpecificFields(new List<SObjectField>{Account.Name})
                .addInnerQuery(new SOQLQueryBuilder(Contact.getSObjectType())
                        .selectSpecificFields(new List<SObjectField>{Contact.Name})
                        .setChildRelationshipName('Contacts'))
                .addInnerQuery(new SOQLQueryBuilder(Contract.getSObjectType())
                        .selectSpecificFields(new List<SObjectField>{Contract.Name}))
                .whereClause(Account.Name)
                .likeValue( (String) expectedValues.get('value0'));

        String expectedQueryString = 'SELECT Name,(SELECT Name FROM Contacts),(SELECT Name FROM Contracts ) ' +
                'FROM Account WHERE Name LIKE :value0';

        List<Account> accounts = soqlQueryBuilder.getResultList();

        for(Account account: accounts){
            Assert.isFalse(account.Contacts.isEmpty());
        }
        assertQueryStringResult(soqlQueryBuilder,expectedValues,expectedQueryString);
    }
    @IsTest
    public static void testParentAccountQueryWithContactShouldReturnContact(){
      Map<String,Object> expectedValues = new Map<String,Object>{'value0'=>'%'+CONTACT_LAST_NAME+'%','value1'=>'%'+ACCOUNT_NAME+'%'};
      SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Contact.getSObjectType())
              .selectSpecificFields(new List<SObjectField>{Contact.LastName})
                .addParentQuery(new SOQLQueryBuilder(Account.getSObjectType())
                        .selectSpecificFields(new List<SObjectField>{Account.Name}))
                 .addParentQuery(new SOQLQueryBuilder(Contact.getSObjectType())
                                    .setParentRelationshipName('ReportsTo')
                                        .addParentQuery(new SOQLQueryBuilder(Account.getSObjectType())
                                        .selectSpecificFields(new List<SObjectField>{Account.Name})))
                .whereClause(Contact.LastName)
                .likeValue((String) expectedValues.get('value0'))
              .andCondition('Account.Name').likeValue((String) expectedValues.get('value1'));

        String expectedQueryString = 'SELECT LastName,Account.Name,ReportsTo.Account.Name FROM Contact' +
                                ' WHERE  LastName LIKE :value0 AND Account.Name LIKE :value1';

        Contact contact = (Contact) soqlQueryBuilder.getSingleResult();

        Assert.areEqual(ACCOUNT_NAME+' 1',contact.Account.Name);
        assertQueryStringResult(soqlQueryBuilder,expectedValues,expectedQueryString);
    }
    @IsTest
    public static void testAccountOrderByShouldReturnAccounts(){
        Map<String,Object> expectedValues = new Map<String,Object>{'value0'=>new List<Integer>{10,40,22,23}};
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name,Account.NumberOfEmployees})
                .whereClause(Account.NumberOfEmployees)
                .notInside( (List<Decimal>) expectedValues.get('value0'))
                .orderBy(Account.Name).ascending().nullsFirst()
                .orderBy(Account.NumberOfEmployees).descending().nullsLast();

        String expectedQueryString = 'SELECT Name,NumberOfEmployees FROM Account WHERE ' +
                'NumberOfEmployees NOT IN :value0' +
                'ORDER BY Name ASC NULLS FIRST, NumberOfEmployees DESC NULLS LAST';

        List<Account> accounts = soqlQueryBuilder.getResultList();

        Assert.areEqual(8,accounts.size());
        assertQueryStringResult(soqlQueryBuilder,expectedValues,expectedQueryString);

    }
    @IsTest
    public static void testAccountGroupByShouldReturnAccounts(){
       SOQLQueryBuilder soqlQueryBuilder =  new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name})
                .groupBy(Account.Name);

       String expectedQueryString = 'SELECT Name FROM Account GROUP BY Name';

       AggregateResult[] aggregateResult = soqlQueryBuilder.getAggregateResult();

       Assert.areEqual(10,aggregateResult.size());
       assertQueryStringResult(soqlQueryBuilder,new Map<String,Object>{},expectedQueryString);

    }
    @IsTest
    public static void testQueryAccountsShouldReturnAccountsForUpdate(){
        SOQLQueryBuilder soqlQueryBuilder =  new SOQLQueryBuilder(Account.getSObjectType()).forUpdate();

        String expectedQueryString = 'SELECT Id FROM Account FOR UPDATE';

       assertQueryStringResult(soqlQueryBuilder,new Map<String,Object>{},expectedQueryString);
    }
    @IsTest
    public static void testQueryAccountsShouldReturnAccountsForView(){
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType()).forView();
        String expectedQueryString = 'SELECT Id FROM Account FOR VIEW';

        assertQueryStringResult(soqlQueryBuilder,new Map<String,Object>{},expectedQueryString);
    }
    @IsTest
    public static void testQueryAccountsShouldReturnAccountsForReference(){
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType()).forReference();
        String expectedQueryString = 'SELECT Id FROM Account FOR REFERENCE';

        assertQueryStringResult(soqlQueryBuilder,new Map<String,Object>{},expectedQueryString);
    }
    @IsTest
    public static void testQueryAccountsShouldReturnAccountsUpdateTracking(){
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType()).updateTracking();
        String expectedQueryString = 'SELECT Id FROM Account UPDATE TRACKING';

        assertQueryStringResult(soqlQueryBuilder,new Map<String,Object>{},expectedQueryString);
    }
    @IsTest
    public static void testQueryAccountsShouldReturnAccountsUpdateViewStat(){
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType()).updateViewStat();

        String expectedQueryString = 'SELECT Id FROM Account UPDATE VIEWSTAT';

        assertQueryStringResult(soqlQueryBuilder,new Map<String,Object>{},expectedQueryString);
    }
    @IsTest
    public static void testQueryAccountsByNameShouldReturnAccountsAllRows(){
        Map<String,Object> expectedValues = new Map<String,Object>{'value0'=>'%'+ACCOUNT_NAME+'%', 'value1'=>'fail', 'value2'=>''};
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .whereClause(Account.Name)
                .likeValue( (String) expectedValues.get('value0'))
                .andOpenBracket(Account.Name)
                .notEquals( (String) expectedValues.get('value1'))
                .andCloseBracket(Account.Name)
                .notEquals( (String) expectedValues.get('value2'))
                .allRows()
                .withSecurityEnforced();

        String expectedQueryString = 'SELECT Id FROM Account WHERE Name LIKE :value0 ' +
                'AND (Name != :value1 AND Name != :value2)  WITH SECURITY_ENFORCED ALL ROWS';

        assertQueryStringResult(soqlQueryBuilder,expectedValues,expectedQueryString);
    }
    @IsTest
    public static void testQueryAccountsShouldReturnAccountsUsingWithStatement(){
        SOQLQueryBuilder soqlQueryBuilder =  new SOQLQueryBuilder(Account.getSObjectType())
                .with('DATA CATEGORY Geography__c').withSecurityEnforced();
        String expectedQueryString = 'SELECT Id FROM Account WITH DATA CATEGORY Geography__c SECURITY_ENFORCED';

        assertQueryStringResult(soqlQueryBuilder,new Map<String,Object>{},expectedQueryString);
    }
    @IsTest
    public static void testQueryAccountsByNameShouldReturnAccountsUsingScope(){
        Map<String,Object> expectedValues = new Map<String,Object>{'value0'=>'%'+ACCOUNT_NAME+'%'};
         SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .whereClause(Account.Name)
                .likeValue((String) expectedValues.get('value0'))
                .usingScope(FilterScope.mine);

        String expectedQueryString = 'SELECT Id FROM Account WHERE Name LIKE :value0 USING SCOPE mine';

        assertQueryStringResult(soqlQueryBuilder,expectedValues,expectedQueryString);
    }
    @IsTest
    public static void testQueryLeadWithGroupByRollup(){
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource,Lead.Rating})
                .addFunction(SOQLFunction.of(SOQLFunction.FunctionName.GROUPING,Lead.LeadSource).setAlias('grpLS'))
                .addFunction(SOQLFunction.of(SOQLFunction.FunctionName.GROUPING,Lead.Rating).setAlias('grpRating'))
                .addFunction(SOQLFunction.of(SOQLFunction.FunctionName.COUNT,Lead.Name).setAlias('cnt'))
                .groupBy(SOQLFunction.of(SOQLFunction.FunctionName.ROLLUP,Lead.LeadSource).addFieldName(Lead.Rating));

        String expectedQueryString = 'SELECT LeadSource,Rating,GROUPING(LeadSource) grpLS,GROUPING(Rating) grpRating,' +
                'COUNT(Name) cnt FROM Lead GROUP BY ROLLUP(LeadSource,Rating)';

        assertQueryStringResult(soqlQueryBuilder,new Map<String,Object>{},expectedQueryString);
    }
    @IsTest
    public static void testInnerFunctionWithGroupBy(){
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

        String expectedQueryString = 'SELECT HOUR_IN_DAY(convertTimezone(CreatedDate)),SUM(Amount) FROM Opportunity ' +
                'GROUP BY HOUR_IN_DAY(convertTimezone(CreatedDate))';

        assertQueryStringResult(soqlQueryBuilder,new Map<String,Object>{},expectedQueryString);
    }
    @IsTest
    public static void testMultiSelectPicklistOperators(){
        Map<String,Object> expectedValues = new Map<String,Object>{'value0'=>new List<String>{'Web','Phone Inquiry'},
                                                                            'value1'=>new List<String>{'Other'}};
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.AccountSource})
                .whereClause(Account.AccountSource)
                .includes((List<String>) expectedValues.get('value0'))
                .orCondition(Account.AccountSource)
                .excludes((List<String>) expectedValues.get('value1'));

        String expectedQueryString = 'SELECT AccountSource FROM Account WHERE ' +
                'AccountSource INCLUDES :value0 OR AccountSource EXCLUDES :value1';

        assertQueryStringResult(soqlQueryBuilder,expectedValues,expectedQueryString);
    }
    @IsTest
    public static void testSOQLFunction(){
        String sumAmountFunctionAlias = 'sumAmount';
        SOQLFunction sumAmountFunction = SOQLFunction.of(SOQLFunction.FunctionName.SUM,Opportunity.Amount)
                .setAlias(sumAmountFunctionAlias);

        Assert.areEqual(SOQLFunction.FunctionName.SUM,sumAmountFunction.getName());
        Assert.areEqual(sumAmountFunctionAlias,  sumAmountFunction.getAlias());
        Assert.areEqual(Opportunity.Amount.getDescribe().getName(),  sumAmountFunction.getFieldNames().get(0));
        Assert.isNull(sumAmountFunction.getInnerFunction());

        sumAmountFunction.setFieldNames(new List<String>{Opportunity.Name.getDescribe().getName()});
        Assert.areEqual(Opportunity.Name.getDescribe().getName(),  sumAmountFunction.getFieldNames().get(0));
    }

    @IsTest
    public static void testConvertParentLookupFieldNameToSOQLField(){
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType());

        String standardObjectNameResult = soqlQueryBuilder.convertParentRelationshipNameToSOQLFormat('Account');
        System.assertEquals('Account', standardObjectNameResult);

        String customObjectNameResult = soqlQueryBuilder.convertParentRelationshipNameToSOQLFormat('Custom__c');
        System.assertEquals('Custom__r', customObjectNameResult);
    }
    @IsTest
    public static void testGetAllFieldsForSObject() {
        List<SObjectField> fields = SOQLQueryBuilder.getFieldsForSObject(Account.SObjectType, true, true, true);

        Assert.isTrue(fields.size() > 0);
        for (SObjectField field : fields) {
            Assert.isNotNull(field.getDescribe().getName());
            Assert.isNotNull(field.getDescribe().getLabel());
            Assert.isNotNull(field.getDescribe().getType());
        }
    }
    @IsTest
    public static void testGetCustomFieldsForSObject() {
        List<SObjectField> fields = SOQLQueryBuilder.getFieldsForSObject(Account.SObjectType, true, false, true);

        for (SObjectField field : fields) {
            Assert.isTrue(field.getDescribe().isCustom());
        }
    }
    @IsTest
    public static void testGetStandardFieldsForSObject() {
        List<SObjectField> fields = SOQLQueryBuilder.getFieldsForSObject(Account.SObjectType, false, true, true);

        for (SObjectField field : fields) {
            Assert.isTrue(!field.getDescribe().isCustom());
        }
    }
    @IsTest
    public static void testGetAllFieldsLargeFieldsExcludedFieldsForSObject() {
        List<SObjectField> fields = SOQLQueryBuilder.getFieldsForSObject(Account.SObjectType, true, true, false);

        for (SObjectField field : fields) {
            Assert.isTrue(field.getDescribe().getLength() <= 255);
        }
    }
    @IsTest
    public static void testGetChildRelationshipNameShouldReturnStringNameOfRelationship() {
        List<String> relationshipNames = SOQLQueryBuilder.getChildRelationshipNames(Account.SObjectType, Contact.SObjectType);
        Assert.isTrue(relationshipNames.size() > 0);
    }


}