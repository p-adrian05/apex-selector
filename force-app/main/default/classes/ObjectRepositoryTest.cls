@IsTest
public with sharing class ObjectRepositoryTest {

    private final static String ACCOUNT_NAME= 'Test account name';

    @TestSetup
    public static void setup() {
        List<Account> accounts = new List<Account>();
        for(Integer i = 1; i<=3; i++){
            Account account = new Account();
            account.Name = ACCOUNT_NAME +' '+i;
            accounts.add(account);
        }
        insert accounts;
    }

    @IsTest
    public static void testFindByIdShouldReturnAccount(){
        Account account = [SELECT Id FROM Account LIMIT 1];
        ObjectRepository objectRepository = new ObjectRepositoryImpl('Account');
        Optional accountOptional = objectRepository.findById(account.Id);

        Account queriedAccount = (Account) accountOptional.get();

        Assert.isTrue(accountOptional.isPresent());
        Assert.isFalse(accountOptional.isEmpty());
        Assert.areEqual(account.Id,queriedAccount.Id);
    }
    @IsTest
    public static void testFindByIdsShouldReturnAccount(){
        List<Account> accounts = [SELECT Id FROM Account];
        ObjectRepository objectRepository = new ObjectRepositoryImpl('Account');

        Map<Id,SObject> queriedAccounts = objectRepository.findAllById(getIdsFromSObjects(accounts));

        Assert.areEqual(accounts.size(),queriedAccounts.size());
    }
    @IsTest
    public static void testFindByIdsWithFieldsShouldReturnAccount(){
        List<Account> accounts = [SELECT Id FROM Account];
        ObjectRepository objectRepository = new ObjectRepositoryImpl('Account');

        Map<Id,SObject> queriedAccounts = objectRepository.findAllById(getIdsFromSObjects(accounts),new List<SObjectField>{});

        Assert.areEqual(accounts.size(),queriedAccounts.size());
        for(SObject account : queriedAccounts.values()){
            String sObjectExceptionMessage;
            try{
                Object name = account.get('Name');
            }catch (Exception e){
                sObjectExceptionMessage = e.getMessage();
            }
            Assert.isNotNull(sObjectExceptionMessage);
        }
    }
    @IsTest
    public static void testFindByIdWithFieldsShouldReturnAccount(){
        Account account = [SELECT Id,Name FROM Account LIMIT 1];

        ObjectRepository objectRepository = new ObjectRepositoryImpl('Account');
        Optional accountOptional = objectRepository.findById(account.Id,new List<SObjectField>{});

        Account queriedAccount = (Account) accountOptional.get();

        Assert.isTrue(accountOptional.isPresent());
        Assert.isFalse(accountOptional.isEmpty());
        Assert.areEqual(account.Id,queriedAccount.Id);

        String sObjectExceptionMessage;
        try{
            String name = queriedAccount.Name;
        }catch (Exception e){
            sObjectExceptionMessage = e.getMessage();
        }
        Assert.isNotNull(sObjectExceptionMessage);
    }
    @IsTest
    public static void testFindByNameWithFieldsShouldReturnAccount() {
        Account accountTest = [SELECT Id, Name FROM Account LIMIT 1];
        ObjectRepository objectRepository = new ObjectRepositoryImpl('Account');

        Map<Id,SObject> accounts  = objectRepository.findByName(accountTest.Name,new List<SObjectField>{Account.Name});

        Assert.areEqual(1,accounts.size());
        Account queriedAccount = (Account) accounts.values().get(0);
        Assert.areEqual(accountTest.Name,queriedAccount.Name);

        String sObjectExceptionMessage;
        try{
            Datetime d = queriedAccount.CreatedDate;
        }catch (Exception e){
            sObjectExceptionMessage = e.getMessage();
        }
        Assert.isNotNull(sObjectExceptionMessage);
    }
    @IsTest
    public static void testFindByNameShouldReturnAccount() {
        Account accountTest = [SELECT Id, Name FROM Account LIMIT 1];
        ObjectRepository objectRepository = new ObjectRepositoryImpl('Account');

        Map<Id,SObject> accounts  = objectRepository.findByName(accountTest.Name);

        Assert.areEqual(1,accounts.size());
        Account queriedAccount = (Account) accounts.values().get(0);
        Assert.areEqual(accountTest.Name,queriedAccount.Name);

    }
    private static List<Id> getIdsFromSObjects(List<SObject> sObjects){
        List<Id> recordIds = new List<Id>();
        if(sObjects!=null && sObjects.size()>0){
            for(SObject sobj:sObjects){
                if(sobj.Id !=null){
                    recordIds.add(sobj.Id);
                }
            }
        }
        return recordIds;
    }

}