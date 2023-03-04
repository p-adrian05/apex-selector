
public interface ObjectRepository {

    Optional findById(Id objectId);
    Map<Id,SObject> findAllById(List<Id> objectIds);
    Map<Id,SObject> findAllById(List<Id> objectIds,List<SObjectField> fields);
    Optional findById(Id objectId,List<SObjectField> fields);
    Map<Id,SObject> findByName(String name);
    Map<Id,SObject> findByName(String name,List<SObjectField> fields);
}