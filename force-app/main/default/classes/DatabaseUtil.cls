public with sharing class DatabaseUtil {

    public static List<SObject> querySObjectsByIds(List<Id> recordIds){
        List<SObject> sObjects = new List<SObject>();
        Set<String> types = getTypesForRecordIds(recordIds);
        for(String type : types){
            sObjects.addAll(querySObjectsByIds(recordIds, type, getAllFieldNamesForSObjectType(type,true)));
        }
        return sObjects;
    }
    public static String convertFieldsToString(Set<String> fields){
        String stringFields = '';
        for(String fieldName:fields){
            if(fieldName !=null && !fieldName.isWhitespace()){
                stringFields += fieldName+ ',';
            }
        }
        if(fields.size()>0){
            stringFields = stringFields.substring(0,stringFields.lastIndexOf(','));
        }
        return stringFields;
    }
    public static String convertFieldsToString(List<String> fields){
        return convertFieldsToString(new Set<String>(fields));
    }

    public static String getChildRelationshipName(String parentSobjectName, String childSobjectName) {
        SObjectType parentsObjType = ((SObject) Type.forName(parentSobjectName).newInstance())
                .getSObjectType();
        SObjectType childSObjectType = ((SObject) Type.forName(childSobjectName).newInstance())
                .getSObjectType();
        return getChildRelationshipName(parentsObjType,childSObjectType);
    }

    public static String getChildRelationshipName(SObjectType parentSObjectType, SObjectType childSObjectType) {
        for(Schema.ChildRelationship childRelationShip :parentSObjectType.getDescribe().getChildRelationships()){
            if(childRelationShip.getChildSObject() ==childSObjectType){
                return childRelationShip.getRelationshipName();
            }
        }
        return null;
    }

    public static Map<Id,SObject> querySObjectsByIdsToMap(List<Id> recordIds){
        return convertsObjectListToMap(querySObjectsByIds(recordIds));
    }
    public static Map<Id,SObject> querySObjectsByIdsToMap(List<Id> recordIds, List<String> fieldNames){
        return convertsObjectListToMap(querySObjectsByIds(recordIds,fieldNames));
    }
    public static Map<Id,SObject> querySObjectsByIdsToMap(List<Id> recordIds, List<SObjectField> fields){
        return convertsObjectListToMap(querySObjectsByIds(recordIds,fields));
    }
    public static Map<Id,SObject> convertsObjectListToMap(List<SObject> sObjects){
        Map<Id,SObject> sObjectMap = new Map<Id,SObject>();
        for(Integer i=0, j=sObjects.size(); i < j; i++){
            SObject sobj = sObjects.get(i);
            sObjectMap.put(sobj.Id,sobj);
        }
        return sObjectMap;
    }
    public static List<SObject> querySObjectsByIds(List<Id> recordIds, List<String> fieldNames){
        List<SObject> sObjects = new List<SObject>();
        Set<String> types = getTypesForRecordIds(recordIds);
        for(String type : types){
            sObjects.addAll(querySObjectsByIds(recordIds, type,fieldNames));
        }
        return sObjects;
    }
    public static List<SObject> querySObjectsByIds(List<Id> recordIds, List<SObjectField> fields){
        return querySObjectsByIds(recordIds,convertFieldsToListOfString(fields));
    }

    public static List<SObject> querySObjectsByIds(List<Id> recordIds, String sObjectTypeName, List<String> fieldNames){
        return Database.query('SELECT '+ fieldNamesToString(fieldNames)+ ' FROM '+ sObjectTypeName+' WHERE Id IN : recordIds');
    }
    public static List<SObject> querySObjectsByIds(List<Id> recordIds, String sObjectTypeName, List<SObjectField> fields){
        return querySObjectsByIds(recordIds,sObjectTypeName,convertFieldsToListOfString(fields));
    }

    public static List<SObject> querySObjectsByIds(List<Id> recordIds, String sObjectTypeName){
       return querySObjectsByIds(recordIds,sObjectTypeName, getAllFieldNamesForSObjectType(sObjectTypeName,true));
    }
    public static List<String> getAllFieldNamesForSObjectType(String sObjectTypeName,Boolean includeLargeText){
        return getFieldNamesForSObject(sObjectTypeName,true,true,includeLargeText);
    }
    public static List<String> getStandardFieldNamesForSObjectType(String sObjectType){
        return getFieldNamesForSObject(sObjectType,false,true,true);
    }
    public static List<String> getCustomFieldNamesForSObjectType(String sObjectType,Boolean includeLargeText){
        return getFieldNamesForSObject(sObjectType,true,false,includeLargeText);
    }

    public static List<Schema.SObjectField> getAllFieldsForSObjectType(String sObjectTypeName){
        SObjectType type = Schema.getGlobalDescribe().get(sObjectTypeName);
        Map<String,Schema.SObjectField> sObjectFields = type.getDescribe().fields.getMap();

        return sObjectFields.values();
    }
    public static List<String> getFieldNamesForSObject(String objectType,Boolean isCustom,Boolean isStandard,Boolean includeLargeText){
        List<String> fieldNames = new List<String>();
        List<Schema.SObjectField> sObjectFields = getFieldsForSObject(objectType,isCustom,isStandard,includeLargeText);

        for(Schema.SObjectField field: sObjectFields){
            fieldNames.add(field.getDescribe().getName());
        }
        return fieldNames;
    }
    public static List<SObjectField> getFieldsForSObject(String objectType,Boolean isCustom,Boolean isStandard,Boolean includeLargeText){
        List<Schema.SObjectField> fieldsToReturn = new List<Schema.SObjectField>();
        List<Schema.SObjectField> sObjectFields = getAllFieldsForSObjectType(objectType);

        for(Schema.SObjectField field: sObjectFields){
            if((isCustom && field.getDescribe().isCustom()) || (isStandard && !field.getDescribe().isCustom())){
                if(!includeLargeText && field.getDescribe().getLength() > 255 ){
                    continue;
                }
                fieldsToReturn.add(field);
            }
        }
        return fieldsToReturn;
    }

    public static FieldDefinition queryFieldDefinitionByDurableId(String durableId){
        return [SELECT FIELDS(STANDARD)
                    FROM FieldDefinition
                    WHERE DurableId = :durableId];
    }

    public static User queryCurrentUserWithFields(List<String> fields){
        Id currentUserId = UserInfo.getUserId();
        return Database.query('SELECT '+ fieldNamesToString(fields) + ' FROM User WHERE Id = : currentUserId');
    }

    public static String queryCurrentUserFieldValue(String field){
        User user = queryCurrentUserWithFields(new List<String>{field});
        return String.valueOf(user.get(field));
    }

    public static List<String> getFieldsByLayout(String sObjectType,String layoutName) {
        List<String> fields = new List<String>();
        String queryName = sObjectType+'-'+layoutName;
        List<Metadata.Metadata> layouts =
                Metadata.Operations.retrieve(Metadata.MetadataType.Layout,
                        new List<String>{
                                queryName
                        });
        if(layouts.size() == 0){
            return fields;
        }else{
            Metadata.Layout layoutMd = (Metadata.Layout) layouts.get(0);
            for (Metadata.LayoutSection section : layoutMd.layoutSections) {
                for (Metadata.LayoutColumn column : section.layoutColumns) {
                    if (column.layoutItems != null) {
                        for (Metadata.LayoutItem item : column.layoutItems) {
                            if(item.field!=null){
                                fields.add(item.field);
                            }
                        }
                    }
                }

            }
        }
        return fields;
    }

    public static String getRecordTypeIdBySObjectIdAndType(String sObjectId, String sObjectName){
       List<SObject> sObjects = Database.query('SELECT RecordtypeId FROM ' + sObjectName + ' WHERE Id =: sObjectId');
       return sObjects.size()==0 ? null :  String.valueOf(sObjects.get(0).get('RecordtypeId'));
    }
    public static String getRecordTypeNameByRecordTypeId(String recordTypeId){
        List<RecordType> recordTypes = [SELECT Name FROM RecordType WHERE Id = :recordTypeId];
        return recordTypes.size()==0 ? null :  String.valueOf(recordTypes.get(0).Name);
    }
    public static String getRecordTypeNameBySObjectIdAndType(String sObjectId, String sObjectName){
       String recordId = getRecordTypeIdBySObjectIdAndType(sObjectId,sObjectName);
        return getRecordTypeNameByRecordTypeId(recordId);
    }
    public static String getRecordTypeIdByDeveloperName(String name){
        RecordType recordType = [SELECT Id FROM RecordType WHERE DeveloperName =:name];
        return recordType.Id;
    }
    public static Map<Id,String> getRecordTypeDeveloperNameBysObjectIds(List<Id> sObjectIds, String type){
        Map<Id,String> sObjectIdAndRecordTypeNameMap = new Map<Id,String>();
        if(sObjectIds!=null && sObjectIds.size()>0){
            Map<Id,Id> sObjectIdAndRecordTypeIdMap = getRecordTypeIdBysObjectIds(sObjectIds,type);
            for(Id sobjId:sObjectIds){
                Id recordTypeId = sObjectIdAndRecordTypeIdMap.get(sobjId);
                sObjectIdAndRecordTypeNameMap.put(sobjId,Schema.getGlobalDescribe().get(type)
                        .getDescribe().getRecordTypeInfosById().get(recordTypeId).getDeveloperName());
            }
        }
        return sObjectIdAndRecordTypeNameMap;
    }
    public static Map<Id,Id> getRecordTypeIdBysObjectIds(List<Id> sObjectIds, String type){
        Map<Id,Id> sObjectIdAndRecordTypeIdMap = new Map<Id,Id>();
        if(sObjectIds!=null && sObjectIds.size()>0){
            List<SObject> sObjectsWithRecordTypeId = new SOQLQueryBuilder(type)
                    .selectSpecificFields(new List<String>{'RecordtypeId','Id'})
                    .whereClause('Id')
                    .inside(sObjectIds)
                    .getResultList();
            for(SObject sobj:sObjectsWithRecordTypeId){
                Id recordTypeId = (Id) sobj.get('RecordtypeId');
                sObjectIdAndRecordTypeIdMap.put(sobj.Id,recordTypeId);
            }
        }
        return sObjectIdAndRecordTypeIdMap;
    }
    public static List<Id> getIdsFromSObjects(List<SObject> sObjects){
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

    public static String getCurrentUserProfileName(){
        String userProfileName = [SELECT Name FROM Profile WHERE Id =: UserInfo.getProfileId()].Name;
        return userProfileName;
    }
    private static List<String> convertFieldsToListOfString(List<SObjectField> fields){
        List<String> fieldsList = new List<String>();
        for(Integer i=0, j=fields.size(); i < j; i++){
            fieldsList.add(fields.get(i).getDescribe().getName());
        }
        return fieldsList;
    }
    private static String fieldNamesToString(List<String> fieldNames){
        String stringFields = '';
        for(Integer i=0, j=fieldNames.size(); i < j; i++){
            stringFields += fieldNames.get(i)+ ',';
        }
        if(fieldNames.size()>0){
            stringFields = stringFields.substring(0,stringFields.lastIndexOf(','));
        }
        return stringFields;
    }
    private static Set<String> getTypesForRecordIds(List<Id> recordIds){
        Set<String> types = new Set<String>();
        for(Integer i=0, j=recordIds.size(); i < j; i++){
            types.add(recordIds.get(i).getSobjectType().getDescribe().getName());
        }
        return types;
    }

    public static List<PermissionSet> getPermissionSetsByUserId(Id userId, List<SObjectField> permissionSetFields){
        Set<String> permissionSetStringFields = new Set<String>();
        List<PermissionSet> permissionSets = new List<PermissionSet>();

        for(Integer i = 0; i<permissionSetFields.size();i++){
            String permissionSetFieldName = permissionSetFields.get(i).getDescribe().getName();
            permissionSetFieldName = 'PermissionSet.'+permissionSetFieldName;
            permissionSetStringFields.add(permissionSetFieldName);
        }

        List<PermissionSetAssignment> permissionSetAssignments = Database.query('SELECT Assignee.Id, Id, '+
                fieldNamesToString(new List<String>(permissionSetStringFields)) +
                ' FROM PermissionSetAssignment WHERE Assignee.Id =: userId');

        for(PermissionSetAssignment permissionSetAssignment: permissionSetAssignments){
            permissionSets.add(permissionSetAssignment.PermissionSet);
        }
        return permissionSets;
    }

}