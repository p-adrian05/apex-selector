
public interface ObjectSelector {

    SObjectType getSObjectType();

    SObject selectById(Id objectId);

    List<SObject> selectByIds(List<Id> objectIds);
}