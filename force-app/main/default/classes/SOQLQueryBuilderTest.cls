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
        List<Account> accounts = new SOQLQueryBuilder(Account.getSObjectType())
                .selectStandardFields()
                .whereClause(Account.Name)
                .likeValue('%'+ACCOUNT_NAME+'%').getResultList();
        System.assert(accounts.size()==10);
        for(Account account:  accounts){
            System.assert(account.Name.contains(ACCOUNT_NAME));
        }
    }
    @IsTest
    public static void testQuerySingeResultAccountShouldReturnAccount(){
        Account account = (Account) new SOQLQueryBuilder(Account.getSObjectType())
                .selectStandardFields()
                .whereClause(Account.Name)
                .likeValue('%'+ACCOUNT_NAME+'%').getSingleResult('Not found');
        System.assert(account.Name.contains(ACCOUNT_NAME));
    }
    @IsTest
    public static void testQueryAccountsWithInvalidSobjectTypeNameShouldThrowException(){
        String exceptionMessage;
        try{
            List<Account> accounts = new SOQLQueryBuilder('Accountt')
                    .selectStandardFields()
                    .whereClause(Account.Name)
                    .likeValue('%'+ACCOUNT_NAME+'%').getResultList();
        }catch (Exception e){
           exceptionMessage  = e.getMessage();
        }
        System.assert(exceptionMessage!=null);
    }
    @IsTest
    public static void testQueryAccountsByNameAndAccountLevelDiscountShouldReturnAccounts(){
        List<Account> accounts = new SOQLQueryBuilder('Account')
                .selectSpecificFields(new List<SObjectField>{Account.Name,Account.AccountSource,Account.NumberOfEmployees})
                .whereWithOpenBracket(Account.Name)
                .likeValue('%'+ACCOUNT_NAME+'%')
                .andWithCloseBracket(Account.NumberOfEmployees)
                .greaterThan(20)
                .orCondition(Account.NumberOfEmployees)
                .lessThan(10)
                .orCondition(Account.AccountSource)
                .equals('Web')
                .addLimit(4)
                .getResultList();
        System.debug(accounts);
        System.assertEquals(4,accounts.size());
        for(Account account:  accounts){
            System.assertEquals(true,account.Name.contains(ACCOUNT_NAME));
            System.assertEquals('Web',account.AccountSource);
        }
    }
    @IsTest
    public static void testQueryAccountsByIdShouldReturnAccounts(){
        List<Account> accounts = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Id})
                .whereClause(Account.Name)
                .likeValue('%'+ACCOUNT_NAME+'%')
                .getResultList();

        List<Id> accountIds = new List<Id>();
        for(Account account:accounts){
            accountIds.add(account.Id);
        }
        List<Account> accountsById = new SOQLQueryBuilder(Account.getSObjectType())
                .selectAllFields(false)
                .whereClause('Id')
                .inside(accountIds)
                .getResultList();
        System.assertEquals(accountsById.size(),accountIds.size());
        for(Account account:  accountsById){
            System.assert(accountIds.contains(account.Id));
            System.debug(account);
        }
    }
    @IsTest
    public static void testQueryAccountsByAccountLevelDiscountShouldReturnAccounts(){
       List<Decimal> numberOfEmployees = new List<Decimal>{10,40,22,23};
        List<Account> accounts = new SOQLQueryBuilder(Account.getSObjectType())
                .selectAllFields(false)
                .whereClause(Account.NumberOfEmployees)
                .inside(numberOfEmployees)
                .addLimit(100)
                .addOffset(10)
                .getResultList();
        for(Account account: accounts){
            System.assert(numberOfEmployees.contains(account.NumberOfEmployees));
        }
    }
    @IsTest
    public static void testCountAccountsByIdShouldReturnInteger(){
        Integer accountCount = new SOQLQueryBuilder(Account.getSObjectType())
                .addFunction(SOQLFunction.of(SOQLFunction.FunctionName.COUNT))
                .getIntegerResult();
        System.assertEquals(10,accountCount);
    }
    @IsTest
    public static void testCountAccountsByAccountSourceFieldShouldReturnAggregateResult(){
        SOQLFunction countFunction = SOQLFunction.of(SOQLFunction.FunctionName.COUNT,Account.Id);
        AggregateResult[] accountCountAggregate = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.AccountSource})
                .addFunction(countFunction)
                .groupBy(Account.AccountSource)
                .havingWithOpenBracket(countFunction)
                .greaterThan(1)
                .orWithCloseBracket(countFunction.toString())
                .lessThan(100)
                .orWithOpenBracket(countFunction.toString())
                .greaterOrEquals(100)
                .orWithCloseBracket(countFunction.toString())
                .lessOrEquals(100)
                .getAggregateResult();
        System.assert((Integer) accountCountAggregate.get(0).get('expr0')>1);
    }
    @IsTest
    public static void testAverageAccountsAccountLevelDiscountFieldShouldReturnAggregateResult(){
        AggregateResult[] accountAverageAggregate = new SOQLQueryBuilder(Account.getSObjectType())
                .addFunction(SOQLFunction.of(SOQLFunction.FunctionName.AVG,Account.NumberOfEmployees))
                .getAggregateResult();
        System.assertEquals(55,accountAverageAggregate.get(0).get('expr0')) ;
    }
    @IsTest
    public static void testInnerContactQueryWithAccountShouldReturnAccountWithContacts(){
        List<Account> accounts = new SOQLQueryBuilder(Account.getSObjectType())
                .selectCustomFields(true)
                .addInnerQuery(new SOQLQueryBuilder(Contact.getSObjectType())
                        .selectStandardFields()
                        .whereClause(Contact.LastName)
                        .likeValue('%'+CONTACT_LAST_NAME+'%')
                        .andCondition(Contact.FirstName)
                        .likeValue('%'+CONTACT_FIRST_NAME+'%'))
                .whereClause(Contact.Name)
                .likeValue('%'+ACCOUNT_NAME+'%')
                .getResultList();
        for(Account account: accounts){
           System.assert(!account.Contacts.isEmpty());
        }
    }
    @IsTest
    public static void testInnerContactAndCasesQueryWithAccountShouldReturnAccountWithContactsAndCases(){
        List<Account> accounts = new SOQLQueryBuilder(Account.getSObjectType())
                .selectCustomFields(true)
                .addInnerQuery(new SOQLQueryBuilder(Contact.getSObjectType())
                        .selectStandardFields())
                .addInnerQuery(new SOQLQueryBuilder(Case.getSObjectType())
                        .selectStandardFields())
                .whereClause(Contact.Name)
                .likeValue('%'+ACCOUNT_NAME+'%')
                .getResultList();
        for(Account account: accounts){
            System.assert(!account.Contacts.isEmpty());
            System.assert(account.Cases.isEmpty());
        }
    }
    @IsTest
    public static void testParentAccountQueryWithContactShouldReturnContact(){
         Contact contact = (Contact)new SOQLQueryBuilder(Contact.getSObjectType())
                .selectAllFields(false)
                .addParentQuery(new SOQLQueryBuilder(Account.getSObjectType())
                        .selectStandardFields())
                 .addParentQuery(new SOQLQueryBuilder(Contact.getSObjectType())
                         .selectStandardFields()
                         .setParentSObjectTypeName('ReportsTo'))
                .whereClause(Contact.LastName)
                .likeValue('%'+CONTACT_LAST_NAME+'%')
                .getSingleResult();
        System.assertEquals(ACCOUNT_NAME+' 1',contact.Account.Name);

    }
    @IsTest
    public static void testAccountOrderByShouldReturnAccounts(){
        List<Decimal> discounts = new List<Decimal>{10,40,22,23};
        List<Account> accounts = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name,Account.NumberOfEmployees})
                .whereClause(Account.NumberOfEmployees)
                .notInside(discounts)
                .orderBy(Account.Name).ascending().nullsFirst()
                .orderBy(Account.NumberOfEmployees).descending().nullsLast()
                .getResultList();
       System.assertEquals(8,accounts.size());
    }
    @IsTest
    public static void testAccountGroupByShouldReturnAccounts(){
        AggregateResult[] aggregateResult = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name})
                .groupBy(Account.Name)
                .getAggregateResult();
       System.assertEquals(10,aggregateResult.size());
    }
    @IsTest
    public static void testQueryAccountsByNameShouldReturnAccountsForUpdate(){
        String queryStr = new SOQLQueryBuilder(Account.getSObjectType())
                .whereClause(Account.Name)
                .likeValue('%'+ACCOUNT_NAME+'%')
                .forUpdate()
                .toString();
        System.assert(queryStr.containsIgnoreCase('FOR UPDATE'));
    }
    @IsTest
    public static void testQueryAccountsByNameShouldReturnAccountsForView(){
        String queryStr = new SOQLQueryBuilder(Account.getSObjectType())
                .whereClause(Account.Name)
                .likeValue('%'+ACCOUNT_NAME+'%')
                .forView()
                .toString();
        System.assert(queryStr.containsIgnoreCase('FOR VIEW'));
    }
    @IsTest
    public static void testQueryAccountsByNameShouldReturnAccountsForReference(){
        String queryStr = new SOQLQueryBuilder(Account.getSObjectType())
                .whereClause(Account.Name)
                .likeValue('%'+ACCOUNT_NAME+'%')
                .forReference()
                .toString();
        System.assert(queryStr.containsIgnoreCase('FOR REFERENCE'));
    }
    @IsTest
    public static void testQueryAccountsByNameShouldReturnAccountsUpdateTracking(){
        String queryStr = new SOQLQueryBuilder(Account.getSObjectType())
                .whereClause(Account.Name)
                .likeValue('%'+ACCOUNT_NAME+'%')
                .updateTracking()
                .toString();
        System.assert(queryStr.containsIgnoreCase('UPDATE TRACKING'));
    }
    @IsTest
    public static void testQueryAccountsByNameShouldReturnAccountsUpdateViewstat(){
        String queryStr = new SOQLQueryBuilder(Account.getSObjectType())
                .whereClause(Account.Name)
                .likeValue('%'+ACCOUNT_NAME+'%')
                .updateViewStat()
                .toString();
        System.assert(queryStr.containsIgnoreCase('UPDATE VIEWSTAT'));
    }
    @IsTest
    public static void testQueryAccountsByNameShouldReturnAccountsAllRows(){
        String queryStr = new SOQLQueryBuilder(Account.getSObjectType())
                .whereClause(Account.Name)
                .likeValue('%'+ACCOUNT_NAME+'%')
                .andWithOpenBracket(Account.Name)
                .notEquals('fail')
                .andWithCloseBracket(Account.Name)
                .notEquals('')
                .allRows()
                .toString();
        System.assert(queryStr.containsIgnoreCase('SELECT Id FROM Account WHERE   Name LIKE \'%Test account name%\'  AND (Name != \'fail\'  AND  Name != \'\')  ALL ROWS'));
    }
    @IsTest
    public static void testQueryAccountsByCustomWhereStatementShouldReturnAccounts(){
        List<Account> accounts = new SOQLQueryBuilder(Account.getSObjectType())
                .selectStandardFields()
                .whereStatement(' Name Like '+ '\'%'+ACCOUNT_NAME+'%\'' )
                .getResultList();
        System.assert(accounts.size()==10);
        for(Account account:  accounts){
            System.assert(account.Name.contains(ACCOUNT_NAME));
        }
    }
    @IsTest
    public static void testQueryAccountsByNameShouldReturnAccountsSecurityEnforced(){
        String queryStr = new SOQLQueryBuilder(Account.getSObjectType())
                .whereClause(Account.Name)
                .notLikeValue('%'+ACCOUNT_NAME+'%')
                .withSecurityEnforced()
                .toString();
        System.assert(queryStr.containsIgnoreCase('SECURITY_ENFORCED'));
    }
    @IsTest
    public static void testQueryAccountsByNameShouldReturnAccountsUsingWithStatement(){
        String queryStr = new SOQLQueryBuilder(Account.getSObjectType())
                .whereClause(Account.Name)
                .likeValue('%'+ACCOUNT_NAME+'%')
                .with('WITH DATA CATEGORY Geography__c')
                .withSecurityEnforced()
                .toString();
        System.assert(queryStr.containsIgnoreCase('SELECT Id FROM Account WHERE   Name LIKE \'%Test account name%\'   WITH WITH DATA CATEGORY Geography__c SECURITY_ENFORCED'));
    }
    @IsTest
    public static void testQueryAccountsByNameShouldReturnAccountsUsingScope(){
        String queryStr = new SOQLQueryBuilder(Account.getSObjectType())
                .whereClause(Account.Name)
                .likeValue('%'+ACCOUNT_NAME+'%')
                .usingScope(FilterScope.mine)
                .toString();
        System.assert(queryStr.containsIgnoreCase('USING SCOPE '+FilterScope.mine));
    }
    @IsTest
    public static void testQueryLeadWithGroupByRollup(){
        String queryStr = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .addFunction(SOQLFunction.of(SOQLFunction.FunctionName.COUNT,Lead.Name).setAlias('cnt'))
                .groupBy(SOQLFunction.of(SOQLFunction.FunctionName.ROLLUP,Lead.LeadSource))
                .toString();
        System.assert(queryStr.contains('SELECT LeadSource,COUNT(Name) cnt FROM Lead GROUP BY ROLLUP(LeadSource)'));
    }
    @IsTest
    public static void testInnerFunctionWithGroupBy(){
        SOQLFunction convertTimeZoneFunction = SOQLFunction.of(SOQLFunction.FunctionName.convertTimezone,Opportunity.CreatedDate);
        SOQLFunction hourInDayFunction = SOQLFunction.of(SOQLFunction.FunctionName.HOUR_IN_DAY,convertTimeZoneFunction);
        SOQLFunction sumAmountFunction = SOQLFunction.of(SOQLFunction.FunctionName.SUM,Opportunity.Amount);
        String queryStr = new SOQLQueryBuilder(Opportunity.getSObjectType())
                .addFunction(hourInDayFunction)
                .addFunction(sumAmountFunction)
                .groupBy(hourInDayFunction)
                .toString();
        System.assert(queryStr.contains('SELECT HOUR_IN_DAY(convertTimezone(CreatedDate)),SUM(Amount) FROM Opportunity GROUP BY HOUR_IN_DAY(convertTimezone(CreatedDate))'));
    }
    @IsTest
    public static void testSOQLFunction(){
        SOQLFunction sumAmountFunction = SOQLFunction.of(SOQLFunction.FunctionName.SUM,Opportunity.Amount);
        sumAmountFunction.getName();
        sumAmountFunction.getAlias();
        sumAmountFunction.getFieldNames();
        sumAmountFunction.getInnerFunction();
        sumAmountFunction.addFieldName(Opportunity.Amount);
        sumAmountFunction.setFieldNames(new List<String>{Opportunity.Amount.getDescribe().getName()});
    }

}