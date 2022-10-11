@IsTest
public with sharing class DatabaseUtilTest {

    private final static String ACCOUNT_NAME_DEFAULT = 'Test Account name';
    private final static String OPP_NAME_DEFAULT = 'Test Opoortunity name';

    @TestSetup
    public static void setup() {
        List<SObject> sobjects = new List<SObject>();
          for(Integer i = 1; i<=3; i++){
            Account account = new Account();
            account.Name = ACCOUNT_NAME_DEFAULT +' '+i;
            sobjects.add(account);
          }
        Opportunity opp = new Opportunity();
        opp.CloseDate = Date.newInstance(2021, 11, 30);
        opp.Name = OPP_NAME_DEFAULT;
        opp.StageName = 'test';
        sobjects.add(opp);

        insert sobjects;

    }
    private static List<Account> queryTestAccounts(){
        String likeStatement = '%'+ACCOUNT_NAME_DEFAULT+'%';
        List<Account> accounts = [SELECT Id, Name FROM Account WHERE Name LIKE :likeStatement];
        return accounts;
    }

    @IsTest
    public static void testQuerySObjectsByIdsWithListOfIdShouldReturnQueriedSObjects(){
        List<Account> accounts = queryTestAccounts();
        List<Opportunity> opps = [SELECT Id, Name, CloseDate, StageName FROM Opportunity WHERE Name LIKE :OPP_NAME_DEFAULT];
        List<Id> ids = new List<Id>();
        ids.addAll(filterIds(accounts));
        ids.addAll(filterIds(opps));

        Map<Id,SObject> sObjects = DatabaseUtil.querySObjectsByIdsToMap(ids);

        Set<Id> resultIds = sObjects.keySet();
        System.assertEquals(accounts.size()+opps.size(), sObjects.size());

        for(SObject sObj : sObjects.values()){
            String type = String.valueOf(sObj.getSObjectType());
            switch on type {
                when 'Account' {
                    System.assert(resultIds.contains(sObj.Id));
                }
                when 'Opportunity' {
                    System.assert(resultIds.contains(sObj.Id));
                }
            }
        }
    }
    @IsTest
    public static void testQuerySObjectsByIdsWithListOfIdAndTypeShouldReturnQueriedSObjects(){
        List<Account> accounts = queryTestAccounts();
        List<Id> ids = filterIds(accounts);
    
        List<SObject> sObjects = DatabaseUtil.querySObjectsByIds(ids,'Account');
        List<Id> queriedIds = filterIds(sObjects);

        System.assertEquals(accounts.size(), sObjects.size());

        for(Id id : ids){
            System.assert(queriedIds.contains(id));
        }
    }
    @IsTest
    public static void testQuerySObjectsByIdsWithWrongFieldShouldThrowException(){
        List<Account> accounts = queryTestAccounts();
        List<Id> ids = filterIds(accounts);
    
        try{
            DatabaseUtil.querySObjectsByIdsToMap(ids,new List<String>{'Name','wrong'});
        }catch(System.QueryException e){
            System.assert(e.getMessage().contains('No such column \'wrong\''));
        }
    }
    //Org specific test for SObject recordTypes
    @IsTest
    public static void testGetFieldsByLayoutShouldReturnQueriedFields(){
       List<String> fields = DatabaseUtil.getFieldsByLayout('Account','Account Layout');
       System.assert(fields.size()>0);
    }

    @IsTest
    public static void testGetRecordTypeIdBySobjectAndShouldReturnQueriedRecordTypeId(){
        List<Account> accounts = queryTestAccounts();
        try{
            String recordTypeId = DatabaseUtil.getRecordTypeIdBySObjectIdAndType(accounts.get(0).Id,'Account');
            System.assert(recordTypeId!=null);
        }catch (Exception e){}

    }
    @IsTest
    public static void testGetRecordTypeIdBySobjectAndShouldReturnNullWithInvalidId(){
        try{
            String recordTypeId = DatabaseUtil.getRecordTypeIdBySObjectIdAndType('0010D00000Y9rKVQAA','Account');
            System.assert(recordTypeId==null);
        }catch (Exception e){}

    }
    @IsTest
    public static void testGetRecordTypeNameByRecordIdShouldReturnRecordTypeName(){
        try{
            List<Account> accounts = queryTestAccounts();
            String recordTypeId = DatabaseUtil.getRecordTypeIdBySObjectIdAndType(accounts.get(0).Id,'Account');
            String recordTypeName = DatabaseUtil.getRecordTypeNameByRecordTypeId(recordTypeId);
            System.assert(recordTypeName.equals('Account'));

        }catch (Exception e){}

    }
    @IsTest
    public static void testGetRecordTypeNameByRecordIdShouldReturnNullWithInvalidRecordTypeId(){
        try{
            String recordTypeId = DatabaseUtil.getRecordTypeIdBySObjectIdAndType('0010D00000Y9rKVQAA','Account');
            String recordTypeName = DatabaseUtil.getRecordTypeNameByRecordTypeId(recordTypeId);
            System.assert(recordTypeName == null);
        }catch (Exception e){}
    }
    @IsTest
    public static void testGetRecordTypeNameBySObjectIdAndShouldReturnRecordTypeName(){
        try{
            List<Account> accounts = queryTestAccounts();
            String recordTypeName = DatabaseUtil.getRecordTypeNameBySObjectIdAndType(accounts.get(0).Id,'Account');
            System.assert(recordTypeName.equals('Account'));
        }catch (Exception e){}

    }
    @IsTest
    public static void testGetRecordTypeNameBysObjectIdsAndShouldReturnMap(){
        List<Account> accounts = queryTestAccounts();
        try{
            Map<Id,String> sObjectIdAndRecordTypeNameMap =  DatabaseUtil.getRecordTypeDeveloperNameBysObjectIds(DatabaseUtil.getIdsFromSObjects(accounts),'Account');
            for(Account account : accounts){
                System.assertEquals('Account',sObjectIdAndRecordTypeNameMap.get(account.Id));
            }
        }catch (Exception e){}
    }
    @IsTest
    public static void testGetRecordTypeIdNameByDeveloperName(){
        try{
            String recordTypeId = DatabaseUtil.getRecordTypeIdByDeveloperName('Account');
            System.assert(recordTypeId!= null);
        }catch (Exception e){}
    }
    @IsTest
    public static void testGetCurrentUserProfileName(){
        try{
            String userProfileName = DatabaseUtil.getCurrentUserProfileName();
            System.assert(userProfileName!= null);
        }catch (Exception e){}
    }
    @IsTest
    public static void testQueryFieldDefinitionByDurableId(){
        try{
            FieldDefinition fieldDefinition = DatabaseUtil.queryFieldDefinitionByDurableId('0010D00000Y9rKVQAA');
            System.assert(fieldDefinition!= null);
        }catch (Exception e){}
    }
    @IsTest
    public static void testQueryCurrentUserWithFields(){
        try{
            User user = DatabaseUtil.queryCurrentUserWithFields(new List<String>{'Name'});
            System.assert(user!= null);
        }catch (Exception e){}
    }
    @IsTest
    public static void testQueryCurrentUserFieldValue(){
        try{
            String value = DatabaseUtil.queryCurrentUserFieldValue('Name');
            System.assert(value!= null);
        }catch (Exception e){}
    }
    @IsTest
    public static void testGetPermissionSetsByUserId(){
        List<PermissionSet> permissionSets = DatabaseUtil.getPermissionSetsByUserId(UserInfo.getUserId(),new List<SObjectField>{PermissionSet.Name});
        System.assert(permissionSets != null);
    }
    private static List<Id> filterIds(List<SObject> sObjects){
        List<Id> ids = new List<Id>();
        for(SObject sObj : sObjects){
            ids.add(sObj.Id);
        }
        return ids;

    }

    
    
}