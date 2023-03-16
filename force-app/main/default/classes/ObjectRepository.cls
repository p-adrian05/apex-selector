
public interface ObjectRepository {
    /**
      * Finds a single object by Id with all fields
      * @param objectId the Id of the object to find
      * @return an Optional object containing the found object or null if no object was found
     */
    Optional findById(Id objectId);
    /**
      * Finds multiple objects by Ids with all fields
      * @param objectIds a List of Ids of the objects to find
      * @return a Map of object Ids and corresponding found object records
    */
    Map<Id,SObject> findAllById(List<Id> objectIds);
    /**
       * Finds multiple objects by Ids with specified fields
       * @param objectIds a List of Ids of the objects to find
       * @param fields a List of SObjectFields to include in the results
       * @return a Map of object Ids and corresponding found object records with specified fields
  */
    Map<Id,SObject> findAllById(List<Id> objectIds,List<SObjectField> fields);
    /**
     * Finds a single object by Id with specified fields
     * @param objectId the Id of the object to find
     * @param fields a List of SObjectFields to include in the result
     * @return an Optional object containing the found object or null if no object was found
    */
    Optional findById(Id objectId,List<SObjectField> fields);
    /**
     * Finds multiple objects by name with all fields
     * @param name the name of the object(s) to find
     * @return a Map of object Ids and corresponding found object records
    */
    Map<Id,SObject> findByName(String name);
    /**
     * Finds multiple objects by name with specified fields
     * @param name the name of the object(s) to find
     * @param fields a List of SObjectFields to include in the result
     * @return a Map of object Ids and corresponding found object records with specified fields
    */
    Map<Id,SObject> findByName(String name,List<SObjectField> fields);
}