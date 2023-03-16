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

    @IsTest
    public static void testQueryAccountsByNameShouldReturnAccounts(){
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectStandardFields()
                .whereClause(Account.Name)
                .likeValue('%'+ACCOUNT_NAME+'%');

        Map<Id,SObject> accountMap = soqlQueryBuilder.getResultMap();
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
                    .likeValue('%'+ACCOUNT_NAME+'%').getResultList();
        }catch (Exception e){
           exceptionMessage  = e.getMessage();
        }
        Assert.isNotNull(exceptionMessage);
    }

    @IsTest
    public static void testQueryAccountsByNameAndAccountLevelDiscountShouldReturnAccounts(){
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder('Account')
                .selectSpecificFields(new List<SObjectField>{Account.Name,Account.AccountSource,Account.NumberOfEmployees})
                .whereOpenBracket(Account.Name)
                .likeValue('%'+ACCOUNT_NAME+'%')
                .andCloseBracket(Account.NumberOfEmployees)
                .greaterThan(20)
                .orCondition(Account.NumberOfEmployees)
                .lessThan(10)
                .orCondition(Account.AccountSource)
                .equals('Web')
                .addLimit(4);

        String expectedQueryString = 'SELECT Name,AccountSource,NumberOfEmployees FROM Account WHERE  ' +
                '(Name LIKE \'%Test account name%\'  AND  NumberOfEmployees > 20) OR  NumberOfEmployees < 10  ' +
                'OR  AccountSource = \'Web\'   LIMIT 4';

        List<Account> accounts = soqlQueryBuilder.getResultList();
        String actualQueryString = soqlQueryBuilder.toString();

        Assert.areEqual(4,accounts.size());
        for(Account account:  accounts){
            Assert.isTrue(account.Name.contains(ACCOUNT_NAME));
            Assert.areEqual('Web',account.AccountSource);
        }
        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
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
    //TODO: fix this test
    @IsTest
    public static void testQueryAccountsByAccountLevelDiscountShouldReturnAccounts(){
       List<Decimal> numberOfEmployees = new List<Decimal>{10,40,22,23};

       SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name,Account.NumberOfEmployees})
                .whereClause(Account.NumberOfEmployees)
                .inside(numberOfEmployees)
                .andCondition(Account.CreatedDate)
                .greaterThan(Date.newInstance(2022,02,1))
                .addLimit(100)
                .addOffset(10);

       String expectedQueryString = 'SELECT Name,NumberOfEmployees FROM Account WHERE  ' +
               ' NumberOfEmployees IN (10,40,22,23) AND CreatedDate > 2022-02-01T00:00:00Z LIMIT 100 OFFSET 10';

       List<Account> accounts = soqlQueryBuilder.getResultList();
       String actualQueryString = soqlQueryBuilder.toString();

       for(Account account: accounts){
            Assert.isTrue(numberOfEmployees.contains(account.NumberOfEmployees));
       }
        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }
    @IsTest
    public static void testCountAccountsByIdShouldReturnInteger(){
       SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .addFunction(SOQLFunction.of(SOQLFunction.FunctionName.COUNT));

        Integer accountCount = soqlQueryBuilder.getIntegerResult();
        String expectedQueryString = 'SELECT COUNT() FROM Account';

        String actualQueryString = soqlQueryBuilder.toString();

        Assert.areEqual(10,accountCount);
        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }
    @IsTest
    public static void testCountAccountsByAccountSourceFieldShouldReturnAggregateResult(){
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

        String expectedQueryString = 'SELECT AccountSource,COUNT(Id) FROM Account WHERE ' +
                'Name LIKE \'%Test account name%\' OR ((NOT Name LIKE\'%builder%\') OR  NumberOfEmployees >= 12) ' +
                ' GROUP BY AccountSource ' +
                'HAVING  (COUNT(Id) > 1  OR  COUNT(Id) < 100) AND (COUNT(Id) >= 100  OR  COUNT(Id) <= 10)';

        AggregateResult[] accountCountAggregate = soqlQueryBuilder.getAggregateResult();
        String actualQueryString = soqlQueryBuilder.toString();

        Assert.isTrue((Integer) accountCountAggregate.get(0).get('expr0')>1);
        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }
    @IsTest
    public static void testLeadsGroupByName(){
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.City,Lead.CreatedDate})
                .whereClause(Lead.CreatedDate)
                .inside(new List<Date>{Date.newInstance(2022,02,01)})
                .groupBy(Lead.City)
                .havingClause(Lead.City)
                .likeValue('%San');

        String expectedQueryString = 'SELECT City,CreatedDate FROM Lead WHERE' +
                ' CreatedDate IN (2022-02-01T00:00:00Z)  ' +
                'GROUP BY City HAVING City LIKE \'%San\'';

        String queryString = soqlQueryBuilder.toString();

        Assert.isTrue(queryString.containsOnly(expectedQueryString));
    }
    @IsTest
    public static void testCountLeadsNameGroupByLeadSource(){
        SOQLFunction countFunction = SOQLFunction.of(SOQLFunction.FunctionName.COUNT,Lead.Name);
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .addFunction(countFunction)
                .groupBy(Lead.LeadSource)
                .havingClause(countFunction)
                .greaterThan(23);

        String expectedQueryString = 'SELECT LeadSource,COUNT(Name) FROM Lead GROUP BY LeadSource HAVING COUNT(Name) > 23';

        String actualQueryString = soqlQueryBuilder.toString();

        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }
    @IsTest
    public static void testCountLeadsByNameGroupByCity(){
        SOQLFunction countFunction = SOQLFunction.of(SOQLFunction.FunctionName.COUNT,Lead.Name);
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.City})
                .addFunction(countFunction)
                .groupBy(Lead.City)
                .havingOpenBracket(Lead.City)
                .likeValue('%San')
                .andCloseBracket(countFunction.toString())
                .greaterThan(1);

        String expectedQueryString = 'SELECT City,COUNT(Name) FROM Lead GROUP BY City ' +
                'HAVING  (City LIKE \'%San\'  AND  COUNT(Name) > 1)';

        String actualQueryString = soqlQueryBuilder.toString();

        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }
    @IsTest
    public static void testAverageAccountsAccountLevelDiscountFieldShouldReturnAggregateResult(){
         SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .addFunction(SOQLFunction.of(SOQLFunction.FunctionName.AVG,Account.NumberOfEmployees));

        String expectedQueryString = 'SELECT AVG(NumberOfEmployees) FROM Account';

        AggregateResult[] accountAverageAggregate = soqlQueryBuilder.getAggregateResult();

        String actualQueryString = soqlQueryBuilder.toString();

        Assert.areEqual(55,accountAverageAggregate.get(0).get('expr0')) ;
        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }
    @IsTest
    public static void testInnerContactQueryWithAccountShouldReturnAccountWithContacts(){
       SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
               .selectSpecificFields(new List<SObjectField>{Account.Name})
                .addInnerQuery(new SOQLQueryBuilder(Contact.getSObjectType())
                        .selectSpecificFields(new List<SObjectField>{Contact.LastName,Contact.FirstName})
                        .whereClause(Contact.LastName)
                        .likeValue('%'+CONTACT_LAST_NAME+'%')
                        .andCondition(Contact.FirstName)
                        .likeValue('%'+CONTACT_FIRST_NAME+'%'))
                .whereClause(Contact.Name)
                .likeValue('%'+ACCOUNT_NAME+'%');

        String expectedQueryString = 'SELECT Name,(SELECT LastName,FirstName FROM Contacts WHERE  ' +
                ' LastName LIKE \'%Contact lastName%\'  AND  FirstName LIKE \'%Contact firstName%\') ' +
                'FROM Account WHERE   Name LIKE \'%Test account name%\'';

        List<Account> accounts = soqlQueryBuilder.getResultList();
        String actualQueryString = soqlQueryBuilder.toString();

        for(Account account: accounts){
           System.assert(!account.Contacts.isEmpty());
        }
        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }
    @IsTest
    public static void testInnerContactAndContractQueryWithAccountShouldReturnAccountWithContactsAndContracts(){
      SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
              .selectSpecificFields(new List<SObjectField>{Account.Name})
                .addInnerQuery(new SOQLQueryBuilder(Contact.getSObjectType())
                        .selectSpecificFields(new List<SObjectField>{Contact.Name}))
                .addInnerQuery(new SOQLQueryBuilder(Contract.getSObjectType())
                        .selectSpecificFields(new List<SObjectField>{Contract.Name}))
                .whereClause(Contact.Name)
                .likeValue('%'+ACCOUNT_NAME+'%');

        String expectedQueryString = 'SELECT Name,(SELECT Name FROM Contacts ),(SELECT Name FROM Contracts ) ' +
                'FROM Account WHERE   Name LIKE \'%Test account name%\'';

        List<Account> accounts = soqlQueryBuilder.getResultList();
        String actualQueryString = soqlQueryBuilder.toString();

        for(Account account: accounts){
            Assert.isTrue(!account.Contacts.isEmpty());
        }
        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }
    @IsTest
    public static void testParentAccountQueryWithContactShouldReturnContact(){
      SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Contact.getSObjectType())
              .selectSpecificFields(new List<SObjectField>{Contact.LastName})
                .addParentQuery(new SOQLQueryBuilder(Account.getSObjectType())
                        .selectSpecificFields(new List<SObjectField>{Account.Name}))
                 .addParentQuery(new SOQLQueryBuilder(Contact.getSObjectType())
                         .selectSpecificFields(new List<SObjectField>{Contact.Name})
                         .setParentSObjectTypeName('ReportsTo'))
                .whereClause(Contact.LastName)
                .likeValue('%'+CONTACT_LAST_NAME+'%');

        String expectedQueryString = 'SELECT LastName,Account.Name,ReportsTo.Name FROM Contact WHERE ' +
                ' LastName LIKE \'%Contact lastName%\'';

        Contact contact = (Contact) soqlQueryBuilder.getSingleResult();
        String actualQueryString = soqlQueryBuilder.toString();

        Assert.areEqual(ACCOUNT_NAME+' 1',contact.Account.Name);
        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }
    @IsTest
    public static void testAccountOrderByShouldReturnAccounts(){
        List<Decimal> discounts = new List<Decimal>{10,40,22,23};
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name,Account.NumberOfEmployees})
                .whereClause(Account.NumberOfEmployees)
                .notInside(discounts)
                .orderBy(Account.Name).ascending().nullsFirst()
                .orderBy(Account.NumberOfEmployees).descending().nullsLast();

        String expectedQueryString = 'SELECT Name,NumberOfEmployees FROM Account WHERE ' +
                'NumberOfEmployees NOT IN (10,40,22,23) ' +
                'ORDER BY Name ASC NULLS FIRST, NumberOfEmployees DESC NULLS LAST';

        List<Account> accounts = soqlQueryBuilder.getResultList();
        String actualQueryString = soqlQueryBuilder.toString();

        Assert.areEqual(8,accounts.size());
        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }
    @IsTest
    public static void testAccountGroupByShouldReturnAccounts(){
       SOQLQueryBuilder soqlQueryBuilder =  new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name})
                .groupBy(Account.Name);

       String expectedQueryString = 'SELECT Name FROM Account GROUP BY Name';

       AggregateResult[] aggregateResult = soqlQueryBuilder.getAggregateResult();
       String actualQueryString = soqlQueryBuilder.toString();

       Assert.areEqual(10,aggregateResult.size());
       Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }
    @IsTest
    public static void testQueryAccountsShouldReturnAccountsForUpdate(){
        SOQLQueryBuilder soqlQueryBuilder =  new SOQLQueryBuilder(Account.getSObjectType()).forUpdate();

        String expectedQueryString = 'SELECT Id FROM Account FOR UPDATE';

        String actualQueryString = soqlQueryBuilder.toString();

        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }
    @IsTest
    public static void testQueryAccountsShouldReturnAccountsForView(){
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType()).forView();
        String expectedQueryString = 'SELECT Id FROM Account FOR VIEW';

        String actualQueryString = soqlQueryBuilder.toString();

        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }
    @IsTest
    public static void testQueryAccountsShouldReturnAccountsForReference(){
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType()).forReference();
        String expectedQueryString = 'SELECT Id FROM Account FOR REFERENCE';

        String actualQueryString = soqlQueryBuilder.toString();

        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }
    @IsTest
    public static void testQueryAccountsShouldReturnAccountsUpdateTracking(){
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType()).updateTracking();
        String expectedQueryString = 'SELECT Id FROM Account UPDATE TRACKING';

        String actualQueryString = soqlQueryBuilder.toString();

        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }
    @IsTest
    public static void testQueryAccountsShouldReturnAccountsUpdateViewStat(){
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType()).updateViewStat();

        String expectedQueryString = 'SELECT Id FROM Account UPDATE VIEWSTAT';

        String actualQueryString = soqlQueryBuilder.toString();

        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }
    @IsTest
    public static void testQueryAccountsByNameShouldReturnAccountsAllRows(){
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .whereClause(Account.Name)
                .likeValue('%'+ACCOUNT_NAME+'%')
                .andOpenBracket(Account.Name)
                .notEquals('fail')
                .andCloseBracket(Account.Name)
                .notEquals('')
                .allRows()
                .withSecurityEnforced();

        String expectedQueryString = 'SELECT Id FROM Account WHERE' +
                ' Name LIKE \'%Test account name%\'  AND (Name != \'fail\' AND  Name != \'\') ' +
                ' WITH SECURITY_ENFORCED ALL ROWS';

        String actualQueryString = soqlQueryBuilder.toString();

        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }
    @IsTest
    public static void testQueryAccountsByCustomWhereStatementShouldReturnAccounts(){
         SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name})
                .whereStatement('Name Like '+ '\'%'+ACCOUNT_NAME+'%\'');

        String expectedQueryString = 'SELECT Name FROM Account  WHERE Name Like \'%Test account name%\'';

        List<Account> accounts = soqlQueryBuilder.getResultList();
        String actualQueryString = soqlQueryBuilder.toString();

        Assert.areEqual(10,accounts.size());
        for(Account account:  accounts){
            Assert.isTrue(account.Name.contains(ACCOUNT_NAME));
        }
        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }
    @IsTest
    public static void testQueryAccountsShouldReturnAccountsUsingWithStatement(){
        SOQLQueryBuilder soqlQueryBuilder =  new SOQLQueryBuilder(Account.getSObjectType())
                .with('DATA CATEGORY Geography__c').withSecurityEnforced();
        String expectedQueryString = 'SELECT Id FROM Account WITH DATA CATEGORY Geography__c SECURITY_ENFORCED';

        String actualQueryString = soqlQueryBuilder.toString();

        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }
    @IsTest
    public static void testQueryAccountsByNameShouldReturnAccountsUsingScope(){
         SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .whereClause(Account.Name)
                .likeValue('%'+ACCOUNT_NAME+'%')
                .usingScope(FilterScope.mine);

        String expectedQueryString = 'SELECT Id FROM Account WHERE Name LIKE \'%Test account name%\' USING SCOPE mine';

        String actualQueryString = soqlQueryBuilder.toString();

        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
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

        String actualQueryString = soqlQueryBuilder.toString();

        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
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

        String actualQueryString = soqlQueryBuilder.toString();

        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
    }
    @IsTest
    public static void testMultiSelectPicklistOperators(){
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.AccountSource})
                .whereClause(Account.AccountSource)
                .includes(new List<String>{'Web','Phone Inquiry'})
                .orCondition(Account.AccountSource)
                .excludes(new List<String>{'Other'});

        String expectedQueryString = 'SELECT AccountSource FROM Account WHERE ' +
                'AccountSource INCLUDES (\'Web\',\'Phone Inquiry\') OR AccountSource EXCLUDES (\'Other\')';

        String actualQueryString = soqlQueryBuilder.toString();

        Assert.areEqual(expectedQueryString.deleteWhitespace(),actualQueryString.deleteWhitespace());
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
    public static void testConvertSObjectTypeNameToParent(){
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType());

        String standardObjectNameResult = soqlQueryBuilder.convertSObjectTypeNameToParent('Account');
        System.assertEquals('Account', standardObjectNameResult);

        String customObjectNameResult = soqlQueryBuilder.convertSObjectTypeNameToParent('Custom__c');
        System.assertEquals('Custom__r', customObjectNameResult);
    }
    @IsTest
    public static void testGetAllFieldsForSObject() {
        List<SObjectField> fields = SOQLQueryBuilder.getFieldsForSObject('Account', true, true, true);

        Assert.isTrue(fields.size() > 0);
        for (SObjectField field : fields) {
            Assert.isNotNull(field.getDescribe().getName());
            Assert.isNotNull(field.getDescribe().getLabel());
            Assert.isNotNull(field.getDescribe().getType());
        }
    }
    @IsTest
    public static void testGetCustomFieldsForSObject() {
        List<SObjectField> fields = SOQLQueryBuilder.getFieldsForSObject('Account', true, false, true);

        for (SObjectField field : fields) {
            Assert.isTrue(field.getDescribe().isCustom());
        }
    }
    @IsTest
    public static void testGetStandardFieldsForSObject() {
        List<SObjectField> fields = SOQLQueryBuilder.getFieldsForSObject('Account', false, true, true);

        for (SObjectField field : fields) {
            Assert.isTrue(!field.getDescribe().isCustom());
        }
    }
    @IsTest
    public static void testGetAllFieldsLargeFieldsExcludedFieldsForSObject() {
        List<SObjectField> fields = SOQLQueryBuilder.getFieldsForSObject('Account', true, true, false);

        for (SObjectField field : fields) {
            Assert.isTrue(field.getDescribe().getLength() <= 255);
        }
    }
    @IsTest
    public static void testGetChildRelationshipNameShouldReturnStringNameOfRelationship() {
        String relationshipName = SOQLQueryBuilder.getChildRelationshipName(Account.SObjectType, Contact.SObjectType);
        System.assertEquals('Contacts', relationshipName);
    }


}