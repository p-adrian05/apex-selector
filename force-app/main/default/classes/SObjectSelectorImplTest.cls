@IsTest
public with sharing class SObjectSelectorImplTest {

    @TestSetup
    public static void setup() {
        List<Account> accounts = new List<Account>();
        for(Integer i = 1; i<=3; i++){
            Account account = new Account();
            account.Name = 'Test '+i;
            accounts.add(account);
        }
        insert accounts;
    }

    @IsTest
    public static void testSelectByIdShouldReturnAccount(){
        Account account = [SELECT Id FROM Account LIMIT 1];
        SObjectSelector accountSelector = new AccountsSelector();
        Account queriedAccount = (Account) accountSelector.selectById(account.Id);

        Assert.areEqual(account.Id,queriedAccount.Id);
    }
    @IsTest
    public static void testSelectByIdsShouldReturnAccount(){
        List<Account> accounts = [SELECT Id FROM Account];
        AccountsSelector accountSelector = new AccountsSelector();

        List<Account> queriedAccounts = accountSelector.getAccountsByIds(getIdsFromSObjects(accounts));

        Assert.areEqual(accounts.size(),queriedAccounts.size());
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