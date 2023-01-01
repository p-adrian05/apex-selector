public virtual class ObjectRepository {

    private final String sObjectTypeName;

    public ObjectRepository(String sObjectTypeName){
        this.sObjectTypeName = sObjectTypeName;
    }
    public ObjectRepository(SObjectType sObjectType){
        this.sObjectTypeName = sObjectType.getDescribe().getName();
    }
    public virtual Optional findById(Id objectId){
        return findById(new SOQLQueryBuilder(this.sObjectTypeName)
                .selectAllFields(true),objectId);
    }
    public virtual Map<Id,SObject> findAllById(List<Id> objectIds){
        return findAllById(new SOQLQueryBuilder(this.sObjectTypeName)
                .selectAllFields(true),objectIds);
    }
    public virtual Map<Id,SObject> findAllById(List<Id> objectIds,List<SObjectField> fields){
        return findAllById(new SOQLQueryBuilder(this.sObjectTypeName)
                .selectSpecificFields(fields),objectIds);
    }
    public virtual Optional findById(Id objectId,List<SObjectField> fields){
        return findById(new SOQLQueryBuilder(this.sObjectTypeName)
                .selectSpecificFields(fields),objectId);
    }
    public virtual Map<Id,SObject> findByName(String name){
        return findByName(new SOQLQueryBuilder(this.sObjectTypeName)
                .selectAllFields(true),name);
    }
    public virtual Map<Id,SObject> findByName(String name,List<SObjectField> fields){
        return findByName(new SOQLQueryBuilder(this.sObjectTypeName)
                .selectSpecificFields(fields),name);
    }
    protected Optional findById(SOQLQueryBuilder queryBuilder,Id objectId){
        return Optional.ofNullable(queryBuilder.whereClause('Id').equals(objectId).getSingleResult());
    }
    protected Map<Id,SObject> findAllById(SOQLQueryBuilder queryBuilder,List<Id> objectIds){
        return queryBuilder.whereClause('Id').inside(objectIds).getResultMap();
    }
    protected Map<Id,SObject> findByName(SOQLQueryBuilder queryBuilder,String name){
        return queryBuilder.whereClause('Name').equals(name).getResultMap();
    }


}