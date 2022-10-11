public virtual class ObjectRepository {

    private final String sObjectTypeName;

    public ObjectRepository(String sObjectTypeName){
        this.sObjectTypeName = sObjectTypeName;
    }

    public virtual Optional findById(Id objectId){
        return findById(new SOQLQueryBuilder(this.sObjectTypeName)
                .selectAllFields(true),objectId);
    }
    public virtual List<SObject> findAllById(List<Id> objectIds){
        return findAllById(new SOQLQueryBuilder(this.sObjectTypeName)
                .selectAllFields(true),objectIds);
    }
    public virtual List<SObject> findAllById(List<Id> objectIds,List<SObjectField> fields){
        return findAllById(new SOQLQueryBuilder(this.sObjectTypeName)
                .selectSpecificFields(fields),objectIds);
    }
    public virtual Optional findById(Id objectId,List<SObjectField> fields){
        return findById(new SOQLQueryBuilder(this.sObjectTypeName)
                .selectSpecificFields(fields),objectId);
    }
    public virtual List<SObject> findByName(String name){
        return findByName(new SOQLQueryBuilder(this.sObjectTypeName)
                .selectAllFields(true),name);
    }
    public virtual List<SObject> findByName(String name,List<SObjectField> fields){
        return findByName(new SOQLQueryBuilder(this.sObjectTypeName)
                .selectSpecificFields(fields),name);
    }

    protected Optional findById(SOQLQueryBuilder queryBuilder,Id objectId){
        return Optional.ofNullable(queryBuilder.whereClause('Id').equals(objectId).getSingleResult());
    }
    protected List<SObject> findAllById(SOQLQueryBuilder queryBuilder,List<Id> objectIds){
        return queryBuilder.whereClause('Id').inside(objectIds).getResultList();
    }
    protected List<SObject> findByName(SOQLQueryBuilder queryBuilder,String name){
        return queryBuilder.whereClause('Name').equals(name).getResultList();
    }


}