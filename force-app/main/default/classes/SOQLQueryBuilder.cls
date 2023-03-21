
/**
 *  SOQLQueryBuilder is a utility class to build SOQL queries in dynamic way.
 *
*/
public with sharing class SOQLQueryBuilder {

    private final static String OP_AND = 'AND';
    private final static String OP_OR = 'OR';
    private final static String OP_IN = 'IN';
    private final static String OP_INCLUDES = 'INCLUDES';
    private final static String OP_NOT_IN = 'NOT IN';
    private final static String OP_EXCLUDES = 'EXCLUDES';

    private final static String OP_LESS = '<';
    private final static String OP_LESS_EQUALS = '<=';
    private final static String OP_GREATER = '>';
    private final static String OP_GREATER_EQUALS = '>=';
    private final static String OP_EQUALS = '=';
    private final static String OP_NOT_EQUALS = '!=';
    private final static String OP_LIKE = 'LIKE';
    private final static String OP_NOT_LIKE = 'NOT LIKE';

    private final static String OPEN_BRACKET = '(';
    private final static String CLOSE_BRACKET = ')';

    private final static String LIMIT_STR = 'LIMIT';
    private final static String WHERE_STR = 'WHERE';
    private final static String HAVING_STR = 'HAVING';
    private final static String GROUP_BY_STR = 'GROUP BY';
    private final static String ORDER_BY_STR = 'ORDER BY';
    private final static String SELECT_STR = 'SELECT';
    private final static String FROM_STR = 'FROM';
    private final static String WITH_STR = 'WITH';
    private final static String USING_SCOPE_STR = 'USING SCOPE';
    private final static String ASC_STR = 'ASC';
    private final static String DESC_STR = 'DESC';
    private final static String NULLS_LAST_STR = 'NULLS LAST';
    private final static String NULLS_FIRST_STR = 'NULLS FIRST';
    private final static String OFFSET_STR = 'OFFSET';
    private final static String FOR_VIEW_STR = 'FOR VIEW';
    private final static String FOR_UPDATE_STR = 'FOR UPDATE';
    private final static String SECURITY_ENFORCED_STR = 'SECURITY_ENFORCED';
    private final static String FOR_REFERENCE_STR = 'FOR REFERENCE';
    private final static String UPDATE_TRACKING_STR = 'UPDATE TRACKING';
    private final static String UPDATE_VIEWSTAT_STR = 'UPDATE VIEWSTAT';
    private final static String ALL_ROWS_STR = 'ALL ROWS';

    private final static String DEFAULT_FIELD = 'Id';

    private SObjectType currentSObjectType;
    //Maps to store the FieldNameId and the operator to be used in the query
    private Map<FieldNameId,String> fieldNameIdOperatorMap;
    //Maps to store the FieldNameId and the logical operator to be used in the query
    private Map<FieldNameId,String> fieldNameIdLogicalOperatorMap;
    //Maps to store the FieldNameId and the open bracket to be used in the query
    private Map<FieldNameId,String> fieldNameIdOpenBracketMap;
    //Maps to store the FieldNameId and the close bracket to be used in the query
    private Map<FieldNameId,String> fieldNameIdCloseBracketMap;
    //Maps to store the FieldNameId and the value to be used in the query for where clause
    private Map<FieldNameId,Object> fieldNameIdValueMap;
    //Maps to store the field name and the order to be used in the query
    private Map<String,String> orderByFieldNameOrderMap;
    //Maps to store the field name and the nulls first/last to be used in the query
    private Map<String,String> orderByFieldNameNullsFirstLastMap;

    //Set to store the fields to be selected in the query
    private Set<String> fields;
    //Set to store the fields to be grouped in the query
    private Set<String> groupByFields;
    //List to store the related child queries
    private List<SOQLQueryBuilder> innerQueries;
    //List to store the parent queries
    private List<SOQLQueryBuilder> parentQueries;
    //Name of the parent relationship for the parent fields query
    private String parentRelationshipName;
    //Name of the child relationship for the child query
    private String childRelationshipName;

    private String withStatement;
    private String usingScopeStatement;
    private Integer limitNumber;
    private Integer offsetNumber;
    private Boolean forUpdate = false;
    private Boolean forView = false;
    private Boolean forReference = false;
    private Boolean updateTracking = false;
    private Boolean updateViewStat = false;
    private Boolean allRows = false;

    private Boolean isWhereStatement = true;
    private FieldNameId lastWhereFieldNameId;
    private String lastOrderByFieldName;
    private Integer whereFieldNameCounter = 0;
    private Integer bindValueIndex = 0;

    public SOQLQueryBuilder(SObjectType sObjectType){
        requireNonNull(sObjectType, 'SObject type cannot be null!');
        init(sObjectType);
    }
    public SOQLQueryBuilder(String sObjectTypeName){
        requireNonNull(sObjectTypeName, 'SObject type name cannot be null!');
        try{
            SObjectType currentSObjectType = ((SObject) Type.forName(sObjectTypeName).newInstance())
                    .getSObjectType();
            init(currentSObjectType);
        }catch (Exception e){
            throw new SObjectException('Invalid SObject type: ' + sObjectTypeName);
        }

    }
    private void init(SObjectType currentSObjectType){
        this.currentSObjectType = currentSObjectType;
        this.fieldNameIdValueMap = new Map<FieldNameId,Object>();
        this.fieldNameIdOperatorMap = new Map<FieldNameId,String>();
        this.fieldNameIdLogicalOperatorMap = new Map<FieldNameId,String>();
        this.fieldNameIdOpenBracketMap = new Map<FieldNameId,String>();
        this.fieldNameIdCloseBracketMap = new Map<FieldNameId,String>();
        this.orderByFieldNameOrderMap = new Map<String,String>();
        this.orderByFieldNameNullsFirstLastMap = new Map<String,String>();
        this.fields = new Set<String>{};
        this.groupByFields = new Set<String>{};
        this.innerQueries = new List<SOQLQueryBuilder>();
        this.parentQueries = new List<SOQLQueryBuilder>();
    }
    /**
        * Adds an inner query to the SOQL query to select related records.
        * @example
        * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
              .selectSpecificFields(new List<SObjectField>{Account.Name})
                .addInnerQuery(new SOQLQueryBuilder(Contact.getSObjectType())
                        .selectSpecificFields(new List<SObjectField>{Contact.Name}));

        String expectedQueryString = 'SELECT Name,(SELECT Name FROM Contacts ) FROM Account';
        *
        * @param databaseQuery the inner query to be added.
        * @return SOQLQueryBuilder the current instance of the builder.
    */
    public SOQLQueryBuilder addInnerQuery(SOQLQueryBuilder databaseQuery){
        requireNonNull(databaseQuery, 'Inner query cannot be null!');
        this.innerQueries.add(databaseQuery);
        return this;
    }
    /**
      * Adds a parent query to the SOQL query builder to select related parent fields.
      * @example
      *   SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Contact.getSObjectType())
              .selectSpecificFields(new List<SObjectField>{Contact.LastName})
                .addParentQuery(new SOQLQueryBuilder(Account.getSObjectType())
                   .selectSpecificFields(new List<SObjectField>{Account.Name}));

        String expectedQueryString = 'SELECT LastName,Account.Name FROM Contact;

      * @param parentQuery the parent query to be added.
      * @return SOQLQueryBuilder the current instance of the builder.
   */
    public SOQLQueryBuilder addParentQuery(SOQLQueryBuilder parentQuery){
        requireNonNull(parentQuery, 'Parent query cannot be null');
        this.parentQueries.add(parentQuery);
        return this;
    }

    /**
    * Sets the parent relationship name to be used in the SOQL query when adding a parent query and the
     * relationship name is not the same as the parent SObject type name.
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Contact.getSObjectType())
              .selectSpecificFields(new List<SObjectField>{Contact.LastName})
                 .addParentQuery(new SOQLQueryBuilder(Contact.getSObjectType())
                         .selectSpecificFields(new List<SObjectField>{Contact.Name})
                         .setParentLookupFieldName('ReportsTo'));

        String expectedQueryString = 'SELECT LastName,ReportsTo.Name FROM Contact;
    *
    * @param parentRelationshipName the parent relationship name to be used in the SOQL query.
    * @return SOQLQueryBuilder the current instance of the builder.
    */
    public SOQLQueryBuilder setParentRelationshipName(String parentRelationshipName){
        requireNonNull(parentRelationshipName, 'Parent relationship name cannot be null!');
        this.parentRelationshipName = parentRelationshipName;
        return this;
    }
    /**
   * Sets the child relationship name to be used in the SOQL query when adding a related child query.
    * Have to use if multiple child relationships exist between the parent and child SObject types otherwise not required.
    * @example
    * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
              .selectSpecificFields(new List<SObjectField>{Account.Name})
                .addInnerQuery(new SOQLQueryBuilder(Contact.getSObjectType())
                        .selectSpecificFields(new List<SObjectField>{Contact.Name})
                        .setChildRelationshipName('Contacts'));

        String expectedQueryString = 'SELECT Name,(SELECT Name FROM Contacts ) FROM Account';
   *
   * @param childRelationshipName the child relationship name to be used in the SOQL query.
   * @return SOQLQueryBuilder the current instance of the builder.
   */
    public SOQLQueryBuilder setChildRelationshipName(String childRelationshipName){
        requireNonNull(childRelationshipName, 'Child relationship name cannot be null!');
        this.childRelationshipName = childRelationshipName;
        return this;
    }
    /**
    * Adds a SOQL function to the query builder.
    * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .addFunction(SOQLFunction.of(SOQLFunction.FunctionName.COUNT));

       String expectedQueryString = 'SELECT COUNT() FROM Account';
     *
    * @param soqlFunction the SOQL Function to be added.
    * @return SOQLQueryBuilder the current instance of the builder.
 */
    public SOQLQueryBuilder addFunction(SOQLFunction soqlFunction){
        requireNonNull(soqlFunction, 'SOQL Function cannot be null!');
        this.fields.add(soqlFunction.toString());
        return this;
    }
    /**
    * Selects all custom fields for the SObject type in the query builder.
    *
    * @param includeLargeText whether to include fields with character length greater than 255.
    * @return SOQLQueryBuilder the current instance of the builder.
   */
    public SOQLQueryBuilder selectCustomFields(Boolean includeLargeText){
        requireNonNull(includeLargeText, 'Include large text cannot be null!');
        this.fields.addAll(getCustomFieldNamesForSObjectType(this.currentSObjectType,includeLargeText));
        this.fields.add(DEFAULT_FIELD);
        return this;
    }
    /**
    * Selects all fields for the SObject type in the query builder.
    *
    * @param includeLargeText whether to include fields with character length greater than 255.
    * @return SOQLQueryBuilder the current instance of the builder.
    */
    public SOQLQueryBuilder selectAllFields(Boolean includeLargeText){
        requireNonNull(includeLargeText, 'Include large text cannot be null!');
        this.fields.addAll(getAllFieldNamesForSObjectType(this.currentSObjectType,includeLargeText));
        return this;
    }
    /**
    * Selects all standard fields for the SObject type in the query builder.
    *
    * @return SOQLQueryBuilder the current instance of the builder.
    */
    public SOQLQueryBuilder selectStandardFields(){
        this.fields.addAll(getStandardFieldNamesForSObjectType(this.currentSObjectType));
        return this;
    }
    /**
    * Selects specific fields for the SObject type in the query builder.
    *
    * @param fields the list of SObjectFields to be selected.
    * @return SOQLQueryBuilder the current instance of the builder.
    */
    public SOQLQueryBuilder selectSpecificFields(List<SObjectField> fields){
        List<String> fieldsString = new List<String>();
        if(fields!=null){
            for(SObjectField field: fields){
                validateFieldType(field, this.currentSObjectType, ' in selectSpecificFields method!');
                fieldsString.add(field.getDescribe().getName());
            }
        }
        return selectSpecificFields(fieldsString);
    }
    /**
    * Selects specific fields for the SObject type in the query builder.
    *
    * @param fields the list of field names to be selected.
    * @return SOQLQueryBuilder the current instance of the builder.
    */
    public SOQLQueryBuilder selectSpecificFields(List<String> fields){
        if(fields!=null){
            this.fields.addAll(fields);
        }
        return this;
    }
    /**
     * Adds LIMIT keyword to the SOQL query.
     *
     * @example
     *    SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name,Account.NumberOfEmployees})
                .addLimit(100);

       String expectedQueryString = 'SELECT Name,NumberOfEmployees FROM Account LIMIT 100';
     *
     * @param limitNumber the number of records to limit the query to
     * @return The SOQLQueryBuilder instance with a LIMIT number set
 */
    public SOQLQueryBuilder addLimit(Integer limitNumber){
        requireNonNull(limitNumber, 'Limit number cannot be null!');
        this.limitNumber = limitNumber;
        return this;
    }
    /**
     * Adds OFFSET keyword to the SOQL query.
     * @example
     *       SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name,Account.NumberOfEmployees})
                .addOffset(10);

       String expectedQueryString = 'SELECT Name,NumberOfEmployees FROM Account OFFSET 10';

     * @param offsetNumber the number of records to offset the query by
     * @return The SOQLQueryBuilder instance with an OFFSET number set
    */
    public SOQLQueryBuilder addOffset(Integer offsetNumber){
        requireNonNull(offsetNumber, 'Offset number cannot be null!');
        this.offsetNumber = offsetNumber;
        return this;
    }
    /**
     * Adds FOR UPDATE keyword to the SOQL query.
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType()).forUpdate();
     *  String expectedQueryString = 'SELECT Id FROM Account FOR UPDATE';
     *
     * @return The SOQLQueryBuilder instance with FOR UPDATE keyword added
    */
    public SOQLQueryBuilder forUpdate(){
        this.forUpdate = true;
        return this;
    }
    /**
     * Adds FOR VIEW keyword to the SOQL query.
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType()).forView();
     *
        String expectedQueryString = 'SELECT Id FROM Account FOR VIEW';

     * @return The SOQLQueryBuilder instance with FOR VIEW keyword added
    */
    public SOQLQueryBuilder forView(){
        this.forView = true;
        return this;
    }
    /**
     * Adds FOR REFERENCE keyword to the SOQL query.
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType()).forReference();
     *
       String expectedQueryString = 'SELECT Id FROM Account FOR REFERENCE';
     *
     *
     * @return The SOQLQueryBuilder instance with FOR REFERENCE keyword added
    */
    public SOQLQueryBuilder forReference(){
        this.forReference = true;
        return this;
    }
    /**
     * Adds UPDATE VIEW STAT keyword to the SOQL query.
     *
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType()).updateViewStat();

        String expectedQueryString = 'SELECT Id FROM Account UPDATE VIEWSTAT';
     *
     * @return The SOQLQueryBuilder instance with UPDATE VIEW STAT keyword added
    */
    public SOQLQueryBuilder updateViewStat(){
        this.updateViewStat = true;
        return this;
    }
    /**
     * Adds UPDATE TRACKING keyword to the SOQL query.
     *
     * @example
     *  SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType()).updateTracking();
        String expectedQueryString = 'SELECT Id FROM Account UPDATE TRACKING';

     * @return The SOQLQueryBuilder instance with UPDATE TRACKING keyword  added
    */
    public SOQLQueryBuilder updateTracking(){
        this.updateTracking = true;
        return this;
    }
    /**
     * Adds ALL ROWS keyword to the SOQL query.
     *
     * @example
     *  SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType()).allRows();
        String expectedQueryString = 'SELECT Id FROM Account ALL ROWS';
     *
     * @return The SOQLQueryBuilder instance with ALL ROWS keyword added
 */
    public SOQLQueryBuilder allRows(){
        this.allRows = true;
        return this;
    }
    /**
     * Adds WITH statement to the SOQL query.
     *
     * @example
     * SOQLQueryBuilder soqlQueryBuilder =  new SOQLQueryBuilder(Account.getSObjectType())
                .with('DATA CATEGORY Geography__c');
        String expectedQueryString = 'SELECT Id FROM Account WITH DATA CATEGORY Geography__c';
     *
     * @param withStatement the WITH statement to add to the query
     * @return The SOQLQueryBuilder instance with the WITH statement added
    */
    public SOQLQueryBuilder with(String withStatement){
        requireNonNull(withStatement, 'With statement cannot be null!');
        if(this.withStatement == null){
            this.withStatement = withStatement;
        }else{
            this.withStatement += ' '+withStatement;
        }
        return this;
    }
    /**
     * Adds SECURITY_ENFORCED keyword to the SOQL query.
     *
     * @example
     *   SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .withSecurityEnforced();

        String expectedQueryString = 'SELECT Id FROM Account WITH SECURITY_ENFORCED';
     *
     * @return The SOQLQueryBuilder instance with SECURITY_ENFORCED keyword added
    */
    public SOQLQueryBuilder withSecurityEnforced(){
        if(this.withStatement == null){
            this.withStatement = SECURITY_ENFORCED_STR;
        }else{
            this.withStatement += ' '+SECURITY_ENFORCED_STR;
        }
        return this;
    }
    /**
     * Sets the USING SCOPE keyword with specified FilterScope to use for the SOQL query.
     *
     * @example
     *   SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .usingScope(FilterScope.mine);

        String expectedQueryString = 'SELECT Id FROM Account USING SCOPE mine';
     *
     * @param filterScope the filter scope to use
     * @return the SOQL query builder with the USING SCOPE statement
   */
    public SOQLQueryBuilder usingScope(FilterScope filterScope){
        requireNonNull(filterScope, 'Filter scope cannot be null!');
        this.usingScopeStatement = filterScope.name();
        return this;
    }
    /**
     * Sets the SObjectField field to group by in the SOQL query.
     * @example
     *       SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.City,Lead.CreatedDate})
                .groupBy(Lead.City);

        String expectedQueryString = 'SELECT City,CreatedDate FROM Lead
                'GROUP BY City;
     *
     * @param field the SObjectField field to group by
     * @return the SOQL query builder with the group by statement
    */
    public SOQLQueryBuilder groupBy(SObjectField field){
        requireNonNull(field, 'Field cannot be null in groupBy!');
        validateFieldType(field, this.currentSObjectType, ' in groupBy method!');
        return groupBy(field.getDescribe().getName());
    }
    /**
     * Sets the String field to group by in the SOQL query.
     * @example
     *      SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
            .selectSpecificFields(new List<SObjectField>{Lead.City,Lead.CreatedDate})
            .groupBy('City');

        String expectedQueryString = 'SELECT City,CreatedDate FROM Lead
                'GROUP BY City;
     *
     * @param fieldName the String name of the field to group by
     * @return the SOQL query builder with  group by statement
    */
    public SOQLQueryBuilder groupBy(String fieldName){
        requireNonNull(fieldName, 'Field name cannot be null!');
        this.groupByFields.add(fieldName);
        return this;
    }

    /**
     * Sets the SOQL function to group by in the SOQL query.
     * @example
     *   SOQLFunction hourInDayFunction = SOQLFunction.of(SOQLFunction.FunctionName.HOUR_IN_DAY,
                convertTimeZoneFunction);
     *  SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Opportunity.getSObjectType())
                .addFunction(hourInDayFunction)
                .groupBy(hourInDayFunction);

        String expectedQueryString = 'SELECT HOUR_IN_DAY(convertTimezone(CreatedDate)) FROM Opportunity ' +
                'GROUP BY HOUR_IN_DAY(convertTimezone(CreatedDate))';
     *
     * @param soqlFunction the SOQL function to group by
     * @return the SOQL query builder instance with group by statement
     */
    public SOQLQueryBuilder groupBy(SOQLFunction soqlFunction){
        requireNonNull(soqlFunction, 'SOQL function cannot be null in GROUP BY statement!');
        this.groupByFields.add(soqlFunction.toString());
        return this;
    }
    /**
     * Sets the SObjectField field to order by in the SOQL query in default ascending order.
     * @example
     *  SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name,Account.NumberOfEmployees})
                .orderBy(Account.NumberOfEmployees);

        String expectedQueryString = 'SELECT Name,NumberOfEmployees FROM Account
                'ORDER BY Name ASC';

     * @param field the field to order by
     * @return the SOQL query builder with the order by statement
 */
    public SOQLQueryBuilder orderBy(SObjectField field){
        requireNonNull(field, 'Order By Field cannot be null!');
        validateFieldType(field, this.currentSObjectType, ' in orderBy method!');
        return orderBy(field.getDescribe().getName());
    }
    /**
      * Sets the String field to order by in the SOQL query in default ascending order.
      *  @example
      *  SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name,Account.NumberOfEmployees})
                .orderBy('NumberOfEmployees');

        String expectedQueryString = 'SELECT Name,NumberOfEmployees FROM Account
                'ORDER BY Name ASC';

     * @param fieldName the API name of the field to order by
     * @return the SOQL query builder with the order by statement
     */
    public SOQLQueryBuilder orderBy(String fieldName){
        requireNonNull(fieldName, 'Order By Field name cannot be null!');
        this.orderByFieldNameOrderMap.put(fieldName,ASC_STR);
        this.lastOrderByFieldName = fieldName;
        return this;
    }
    /**
     * Sets the order of order by statement in the SOQL query to ascending order.
     * @example
     *  SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name,Account.NumberOfEmployees})
                .orderBy(Account.Name).ascending();

        String expectedQueryString = 'SELECT Name,NumberOfEmployees FROM Account
                'ORDER BY Name ASC';

     *
     * @return the SOQL query builder with the order by statement with ascending order
   */
    public SOQLQueryBuilder ascending(){
        this.orderByFieldNameOrderMap.put(this.lastOrderByFieldName,ASC_STR);
        return this;
    }
    /**
   * Sets the order of order by statement in the SOQL query to descending order.
   * @example
   *  SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
              .selectSpecificFields(new List<SObjectField>{Account.Name,Account.NumberOfEmployees})
              .orderBy(Account.Name).descending();

      String expectedQueryString = 'SELECT Name,NumberOfEmployees FROM Account
              'ORDER BY Name DESC';

   * @return the SOQL query builder with the order by statement with descending order
 */
    public SOQLQueryBuilder descending(){
        this.orderByFieldNameOrderMap.put(this.lastOrderByFieldName,DESC_STR);
        return this;
    }
    /**
   * Sets NULLS LAST keyword after the order by statement in the SOQL query..
   *@example
   SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name,Account.NumberOfEmployees})
                .orderBy(Account.Name).ascending().nullsLast()

        String expectedQueryString = 'SELECT Name,NumberOfEmployees FROM Account
                'ORDER BY Name ASC NULLS LAST'

   * @return the SOQL query builder the order by statement with NULLS LAST keyword
  */
    public SOQLQueryBuilder nullsLast(){
        this.orderByFieldNameNullsFirstLastMap.put(this.lastOrderByFieldName,NULLS_LAST_STR);
        return this;
    }
    /**
    * Sets NULLS FIRST keyword after the order by statement in the SOQL query..
    *
     * @example
    SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name,Account.NumberOfEmployees})
                .orderBy(Account.Name).ascending().nullsFirst()

        String expectedQueryString = 'SELECT Name,NumberOfEmployees FROM Account
                'ORDER BY Name ASC NULLS FIRST'

    * @return the SOQL query builder the order by statement with NULLS FIRST keyword
*/
    public SOQLQueryBuilder nullsFirst(){
        this.orderByFieldNameNullsFirstLastMap.put(this.lastOrderByFieldName,NULLS_FIRST_STR);
        return this;
    }
    /**
     * Sets the WHERE clause in the SOQL query based on the provided SObjectField field.
     *
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name})
                .whereClause(Account.Name)
                .likeValue('%Test account name%');

       String expectedQueryString = 'SELECT Name FROM Account WHERE Name Like \'%Test account name%\'';
     *
     * @param field the SObjectField to use for the WHERE clause
     * @return the SOQLQueryBuilder object with the WHERE clause based on the provided SObjectField
    */
    public SOQLQueryBuilder whereClause(SObjectField field){
        requireNonNull(field, 'WHERE clause field cannot be null!');
        validateFieldType(field, this.currentSObjectType, ' in whereClause method!');
        return whereClause(field.getDescribe().getName());
    }
    /**
     * Sets the WHERE clause in the SOQL query based on the provided String field api name.
     *
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name})
                .whereClause('Name')
                .likeValue('%Test account name%');

       String expectedQueryString = 'SELECT Name FROM Account WHERE Name Like \'%Test account name%\'';
     *
     * @param fieldName the String field api name to use for the WHERE clause
     * @return the SOQLQueryBuilder object with the WHERE clause based on the provided field api name
    */
    public SOQLQueryBuilder whereClause(String fieldName){
        requireNonNull(fieldName, 'WHERE clause field name cannot be null!');
        this.isWhereStatement = true;
        setLogicalOperator(fieldName,'');
        return this;
    }
    /**
     * Adds an opening bracket to the WHERE clause of the SOQL query based on the provided SObjectField.
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder('Account')
                .selectSpecificFields(new List<SObjectField>{Account.Name,Account.NumberOfEmployees})
                .whereOpenBracket(Account.Name)
                .likeValue('%Test account name%')
                .andCloseBracket(Account.NumberOfEmployees)
                .greaterThan(20);

        String expectedQueryString = 'SELECT Name,NumberOfEmployees FROM Account WHERE  ' +
                '(Name LIKE \'%Test account name%\'  AND  NumberOfEmployees > 20);
     *
     * @param field the SObjectField field to use for the opening bracket
     * @return the SOQLQueryBuilder object with the opening bracket added to the WHERE clause
     */
    public SOQLQueryBuilder whereOpenBracket(SObjectField field){
        requireNonNull(field, 'WHERE clause field cannot be null!');
        validateFieldType(field, this.currentSObjectType, ' in whereOpenBracket method!');
        return whereOpenBracket(field.getDescribe().getName());
    }
    /**
   * Adds an opening bracket to the WHERE clause of the SOQL query based on the provided String field api name.
   * @example
   * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder('Account')
              .selectSpecificFields(new List<SObjectField>{Account.Name,Account.NumberOfEmployees})
              .whereOpenBracket('Name')
              .likeValue('%Test account name%\')
              .andCloseBracket(Account.NumberOfEmployees)
              .greaterThan(20);

      String expectedQueryString = 'SELECT Name,NumberOfEmployees FROM Account WHERE  ' +
              '(Name LIKE \'%Test account name%\'  AND  NumberOfEmployees > 20);
   *
   * @param fieldName the String field api name to use for the opening bracket
   * @return the SOQLQueryBuilder object with the opening bracket added to the WHERE clause
   */
    public SOQLQueryBuilder whereOpenBracket(String fieldName){
        requireNonNull(fieldName, 'WHERE clause field name cannot be null!');
        this.isWhereStatement = true;
        FieldNameId fieldNameId = setLogicalOperator(fieldName,'');
        this.fieldNameIdOpenBracketMap.put(fieldNameId,OPEN_BRACKET);
        return this;
    }
    /**
     * Sets the HAVING clause statement in the SOQL query based on the provided String field api name.
     * @example
     *  SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.City,Lead.CreatedDate})
                .whereClause(Lead.CreatedDate)
                .inside(new List<Date>{Date.newInstance(2022,02,01)})
                .groupBy(Lead.City)
                .havingClause('City')
                .likeValue('%San');

        String expectedQueryString = 'SELECT City,CreatedDate FROM Lead WHERE' +
                ' CreatedDate IN (2022-02-01T00:00:00Z)  ' +
                'GROUP BY City HAVING City LIKE \'%San\'';
     *
     *
     * @param fieldName the string field api name to use for the HAVING clause statement
     * @return the SOQLQueryBuilder object with the HAVING clause statement based on the provided field api name
     */
    public SOQLQueryBuilder havingClause(String fieldName){
        requireNonNull(fieldName, 'HAVING clause field name cannot be null!');
        this.isWhereStatement = false;
        setLogicalOperator(fieldName,'');
        return this;
    }
    /**
        * Sets the HAVING clause statement in the SOQL query based on the provided SObjectField.
       * @example
       *  *  SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                    .selectSpecificFields(new List<SObjectField>{Lead.City,Lead.CreatedDate})
                    .whereClause(Lead.CreatedDate)
                    .inside(new List<Date>{Date.newInstance(2022,02,01)})
                    .groupBy(Lead.City)
                    .havingClause(Lead.City)
                    .likeValue('%San');

            String expectedQueryString = 'SELECT City,CreatedDate FROM Lead WHERE' +
                    ' CreatedDate IN (2022-02-01T00:00:00Z)  ' +
                    'GROUP BY City HAVING City LIKE \'%San\'';

       * @param field the SObjectField to use for the HAVING clause statement
       * @return the SOQLQueryBuilder object with the HAVING clause statement based on the provided SObjectField
   */
    public SOQLQueryBuilder havingClause(SObjectField field){
        requireNonNull(field, 'HAVING clause field cannot be null!');
        validateFieldType(field, this.currentSObjectType, ' in havingClause method!');
        havingClause(field.getDescribe().getName());
        return this;
    }
    /**
     * Sets the HAVING clause statement in the SOQL query based on the provided SOQLFunction.
     * @example
     * SOQLFunction countFunction = SOQLFunction.of(SOQLFunction.FunctionName.COUNT,Lead.Name);
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .addFunction(countFunction)
                .groupBy(Lead.LeadSource)
                .havingClause(countFunction)
                .greaterThan(23);

        String expectedQueryString = 'SELECT LeadSource,COUNT(Name) FROM Lead GROUP BY LeadSource HAVING COUNT(Name) > 23';
     *
     * @param function the SOQLFunction to use for the HAVING clause statement
     * @return the SOQLQueryBuilder object with the HAVING clause statement based on the provided SOQLFunction
    */
    public SOQLQueryBuilder havingClause(SOQLFunction function){
        requireNonNull(function, 'HAVING clause function cannot be null!');
        havingClause(function.toString());
        return this;
    }
    /**
     * Adds an opening bracket to the HAVING clause statement of the SOQL query based on the provided String field api name.
     * @example
     * SOQLFunction countFunction = SOQLFunction.of(SOQLFunction.FunctionName.COUNT,Lead.Name);
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .addFunction(countFunction)
                .groupBy(Lead.LeadSource)
                .havingOpenBracket('LeadSource')
                .likeValue('%San')
                .andCloseBracket(countFunction)
                .greaterThan(23);

        String expectedQueryString = 'SELECT LeadSource,COUNT(Name)
                FROM Lead GROUP BY LeadSource HAVING (LeadSource LIKE \'%San\'  AND  COUNT(Name) > 23)';

     * @param fieldName the name of the field to use for the opening bracket in the HAVING clause statement
     * @return the SOQLQueryBuilder object with the opening bracket added to the HAVING clause statement
   */
    public SOQLQueryBuilder havingOpenBracket(String fieldName){
        requireNonNull(fieldName, 'HAVING clause field name cannot be null!');
        this.isWhereStatement = false;
        FieldNameId fieldNameId = setLogicalOperator(fieldName,'');
        this.fieldNameIdOpenBracketMap.put(fieldNameId,OPEN_BRACKET);
        return this;
    }
    /**
     * Adds an opening bracket to the HAVING clause statement of the SOQL query based on the provided SObjectField.
     * @example
     * SOQLFunction countFunction = SOQLFunction.of(SOQLFunction.FunctionName.COUNT,Lead.Name);
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .addFunction(countFunction)
                .groupBy(Lead.LeadSource)
                .havingOpenBracket(Lead.LeadSource)
                .likeValue('%San')
                .andCloseBracket(countFunction)
                .greaterThan(23);

        String expectedQueryString = 'SELECT LeadSource,COUNT(Name)
                FROM Lead GROUP BY LeadSource HAVING (LeadSource LIKE \'%San\'  AND  COUNT(Name) > 23)';
     *
     * @param field the SObjectField to use for the opening bracket in the HAVING clause statement
     * @return the SOQLQueryBuilder object the opening bracket added to the HAVING clause statement
 */
    public SOQLQueryBuilder havingOpenBracket(SObjectField field){
        requireNonNull(field, 'HAVING clause field cannot be null!');
        validateFieldType(field, this.currentSObjectType, ' in havingOpenBracket method!');
        havingOpenBracket(field.getDescribe().getName());
        return this;
    }
    /**
     * Adds an opening bracket to the HAVING clause statement of the SOQL query based on the provided SOQLFunction.
     *
     * @example
     *  SOQLFunction countFunction = SOQLFunction.of(SOQLFunction.FunctionName.COUNT,Lead.Name);
        SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .addFunction(countFunction)
                .groupBy(Lead.LeadSource)
                .havingOpenBracket(countFunction)
                .greaterThan(23)
                .andCloseBracket(Lead.LeadSource)
                .likeValue('%San');

        String expectedQueryString = 'SELECT LeadSource,COUNT(Name)
                FROM Lead GROUP BY LeadSource HAVING (COUNT(Name) > 23  AND  LeadSource LIKE \'%San\')';

     * @param function the SOQLFunction to use for the opening bracket in the HAVING clause statement
     * @return the SOQLQueryBuilder object the opening bracket added to the HAVING clause statement
     */
    public SOQLQueryBuilder havingOpenBracket(SOQLFunction function){
        requireNonNull(function, 'HAVING clause function cannot be null!');
        havingOpenBracket(function.toString());
        return this;
    }
    /**
     * Sets the AND condition in the SOQL query based on the provided SObjectField.
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .whereClause(Lead.LeadSource)
                .likeValue('%San')
                .andCondition(Lead.City)
                .likeValue('%San');

        String expectedQueryString = 'SELECT LeadSource FROM Lead WHERE LeadSource LIKE \'%San\'
                                        AND  City LIKE \'%San\'';
     *
     * @param field the SObjectField to use for the AND condition
     * @return the SOQLQueryBuilder object with the AND condition based on the provided SObjectField
 */
    public SOQLQueryBuilder andCondition(SObjectField field){
        requireNonNull(field, 'AND condition field cannot be null!');
        validateFieldType(field, this.currentSObjectType, ' in andCondition method!');
        return andCondition(field.getDescribe().getName());
    }
    /**
     * Sets the AND condition in the SOQL query based on the provided String field api name.
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .whereClause(Lead.LeadSource)
                .likeValue('%San')
                .andCondition('City')
                .likeValue('%San');

        String expectedQueryString = 'SELECT LeadSource FROM Lead WHERE LeadSource LIKE \'%San\'
                                        AND  City LIKE \'%San\'';
     *
     * @param fieldName the name of the field to use for the AND condition
     * @return the SOQLQueryBuilder object with the AND condition based on the provided String field api name
    */
    public SOQLQueryBuilder andCondition(String fieldName){
        requireNonNull(fieldName, 'AND condition field name cannot be null!');
        setLogicalOperator(fieldName,OP_AND);
        return this;
    }
    /**
     * Add an opening bracket to the AND condition in the SOQL query based on the provided String field api name.
     *
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .whereClause(Lead.LeadSource)
                .likeValue('%San')
                .andOpenBracket(Lead.City)
                .likeValue('%San')
                .orCondition(Lead.State)
                .likeValue('%CA');

        String expectedQueryString = 'SELECT LeadSource FROM Lead WHERE LeadSource LIKE \'%San\'
                                        AND  (City LIKE \'%San\'  OR  State LIKE \'%CA\')';
     *
     * @param field the SObjectField to use for the opening bracket in the AND condition
     * @return the current instance of SOQLQueryBuilder with the opening bracket added to the AND condition
     */
    public SOQLQueryBuilder andOpenBracket(SObjectField field){
        requireNonNull(field, 'AND condition field cannot be null!');
        validateFieldType(field, this.currentSObjectType, ' in andOpenBracket method!');
        return andOpenBracket(field.getDescribe().getName());
    }
    /**
     * Add an opening bracket to the AND condition in the SOQL query based on the provided String field api name.
     *
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .whereClause(Lead.LeadSource)
                .likeValue('%San')
                .andOpenBracket('City')
                .likeValue('%San')
                .andCloseBracket('State')
                .likeValue('%CA');

        String expectedQueryString = 'SELECT LeadSource FROM Lead WHERE LeadSource LIKE \'%San\'
                                        AND  (City LIKE \'%San\' AND State LIKE \'%CA\')';
     *
     * @param fieldName the name of the field to use for the opening bracket in the AND condition
     * @return the current instance of SOQLQueryBuilder with the opening bracket added to the AND condition
     */
    public SOQLQueryBuilder andOpenBracket(String fieldName){
        requireNonNull(fieldName, 'AND condition field name cannot be null!');
        FieldNameId fieldNameId = setLogicalOperator(fieldName,OP_AND);
        this.fieldNameIdOpenBracketMap.put(fieldNameId,OPEN_BRACKET);
        return this;
    }
    /**
     * Add a closing bracket to the AND condition in the SOQL query based on the provided String field api name.
     *
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .whereClause(Lead.LeadSource)
                .likeValue('%San')
                .andOpenBracket(Lead.City)
                .likeValue('%San')
                .andCloseBracket(Lead.State)
                .likeValue('%CA');

        String expectedQueryString = 'SELECT LeadSource FROM Lead WHERE LeadSource LIKE \'%San\'
                                        AND  (City LIKE \'%San\'  AND  State LIKE \'%CA\')';
     *
     * @param field the SObjectField to use for the closing bracket in the AND condition
     * @return the current instance of SOQLQueryBuilder with the closing bracket added to the AND condition
     */
    public SOQLQueryBuilder andCloseBracket(SObjectField field){
        requireNonNull(field, 'AND condition field cannot be null!');
        validateFieldType(field, this.currentSObjectType, ' in andCloseBracket method!');
        return andCloseBracket(field.getDescribe().getName());
    }
    /**
     * Add a closing bracket to the AND condition in the SOQL query based on the provided String field api name.
     *
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .whereClause(Lead.LeadSource)
                .likeValue('%San')
                .andOpenBracket('City')
                .likeValue('%San')
                .andCloseBracket('State')
                .likeValue('%CA');

        String expectedQueryString = 'SELECT LeadSource FROM Lead WHERE LeadSource LIKE \'%San\'
                                        AND  (City LIKE \'%San\'  OR  State LIKE \'%CA\')';
     *
     * @param fieldName the name of the field to use for the closing bracket in the AND condition
     * @return the current instance of SOQLQueryBuilder with the closing bracket added to the AND condition
     */
    public SOQLQueryBuilder andCloseBracket(String fieldName){
        requireNonNull(fieldName, 'AND condition field name cannot be null!');
        FieldNameId fieldNameId = setLogicalOperator(fieldName,OP_AND);
        this.fieldNameIdCloseBracketMap.put(fieldNameId,CLOSE_BRACKET);
        return this;
    }
    /**
     * Sets the OR condition in the SOQL query based on the provided SObjectField.
     *
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .whereClause(Lead.LeadSource)
                .likeValue('%San')
                .orCondition(Lead.City)
                .likeValue('%San');

        String expectedQueryString = 'SELECT LeadSource FROM Lead WHERE LeadSource LIKE \'%San\'
                                        OR  City LIKE \'%San\'';
     *
     * @param field the SObjectField to use for the OR condition
     * @return the SOQLQueryBuilder object with the OR condition based on the provided SObjectField
     */
    public SOQLQueryBuilder orCondition(SObjectField field){
        requireNonNull(field, 'OR condition field cannot be null!');
        validateFieldType(field, this.currentSObjectType, ' in orCondition method!');
        return orCondition(field.getDescribe().getName());
    }
    /**
     * Sets the OR condition in the SOQL query based on the provided String field api name.
     *
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .whereClause(Lead.LeadSource)
                .likeValue('%San')
                .orCondition('City')
                .likeValue('%San');

        String expectedQueryString = 'SELECT LeadSource FROM Lead WHERE LeadSource LIKE \'%San\'
                                        OR  City LIKE \'%San\'';
     *
     * @param fieldName the name of the field to use for the OR condition
     * @return the SOQLQueryBuilder object with the OR condition based on the provided String field api name
     */
    public SOQLQueryBuilder orCondition(String fieldName){
        requireNonNull(fieldName, 'OR condition field name cannot be null!');
        setLogicalOperator(fieldName,OP_OR);
        return this;
    }
    /**
     * Add an opening bracket to the OR condition in the SOQL query based on the provided SObjectField.
     *
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .whereClause(Lead.LeadSource)
                .likeValue('%San')
                .orOpenBracket(Lead.City)
                .likeValue('%San')
                .orCloseBracket(Lead.State)
                .likeValue('%CA');

        String expectedQueryString = 'SELECT LeadSource FROM Lead WHERE LeadSource LIKE \'%San\'
                                        OR  (City LIKE \'%San\' OR State LIKE \'%CA\')';
     *
     * @param field the SObjectField to use for the opening bracket in the OR condition
     * @return the current instance of SOQLQueryBuilder with the opening bracket added to the OR condition
     */
    public SOQLQueryBuilder orOpenBracket(SObjectField field){
        requireNonNull(field, 'OR condition field cannot be null!');
        validateFieldType(field, this.currentSObjectType, ' in orOpenBracket method!');
        return orOpenBracket(field.getDescribe().getName());
    }
    /**
     * Add an opening bracket to the OR condition in the SOQL query based on the provided String field api name.
     *
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .whereClause(Lead.LeadSource)
                .likeValue('%San')
                .orOpenBracket('City')
                .likeValue('%San')
                .orCloseBracket('State')
                .likeValue('%CA');

        String expectedQueryString = 'SELECT LeadSource FROM Lead WHERE LeadSource LIKE \'%San\'
                                        OR  (City LIKE \'%San\' OR State LIKE \'%CA\')';
     *
     * @param fieldName the name of the field to use for the opening bracket in the OR condition
     * @return the current instance of SOQLQueryBuilder with the opening bracket added to the OR condition
     */
    public SOQLQueryBuilder orOpenBracket(String fieldName){
        requireNonNull(fieldName, 'OR condition field name cannot be null!');
        FieldNameId fieldNameId = setLogicalOperator(fieldName,OP_OR);
        this.fieldNameIdOpenBracketMap.put(fieldNameId,OPEN_BRACKET);
        return this;
    }
    /**
     * Add a closing bracket to the OR condition in the SOQL query based on the provided SObjectField.
     *
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .whereClause(Lead.LeadSource)
                .likeValue('%San')
                .orOpenBracket(Lead.City)
                .likeValue('%San')
                .orCloseBracket(Lead.State)
                .likeValue('%CA');

        String expectedQueryString = 'SELECT LeadSource FROM Lead WHERE LeadSource LIKE \'%San\'
                                        OR  (City LIKE \'%San\' OR State LIKE \'%CA\')';
     *
     * @param field the SObjectField to use for the closing bracket in the OR condition
     * @return the current instance of SOQLQueryBuilder with the closing bracket added to the OR condition
     */
    public SOQLQueryBuilder orCloseBracket(SObjectField field){
        requireNonNull(field, 'OR condition field cannot be null!');
        validateFieldType(field, this.currentSObjectType, ' in orCloseBracket method!');
        return orCloseBracket(field.getDescribe().getName());
    }
    /**
     * Add a closing bracket to the OR condition in the SOQL query based on the provided String field api name.
     *
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .whereClause(Lead.LeadSource)
                .likeValue('%San')
                .orOpenBracket('City')
                .likeValue('%San')
                .orCloseBracket('State')
                .likeValue('%CA');

        String expectedQueryString = 'SELECT LeadSource FROM Lead WHERE LeadSource LIKE \'%San\'
                                        OR  (City LIKE \'%San\' OR State LIKE \'%CA\')';
     *
     * @param fieldName the name of the field to use for the closing bracket in the OR condition
     * @return the current instance of SOQLQueryBuilder with the closing bracket added to the OR condition
     */
    public SOQLQueryBuilder orCloseBracket(String fieldName){
        requireNonNull(fieldName, 'OR condition field name cannot be null!');
        FieldNameId fieldNameId = setLogicalOperator(fieldName,OP_OR);
        this.fieldNameIdCloseBracketMap.put(fieldNameId,CLOSE_BRACKET);
        return this;
    }
     /**
      * Sets the equals (=) operator in the SOQL query with the provided value.
      * @example
      * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .whereClause(Lead.LeadSource)
                .equals('Web');

        String expectedQueryString = 'SELECT LeadSource FROM Lead WHERE LeadSource = \'Web\'';
        * @param value the value to use for the equals operator
        * @return the current instance of SOQLQueryBuilder with the equals operator set
      */
    public SOQLQueryBuilder equals(Object value){
        setOperator(OP_EQUALS,value);
        return this;
    }
    /**
     * Sets the not equals (!=) operator in the SOQL query with the provided value.
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Lead.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Lead.LeadSource})
                .whereClause(Lead.LeadSource)
                .notEquals('Web');

        String expectedQueryString = 'SELECT LeadSource FROM Lead WHERE LeadSource != \'Web\'';
     * @param value the value to use for the not equals operator
     * @return the current instance of SOQLQueryBuilder with the not equals operator set
     */
    public SOQLQueryBuilder notEquals(Object value){
        setOperator(OP_NOT_EQUALS,value);
        return this;
    }
    /**
     * Sets the greater than (>) operator in the SOQL query with the provided value.
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.NumberOfEmployees})
                .whereClause(Account.NumberOfEmployees)
                .greaterThan(12);

        String expectedQueryString = 'SELECT NumberOfEmployees FROM Account WHERE NumberOfEmployees > 12';
     * @param value the value to use for the greater than operator
     * @return the current instance of SOQLQueryBuilder with the greater than operator set
     */
    public SOQLQueryBuilder greaterThan(Object value){
        requireNonNull(value, 'Value cannot be null for the greater than operator!');
        setOperator(OP_GREATER,value);
        return this;
    }
    /**
     * Sets the greater than or equals (>=) operator in the SOQL query with the provided value.
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.NumberOfEmployees})
                .whereClause(Account.NumberOfEmployees)
                .greaterOrEquals(12);

        String expectedQueryString = 'SELECT NumberOfEmployees FROM Account WHERE NumberOfEmployees >= 12';
     * @param value the value to use for the greater than or equals operator
     * @return the current instance of SOQLQueryBuilder with the greater than or equals operator set
     */
    public SOQLQueryBuilder greaterOrEquals(Object value){
        requireNonNull(value, 'Value cannot be null for the greater than or equals operator!');
        setOperator(OP_GREATER_EQUALS,value);
        return this;
    }
    /**
   * Sets the less than or equals (<=) operator in the SOQL query with the provided value.
   * @example
   * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
              .selectSpecificFields(new List<SObjectField>{Account.NumberOfEmployees})
              .whereClause(Account.NumberOfEmployees)
              .lessOrEquals(12);

      String expectedQueryString = 'SELECT NumberOfEmployees FROM Account WHERE NumberOfEmployees <= 12';
   * @param value the value to use for the less than or equals operator
   * @return the current instance of SOQLQueryBuilder with the less than or equals operator set
   */
    public SOQLQueryBuilder lessOrEquals(Object value){
        requireNonNull(value, 'Value cannot be null for the less than or equals operator!');
        setOperator(OP_LESS_EQUALS,value);
        return this;
    }
    /**
     * Sets the less than (<) operator in the SOQL query with the provided value.
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.NumberOfEmployees})
                .whereClause(Account.NumberOfEmployees)
                .lessThan(12);

        String expectedQueryString = 'SELECT NumberOfEmployees FROM Account WHERE NumberOfEmployees < 12';
     * @param value the value to use for the less than operator
     * @return the current instance of SOQLQueryBuilder with the less than operator set
     */
    public SOQLQueryBuilder lessThan(Object value){
        requireNonNull(value, 'The value cannot be null for the less than operator');
        setOperator(OP_LESS,value);
        return this;
    }
    /**
     * Sets the operator INCLUDES in the SOQL query with the provided values.
     * @example
     *  SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.AccountSource})
                .whereClause(Account.AccountSource)
                .includes(new List<String>{'Web','Phone Inquiry'})
                .orCondition(Account.AccountSource)
                .excludes(new List<String>{'Other'});

        String expectedQueryString = 'SELECT AccountSource FROM Account WHERE ' +
                'AccountSource INCLUDES (\'Web\',\'Phone Inquiry\') OR AccountSource EXCLUDES (\'Other\')';
     *
     * @param values a list of values to use for the INCLUDES operator
     * @return the SOQLQueryBuilder instance with include operator set
     */
    public SOQLQueryBuilder includes(List<String> values){
        requireNonNull(values, 'The values list cannot be null for the includes operator');
        setOperator(OP_INCLUDES,values);
        return this;
    }
    /**
     * Sets the operator EXCLUDES in the SOQL query with the provided values.
     * @example
     *  SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.AccountSource})
                .whereClause(Account.AccountSource)
                .includes(new List<String>{'Web','Phone Inquiry'})
                .orCondition(Account.AccountSource)
                .excludes(new List<String>{'Other'});

        String expectedQueryString = 'SELECT AccountSource FROM Account WHERE ' +
                'AccountSource INCLUDES (\'Web\',\'Phone Inquiry\') OR AccountSource EXCLUDES (\'Other\')';
     *
     * @param values a list of values to use for the EXCLUDES operator
     * @return the SOQLQueryBuilder instance with exclude operator set
     */
    public SOQLQueryBuilder excludes(List<String> values){
        requireNonNull(values, 'The values list cannot be null for the excludes operator');
        setOperator(OP_EXCLUDES,values);
        return this;
    }
    /**
     * Sets the operator IN in the SOQL query with the provided values.
     * @example
      SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                 selectSpecificFields(new List<SObjectField>{Account.Id})
                .whereClause('Id')
                .inside(new List<Id>{'001D0000000X0X0','001D0000000X0X1'});

        String expectedQueryString = 'SELECT Id FROM Account WHERE Id IN (\'001D0000000X0X0\',\'001D0000000X0X1\')';
     *
     * @param values a list of values to use for the IN operator
     * @return the SOQLQueryBuilder instance with IN operator set
     */
    public SOQLQueryBuilder inside(List<Object> values){
        requireNonNull(values, 'The values list cannot be null for the inside operator');
        setOperator(OP_IN,values);
        return this;
    }
    /**
     * Sets the operator NOT IN in the SOQL query with the provided values.
     * @example
      SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                 selectSpecificFields(new List<SObjectField>{Account.Id})
                .whereClause('Id')
                .notInside(new List<Id>{'001D0000000X0X0','001D0000000X0X1'});

        String expectedQueryString = 'SELECT Id FROM Account WHERE Id NOT IN (\'001D0000000X0X0\',\'001D0000000X0X1\')';
     *
     * @param values a list of values to use for the NOT IN operator
     * @return the SOQLQueryBuilder instance with NOT IN operator set
     */
    public SOQLQueryBuilder notInside(List<Object> values){
        requireNonNull(values, 'The values list cannot be null for the not inside operator');
        setOperator(OP_NOT_IN,values);
        return this;
    }
    /**
     * Sets the operator LIKE in the SOQL query with the provided value.
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name})
                .whereClause(Account.Name)
                .likeValue('Acme%');

        String expectedQueryString = 'SELECT Name FROM Account WHERE Name LIKE \'Acme%\'';
     * @param value the value to use for the LIKE operator
     * @return the current instance of SOQLQueryBuilder with the LIKE operator set
     */
    public SOQLQueryBuilder likeValue(String value){
        requireNonNull(value, 'The value cannot be null for the like operator');
        setOperator(OP_LIKE,value);
        return this;
    }
    /**
     * Sets the operator NOT LIKE in the SOQL query with the provided value.
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name})
                .whereClause(Account.Name)
                .notLikeValue('Acme%');

        String expectedQueryString = 'SELECT Name FROM Account WHERE Name NOT LIKE \'Acme%\'';
     * @param value the value to use for the NOT LIKE operator
     * @return the current instance of SOQLQueryBuilder with the NOT LIKE operator set
     */
    public SOQLQueryBuilder notLikeValue(String value){
        requireNonNull(value, 'The value cannot be null for the not like operator');
        setOperator(OP_NOT_LIKE,value);
        return this;
    }
    /**
     * Returns a list of SObjects based on the specified access level.
     * @param accessLevel The access level for the query.
     * @return List of SObjects based on the specified access level.
     */
    public List<SObject> getResultList(AccessLevel accessLevel){
        QueryStringResult queryResult = getQueryStringResult();
        return Database.queryWithBinds(queryResult.queryString,queryResult.objectBinds,accessLevel);
    }
    /**
     * Returns a list of SObjects with Access Level set to SYSTEM_MODE.
     * @return List of SObjects with access level set to SYSTEM_MODE.
     */
    public List<SObject> getResultList(){
        return getResultList(AccessLevel.SYSTEM_MODE);
    }

    /**
     * Returns a map of SObjects based on the specified access level.
     * @param accessLevel The access level for the query.
     * @return Map of SObjects based on the specified access level with Id as the key and SObject as the value.
     */
    public Map<Id,SObject> getResultMap(AccessLevel accessLevel){
        return new Map<Id, SObject>(getResultList(accessLevel));
    }
    /**
     * Returns a map of SObjects with Access Level set to SYSTEM_MODE.
     * @return Map of SObjects with access level set to SYSTEM_MODE.
     */
    public Map<Id,SObject> getResultMap(){
        return getResultMap(AccessLevel.SYSTEM_MODE);
    }
    /**
     * Returns a single SObject based on the specified access level.
     * @param accessLevel The access level for the query.
     * @return First SObject in the list based on the specified access level or null if the list is empty.
     */
    public SObject getSingleResult(AccessLevel accessLevel){
        List<SObject> sObjects = getResultList(accessLevel);
        return sObjects.size() > 0 ? sObjects.get(0) : null;
    }
    /**
     * Returns a single SObject with Access Level set to SYSTEM_MODE.
     * @return First SObject in the list with access level set to SYSTEM_MODE or null if the list is empty.
     */
    public SObject getSingleResult(){
        return getSingleResult(AccessLevel.SYSTEM_MODE);
    }
    /**
     * Returns a single SObject based on the specified access level, and throws an exception if the list is empty.
     * @param messageIfNull Error message to be thrown if list is empty.
     * @param accessLevel The access level for the query.
     * @return First SObject in the list based on the specified access level.
     * @throws SObjectException if the list is empty.
    */
    public SObject getSingleResult(String messageIfNull, AccessLevel accessLevel){
        requireNonNull(messageIfNull, 'The messageIfNull parameter cannot be null for the getSingleResult method!');
        List<SObject> sObjects = getResultList(accessLevel);
        if(sObjects.size()>0){
            return sObjects.get(0);
        }
        throw new SObjectException(messageIfNull);
    }
    /**
     * Returns a single SObject with Access Level set to SYSTEM_MODE, and throws an exception if the list is empty.
     * @param messageIfNull Error message to be thrown if list is empty.
     * @return First SObject in the list with access level set to SYSTEM_MODE.
     * @throws SObjectException if the list is empty.
     */
    public SObject getSingleResult(String messageIfNull){
        return getSingleResult(messageIfNull, AccessLevel.SYSTEM_MODE);
    }

    /**
      * Returns the number of records that a dynamic SOQL query would return when executed with Access Level set to SYSTEM_MODE.
      * @return An Integer representing total SObjects count with access level set to SYSTEM_MODE.
    */
    public Integer getIntegerResult(){
        return getIntegerResult(AccessLevel.SYSTEM_MODE);
    }
    /**
      * Returns the number of records that a dynamic SOQL query would return when executed.
      * @param accessLevel The access level for the query.
      * @return An Integer representing total number of SObjects based on the specified access level.
      */
    public Integer getIntegerResult(AccessLevel accessLevel){
        QueryStringResult queryResult = getQueryStringResult();
        return Database.countQueryWithBinds(queryResult.queryString,queryResult.objectBinds,accessLevel);
    }
    /**
     * Returns an array of AggregateResult with Access Level set to SYSTEM_MODE.
     * @return An array of AggregateResult with access level set to SYSTEM_MODE.
     */
    public AggregateResult[] getAggregateResult(){
        return getAggregateResult(AccessLevel.SYSTEM_MODE);
    }
    /**
     * Returns an array of AggregateResult based on the specified access level.
     * @param accessLevel The access level for the query.
     * @return An array of AggregateResult based on the specified access level.
     */
    public AggregateResult[] getAggregateResult(AccessLevel accessLevel){
        return (AggregateResult[]) getResultList(accessLevel);
    }

    /**
       * Returns the SOQL query string that is used to dynamically query the SObject records.
       *
       * @return the SOQL query string.
    */
    public override String toString(){
        this.bindValueIndex = 0;
        return this.generateQuery(null).queryString;
    }
    /**
    * Return the QueryStringResult object that contains the SOQL query string and the bind values for executing the query.
    * @return QueryStringResult object
    */
    public QueryStringResult getQueryStringResult(){
        this.bindValueIndex = 0;
        return this.generateQuery(null);
    }
    private FieldNameId setLogicalOperator(String fieldName,String logicalOperator){
        FieldNameId fieldNameId = generateIdFromFieldName(fieldName);
        this.lastWhereFieldNameId = fieldNameId;
        this.fieldNameIdLogicalOperatorMap.put(fieldNameId,logicalOperator);
        return fieldNameId;
    }
    private void setOperator(String operator,Object value){
        this.fieldNameIdOperatorMap.put(this.lastWhereFieldNameId,operator);
        this.fieldNameIdValueMap.put(this.lastWhereFieldNameId,value);
    }

    private FieldNameId generateIdFromFieldName(String fieldName){
        Integer counter = this.whereFieldNameCounter++;
        String state = this.isWhereStatement ? WHERE_STR : HAVING_STR;
        return new FieldNameId(fieldName,counter,state);
    }
    class FieldNameId{
        final String fieldName;
        final Integer counter;
        final String state;

        FieldNameId(String fieldName,Integer counter,String state){
            this.fieldName = fieldName;
            this.counter = counter;
            this.state = state;
        }
        public Boolean equals(Object obj){
            if(obj instanceof FieldNameId){
                FieldNameId other = (FieldNameId)obj;
                return this.fieldName.equals(other.fieldName)
                        && this.counter == other.counter
                        && this.state.equals(other.state);
            }
            return false;
        }
        public Integer hashCode(){
            return (fieldName != null ? fieldName.hashCode() : 0) ^
                    (counter != null ? counter : 0) ^
                    (state != null ? state.hashCode() : 0);
        }
    }

    /**
     * Generates and returns the final QueryStringResult based on the criteria set in the query builder object.
     * @example 'SELECT Name,AccountSource,NumberOfEmployees FROM Account WHERE ' +
                ' (Name LIKE :value0 AND NumberOfEmployees > :value1) ' +
                'OR NumberOfEmployees < :value2 OR AccountSource = :value3'

     *  Map<String,Object> objectBinds = new Map<String,Object>{'value0' => '%'+ACCOUNT_NAME+'%','value1' => 20,'value2' => 10,'value3' => 'Web'};
     *
     * @param childRelationshipName Optional parameter, if specified, will override the sObject type name for the FROM clause in the query.
     * @return The final QueryStringResult object containing the final SOQL query string and the bind values.
    */
    private QueryStringResult generateQuery(String childRelationshipName){
        //the query string is built based on the sObject type name
        //or if the child relationship name specified it is building as an inner child query
        String sObjectTypeNameInQuery = childRelationshipName!=null ? childRelationshipName : this.currentSObjectType.getDescribe().getName();
        String limitStatement = this.limitNumber!=null ? LIMIT_STR+' '+this.limitNumber: '';
        String forUpdateStatement = this.forUpdate ? FOR_UPDATE_STR : '';
        String forViewStatement = this.forView ? FOR_VIEW_STR : '';
        String updateTrackingStatement = this.updateTracking ? UPDATE_TRACKING_STR : '';
        String updateViewstatStatement = this.updateViewStat ? UPDATE_VIEWSTAT_STR : '';
        String forReferenceStatement = this.forReference ? FOR_REFERENCE_STR : '';
        String allRowsStatement = this.allRows ? ALL_ROWS_STR : '';
        String offsetStatement = this.offsetNumber!=null ? OFFSET_STR+' '+this.offsetNumber: '';
        String groupByStatement = this.groupByFields.size()>0 ? GROUP_BY_STR+' '+String.join(new List<String>(this.groupByFields),','): '';
        String withStatement = this.withStatement !=null ? WITH_STR+' '+this.withStatement : '';
        String usingScopeStatement = this.usingScopeStatement !=null ? USING_SCOPE_STR+' '+this.usingScopeStatement : '';
        //generate the inner related child queries
        QueryStringResult innerQueryResult = generateInnerQueriesString(this.innerQueries);
        //generate the related parent fields
        String parentFields = generateParentFields(parentQueries);
        //generate the where statement
        LogicalOperatorStatement whereStatement = generateWhereStatement(this.fieldNameIdValueMap);
        //generate the having statement
        LogicalOperatorStatement havingStatement = generateHavingStatement(this.fieldNameIdValueMap);
        //generate the order by statement
        String orderByStatement = generateOrderStatement(this.orderByFieldNameOrderMap,this.orderByFieldNameNullsFirstLastMap);
        Map<String,Object> objectBinds = new Map<String,Object>();

        //if no fields are specified, add the default field
        if(this.fields.size()==0){
            this.fields.add(DEFAULT_FIELD);
        }

        String queryStatement = SELECT_STR+' '+String.join(new List<String>(this.fields),',');

        if(innerQueryResult.queryString.length()>0){
            queryStatement+=','+innerQueryResult.queryString;
            objectBinds.putAll(innerQueryResult.objectBinds);
        }
        if(parentFields.length()>0){
            queryStatement+= ','+parentFields;
        }
        //add the from clause
        queryStatement +=' '+ FROM_STR+' '+ sObjectTypeNameInQuery;

        if(whereStatement.logicalOperatorStatement.length()>0){
            queryStatement += ' '+whereStatement.logicalOperatorStatement;
            objectBinds.putAll(whereStatement.objectBinds);
        }
        if(usingScopeStatement.length()>0){
            queryStatement += ' '+usingScopeStatement;
        }
        if(withStatement.length()>0){
            queryStatement += ' '+withStatement;
        }
        if(groupByStatement.length()>0){
            queryStatement += ' '+groupByStatement;
        }
        if(havingStatement.logicalOperatorStatement.length()>0){
            queryStatement += ' '+havingStatement.logicalOperatorStatement;
            objectBinds.putAll(havingStatement.objectBinds);
        }
        if(orderByStatement.length()>0){
            queryStatement += ' '+orderByStatement;
        }
        if(limitStatement.length()>0){
            queryStatement += ' '+limitStatement;
        }
        if(offsetStatement.length()>0){
            queryStatement += ' '+offsetStatement;
        }
        if(forUpdateStatement.length()>0){
            queryStatement += ' '+forUpdateStatement;
        }
        if(forViewStatement.length()>0){
            queryStatement += ' '+forViewStatement;
        }
        if(forReferenceStatement.length()>0){
            queryStatement += ' '+forReferenceStatement;
        }
        if(updateTrackingStatement.length()>0){
            queryStatement += ' '+updateTrackingStatement;
        }
        if(updateViewstatStatement.length()>0){
            queryStatement += ' '+updateViewstatStatement;
        }
        if(allRowsStatement.length()>0){
            queryStatement += ' '+allRowsStatement;
        }
        queryStatement +=' ';
        System.debug(queryStatement);
        return new QueryStringResult(queryStatement, objectBinds);
    }
    public class QueryStringResult {
        public final Map<String, Object> objectBinds;
        public final String queryString;
        QueryStringResult(String queryString, Map<String, Object> objectBinds) {
            this.queryString = queryString;
            this.objectBinds = objectBinds;
        }
    }
    /**
     * Generates the inner query string for a list of SOQLQueryBuilder objects
     *
     * @example (SELECT Id,Name FROM Account WHERE Id =: value0),(SELECT Id,Name FROM Contact)
     * @param innerQueries a list of SOQLQueryBuilder objects representing the inner queries
     * @return QueryStringResult object containing the inner query string and the bind values
    */
    private QueryStringResult generateInnerQueriesString(List<SOQLQueryBuilder> innerQueries){
        String innerQueryString = '';
        Map<String,Object> objectBinds = new Map<String,Object>();
        SOQLQueryBuilder actualInnerQueryBuilder;
        if(innerQueries!=null && innerQueries.size()>0){
            for(SOQLQueryBuilder innerQueryBuilder:innerQueries){
                //set the bind value index for indexing the bind values globally
                if(actualInnerQueryBuilder!=null){
                    innerQueryBuilder.bindValueIndex = actualInnerQueryBuilder.bindValueIndex++;
                }else{
                    innerQueryBuilder.bindValueIndex = 0;
                }
                actualInnerQueryBuilder = innerQueryBuilder;

                //add the child query to the inner query string
                QueryStringResult innerQueryResult = generateInnerQueryString(innerQueryBuilder);
                innerQueryString += '('+innerQueryResult.queryString+'),';
                objectBinds.putAll(innerQueryResult.objectBinds);
            }
            //set the bind value index to the bind value index of the last inner query builder
            //to continue the bind value indexing from there
            this.bindValueIndex = actualInnerQueryBuilder.bindValueIndex++;
            innerQueryString = innerQueryString.substring(0,innerQueryString.lastIndexOf(','));
        }
        return new QueryStringResult(innerQueryString, objectBinds);
    }
    /**
     * Generates a QueryStringResult object for the given SOQLQueryBuilder's child relationship name,
     * automatically finding it if not specified.
     *
     * @example (SELECT Id,Name FROM Account WHERE Id =: value0)
     * @param innerQueryBuilder the SOQLQueryBuilder object being used.
     * @return a QueryStringResult object containing the generated query string and the bind values.
     * @throws SObjectException if no child relationship is found or multiple child relationships are found
    */
    private QueryStringResult generateInnerQueryString(SOQLQueryBuilder innerQueryBuilder){
        //if the child relationship name is not specified, try to find it automatically
        String childRelationshipName = innerQueryBuilder.childRelationshipName;
        if(childRelationshipName==null){
            List<String> childRelationshipFieldNames = getChildRelationshipNames(
                    this.currentSObjectType,innerQueryBuilder.currentSObjectType);

            if(childRelationshipFieldNames.isEmpty()){
                throw new SObjectException('No child relationship found between '+
                        this.currentSObjectType+' and '+innerQueryBuilder.currentSObjectType);
            }
            if(childRelationshipFieldNames.size()>1){
                throw new SObjectException('Multiple child relationships found between '+
                        this.currentSObjectType+' and '+innerQueryBuilder.currentSObjectType +' : '
                        +childRelationshipFieldNames
                        +'. Please specify the child relationship name in the query ' +
                        'using setChildRelationshipName(String childRelationshipName) method!');
            }
            childRelationshipName = childRelationshipFieldNames.get(0);
        }
        return innerQueryBuilder.generateQuery(childRelationshipName);
    }
    /**
     * Generates the representation of related parent query fields by iterating over
     * the list of parent queries and converting the fields to parent fields.
     * @example Account.Name, ReportsTo.Name
     *
     * @return a string containing the parent fields separated by commas
     */
    private String generateParentFields(List<SOQLQueryBuilder> parentQueries){
        String parentFieldsString = '';
        if(parentQueries!=null && parentQueries.size()>0){
            for(SOQLQueryBuilder parentQueryBuilder:parentQueries){
                //get the parent lookup field name
                String parentSOQLRelationshipName = parentQueryBuilder.parentRelationshipName;
                if(parentSOQLRelationshipName==null){
                    parentSOQLRelationshipName = convertParentRelationshipNameToSOQLFormat(
                            parentQueryBuilder.currentSObjectType.getDescribe().getName());
                }
                //convert the fields to SOQL parent query fields
                Set<String> parentFields = convertFieldsToParentFields(parentSOQLRelationshipName,parentQueryBuilder.fields);
                parentFieldsString += String.join(new List<String>(parentFields),',')+',';
            }
            parentFieldsString = parentFieldsString.substring(0,parentFieldsString.lastIndexOf(','));
        }
        return parentFieldsString;
    }
    private LogicalOperatorStatement generateWhereStatement(Map<FieldNameId,Object> fieldNameIdValueMap){
        return generateLogicalOperatorStatement(fieldNameIdValueMap,WHERE_STR);
    }
    private LogicalOperatorStatement generateHavingStatement(Map<FieldNameId,Object> fieldNameIdValueMap){
        return generateLogicalOperatorStatement(fieldNameIdValueMap,HAVING_STR);
    }
    /**
    *  Generates a logical operator statement based on the provided map of FieldNameId objects and their corresponding values,
     * and a statement operator (WHERE or HAVING).
     *
    * @param fieldNameIdValueMap a map of FieldNameId objects and their corresponding values.
    * @param statementOperator the statement operator to use in the logical operator statement (WHERE or HAVING).
    * @return a LogicalOperatorStatement object containing the logical operator statement such as WHERE Name = :value0 AND Age = :value1
     * and a Map of bind variables and corresponding values.
    */
    private LogicalOperatorStatement generateLogicalOperatorStatement(Map<FieldNameId,Object> fieldNameIdValueMap,String statementOperator){
        String logicalOperatorStatement = '';
        Map<String,Object> objectBinds = new Map<String,Object>();
        if(fieldNameIdValueMap.keySet().size()>0){
            for(FieldNameId fieldNameId : fieldNameIdValueMap.keySet()){
                if(fieldNameId.state.endsWithIgnoreCase(statementOperator)){
                    LogicalStatement logicalStatement = generateLogicalStatement(fieldNameId);
                    logicalOperatorStatement += logicalStatement.logicalStatement;
                    objectBinds.put(logicalStatement.bindValueKey,logicalStatement.value);
                }
            }
            logicalOperatorStatement = logicalOperatorStatement.length()>0 ? statementOperator+' '+ logicalOperatorStatement: '';
        }
        return new LogicalOperatorStatement(logicalOperatorStatement,objectBinds);
    }
    class LogicalOperatorStatement{
        final String logicalOperatorStatement;
        final Map<String,Object> objectBinds;
        LogicalOperatorStatement(String logicalOperatorStatement, Map<String,Object> objectBinds){
            this.logicalOperatorStatement = logicalOperatorStatement;
            this.objectBinds = objectBinds;
        }
    }
    /**
     * Generates an SQL ORDER BY statement based on the keys and values of the map
     * of field names and their corresponding sort order and null sorting preferences.
     * If the map is empty, an empty String will be returned.
     *
     * @example ORDER BY Name ASC, Age DESC NULLS LAST
     *
     * @return an SQL ORDER BY statement as a String.
    */
    private String generateOrderStatement(Map<String,String> orderByFieldNameOrderMap,
                                          Map<String,String> orderByFieldNameNullsFirstLastMap){
        String orderStatement = orderByFieldNameOrderMap.keySet().size()>0 ? ORDER_BY_STR+' ': '';
        if(orderByFieldNameOrderMap.keySet().size()>0){
            for(String fieldName: orderByFieldNameOrderMap.keySet()){
                String nullsLastFirst = orderByFieldNameNullsFirstLastMap.get(fieldName) == null ? ''
                                        :orderByFieldNameNullsFirstLastMap.get(fieldName);

                String orderStr = orderByFieldNameOrderMap.get(fieldName);
                orderStatement += fieldName +' '+orderStr +' '+nullsLastFirst+', ';
            }
            orderStatement = orderStatement.substring(0,orderStatement.lastIndexOf(','));
        }
        return orderStatement;
    }
    /**
     * Generates a logical statement for a given FieldNameId object
     *
     * @param fieldNameId the FieldNameId object for which to generate the logical statement
     * @return a LogicalStatement object containing value, operator, logical operator,
     * bind value key and logical statement string such as 'Name = :value1 AND Age = :value2'
     */
    private LogicalStatement generateLogicalStatement(FieldNameId fieldNameId){
        Object value = this.fieldNameIdValueMap.get(fieldNameId);
        String bindValueKey = 'value'+this.bindValueIndex++;
        String operator = fieldNameIdOperatorMap.get(fieldNameId);
        String logicalOperator = fieldNameIdLogicalOperatorMap.get(fieldNameId);

        String openBracket = this.fieldNameIdOpenBracketMap.get(fieldNameId) == null? ''
                                : this.fieldNameIdOpenBracketMap.get(fieldNameId);
        String closeBracket = this.fieldNameIdCloseBracketMap.get(fieldNameId) == null? ''
                                : this.fieldNameIdCloseBracketMap.get(fieldNameId);
        String logicalStatement = '';

        if(operator.equals(OP_NOT_LIKE)){
            logicalStatement = logicalOperator+' '
                    +openBracket+'('+ 'NOT '+fieldNameId.fieldName +' '
                    +'LIKE '
                    +':'+bindValueKey+') '+closeBracket+' ';
        }else{
            logicalStatement = logicalOperator+' '
                    +openBracket+ fieldNameId.fieldName +' '
                    +operator+' '
                    +':'+bindValueKey+closeBracket+' ';
        }
        return new LogicalStatement(value, operator, logicalOperator, bindValueKey, logicalStatement);
    }
    class LogicalStatement{
        final Object value;
        final String operator;
        final String logicalOperator;
        final String bindValueKey;
        final String logicalStatement;

        LogicalStatement(Object value, String operator, String logicalOperator, String bindValueKey, String logicalStatement){
            this.value = value;
            this.operator = operator;
            this.logicalOperator = logicalOperator;
            this.bindValueKey = bindValueKey;
            this.logicalStatement = logicalStatement;
        }

    }
    /**
     * This method is used to convert the given parent object relationship name to a format that can be use as SOQL query field name,
     * if it ends with '__c' the 'c' character is removed from the end of the relationship name and replaced with 'r'.
     * If the given relationship name does not end with '__c', it is returned as is.
     * @example
     * parentRelationshipName = 'Account__c'
     * return = 'Account__r'
     *
     * @param parentRelationshipName - the parent relationship name to be converted
     * @return the parent object relationship name in SOQL query format
    */
    @TestVisible
    private String convertParentRelationshipNameToSOQLFormat(String parentRelationshipName){
        String parentsObjectRelationshipName = parentRelationshipName;
        if(parentsObjectRelationshipName.endsWithIgnoreCase('__c')){
            parentsObjectRelationshipName = parentRelationshipName.substring(0,parentRelationshipName.lastIndexOfIgnoreCase('c'));
            parentsObjectRelationshipName += 'r';
        }
        return parentsObjectRelationshipName;
    }
    /**
     * This method is used to convert a set of parent field names in SOQL query format.
     * The parent relationship name and the set of field names are given as input parameters.
     *
     * @example
     * parentRelationshipName = 'Account'
     * fieldNames = ['Name','Id']
     * return = ['Account.Name','Account.Id']
     *
     * @param parentRelationshipName - the parent object relationship name
     * @param fieldNames - the set of field names to be converted
     * @return the set of parent field names
  */
   private Set<String> convertFieldsToParentFields(String parentRelationshipName,Set<String> fieldNames){
        Set<String> parentFieldNames = new Set<String>();
        for(String fieldName:fieldNames){
            parentFieldNames.add(parentRelationshipName+'.'+fieldName);
        }
        return parentFieldNames;
    }
    /**
     * Retrieves the names of all fields of an sObject type specified by sObjectTypeName,
     * including custom fields and the standard fields.
     * If includeLargeText parameter is true, large text fields are also included in the returned list.
     *
     * @param sObjectType the SObjectType to retrieve field names for
     * @param includeLargeText a Boolean value indicating whether or not to include large text fields
     * @return a List object containing the names of all fields of the specified sObject type
     */
    public static List<String> getAllFieldNamesForSObjectType(SObjectType sObjectType,Boolean includeLargeText){
        return getFieldNamesForSObject(sObjectType,true,true,includeLargeText);
    }
    /**
     * Retrieves the names of all standard fields of an sObject type specified by sObjectType.
     *
     * @param sObjectType the SObjectType to retrieve standard field names for
     * @return a List object containing the names of all standard fields of the specified sObject type
    */
    public static List<String> getStandardFieldNamesForSObjectType(SObjectType sObjectType){
        return getFieldNamesForSObject(sObjectType,false,true,true);
    }
    /**
     * Retrieves the names of all custom fields of an sObject type specified by sObjectType.
     * If includeLargeText parameter is true, large text fields are also included in the returned list.
     *
     * @param sObjectType the SObjectType type to retrieve custom field names for
     * @param includeLargeText a Boolean value indicating whether or not to include large text fields
     * @return a List object containing the names of all custom fields of the specified sObject type
     */
    public static List<String> getCustomFieldNamesForSObjectType(SObjectType sObjectType,Boolean includeLargeText){
        return getFieldNamesForSObject(sObjectType,true,false,includeLargeText);
    }
    /**
     * Retrieves the list of API names of all fields on the given SObject type that meet the specified criteria.
     *
     * @param sObjectType    the SObjectType type to retrieve fields for
     * @param isCustom       a boolean value indicating whether custom fields should be included in the returned list
     * @param isStandard     a boolean value indicating whether standard fields should be included in the returned list
     * @param includeLargeText a boolean value indicating whether large text (>255) fields should be included in the returned list
     *
     * @return A list of API names of all fields on the given SObject type that meet the specified criteria.
     */
    public static List<String> getFieldNamesForSObject(SObjectType sObjectType,Boolean isCustom,Boolean isStandard,Boolean includeLargeText){
        List<String> fieldNames = new List<String>();
        List<Schema.SObjectField> sObjectFields = getFieldsForSObject(sObjectType,isCustom,isStandard,includeLargeText);

        for(Schema.SObjectField field: sObjectFields){
            fieldNames.add(field.getDescribe().getName());
        }
        return fieldNames;
    }
    /**
    * Returns a list of SObject fields for a given SObject type.
    *
    * @param sObjectType    the SObjectType type to retrieve fields for
    * @param isCustom       a boolean value indicating whether custom fields should be included in the returned list
    * @param isStandard     a boolean value indicating whether standard fields should be included in the returned list
    * @param includeLargeText a boolean value indicating whether large text (>255) fields should be included in the returned list
    *
    * @return a list of SObject fields for the given SObject type
    */
    public static List<SObjectField> getFieldsForSObject(SObjectType sObjectType,Boolean isCustom,Boolean isStandard,Boolean includeLargeText){
        List<Schema.SObjectField> fieldsToReturn = new List<Schema.SObjectField>();
        List<Schema.SObjectField> sObjectFields = sObjectType.getDescribe().fields.getMap().values();

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

    /**
     * Returns a list of child relationship names between a parent sObject type and a child sObject type.
     *
     * @param parentSObjectType The type object of the parent sObject.
     * @param childSObjectType The type object of the child sObject.
     * @return A list of child relationship names between the two specified sObject types.
     */
    public static List<String> getChildRelationshipNames(SObjectType parentSObjectType, SObjectType childSObjectType) {
        List<String> childRelationshipNames = new List<String>();
        for(Schema.ChildRelationship childRelationShip :parentSObjectType.getDescribe().getChildRelationships()){
            if(childRelationShip.getChildSObject() ==childSObjectType && childRelationShip.getRelationshipName() != null){
                childRelationshipNames.add(childRelationShip.getRelationshipName());
            }
        }
        return childRelationshipNames;
    }
    /**
     * Returns the specified object if it is not null; otherwise throws an
     * IllegalArgumentException with the given message.
     *
     * @param obj the object to check for null
     * @param message the message to use for the exception if obj is null
     * @return the non-null object
     * @throws IllegalArgumentException if obj is null
    */
    private Object requireNonNull(Object obj, String message){
        if (obj == null){
            throw new IllegalArgumentException(message);
        }
        return obj;
    }
    /**
        * Validates if the SObjectField is of the expected SObjectType.
        *
        * @param fieldTypeToCheck The SObjectField to be validated.
        * @param sobjectTypeToExpect The expected SObjectType.
        * @param extraMessage The extra message to be included in the exception.
        * @throws IllegalArgumentException if the SObjectField is not of the expected SObjectType or null.
      */
    private void validateFieldType(SObjectField fieldTypeToCheck,SObjectType sobjectTypeToExpect, String extraMessage){
        String fieldNameSObjectTypeName = fieldTypeToCheck.getDescribe().getSObjectType().getDescribe().getName();
        String sObjectTypeName = sobjectTypeToExpect.getDescribe().getSObjectType().getDescribe().getName();
        if(!fieldNameSObjectTypeName.equals(sObjectTypeName)){
            throw new IllegalArgumentException('Field type is not of type '+sObjectTypeName
                    +'! Field name: '+fieldTypeToCheck.getDescribe().getName()+
                    ' Field type: '+fieldTypeToCheck.getDescribe().getSObjectType().getDescribe().getName() +' '+ extraMessage);
        }
    }

}