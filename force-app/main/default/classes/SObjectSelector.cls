
public interface SObjectSelector {

    SObjectType getSObjectType();

    SObject selectById(Id objectId);

    List<SObject> selectByIds(List<Id> objectIds);
}