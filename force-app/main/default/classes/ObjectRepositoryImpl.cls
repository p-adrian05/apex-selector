public virtual class ObjectRepositoryImpl implements ObjectRepository{

    private final String sObjectTypeName;

    public ObjectRepositoryImpl(String sObjectTypeName){
        this.sObjectTypeName = sObjectTypeName;
    }
    public ObjectRepositoryImpl(SObjectType sObjectType){
        this.sObjectTypeName = sObjectType.getDescribe().getName();
    }
    public Optional findById(Id objectId){
        return findById(new SOQLQueryBuilder(this.sObjectTypeName)
                .selectAllFields(true),objectId);
    }
    public Map<Id,SObject> findAllById(List<Id> objectIds){
        return findAllById(new SOQLQueryBuilder(this.sObjectTypeName)
                .selectAllFields(true),objectIds);
    }
    public Map<Id,SObject> findAllById(List<Id> objectIds,List<SObjectField> fields){
        return findAllById(new SOQLQueryBuilder(this.sObjectTypeName)
                .selectSpecificFields(fields),objectIds);
    }
    public Optional findById(Id objectId,List<SObjectField> fields){
        return findById(new SOQLQueryBuilder(this.sObjectTypeName)
                .selectSpecificFields(fields),objectId);
    }
    public Map<Id,SObject> findByName(String name){
        return findByName(new SOQLQueryBuilder(this.sObjectTypeName)
                .selectAllFields(true),name);
    }
    public Map<Id,SObject> findByName(String name,List<SObjectField> fields){
        return findByName(new SOQLQueryBuilder(this.sObjectTypeName)
                .selectSpecificFields(fields),name);
    }
    private Optional findById(SOQLQueryBuilder queryBuilder,Id objectId){
        return Optional.ofNullable(queryBuilder.whereClause('Id').equals(objectId).getSingleResult());
    }
    private Map<Id,SObject> findAllById(SOQLQueryBuilder queryBuilder,List<Id> objectIds){
        return queryBuilder.whereClause('Id').inside(objectIds).getResultMap();
    }
    private Map<Id,SObject> findByName(SOQLQueryBuilder queryBuilder,String name){
        return queryBuilder.whereClause('Name').equals(name).getResultMap();
    }
}