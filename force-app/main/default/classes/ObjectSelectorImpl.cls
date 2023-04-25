
public abstract with sharing class ObjectSelectorImpl implements ObjectSelector{

    public abstract SObjectType getSObjectType();

    public abstract List<SObjectField> getSObjectFieldList();
    public virtual SObject selectById(Id objectId) {
        return new SOQLQueryBuilder(getSObjectType())
                .selectSpecificFields(getSObjectFieldList())
                .whereClause('Id').equals(objectId)
                .getSingleResult();
    }

    public virtual List<SObject> selectByIds(List<Id> objectIds) {
        return new SOQLQueryBuilder(getSObjectType())
                .selectSpecificFields(getSObjectFieldList())
                .whereClause('Id').inside(objectIds)
                .getResultList();
    }
}