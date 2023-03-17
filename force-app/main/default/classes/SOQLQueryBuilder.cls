
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

    private String sObjectTypeName;
    //Maps to store the field name and the operator to be used in the query
    private Map<String,String> fieldNameOperatorMap;
    //Maps to store the field name and the logical operator to be used in the query
    private Map<String,String> fieldNameLogicalOperatorMap;
    //Maps to store the field name and the open bracket to be used in the query
    private Map<String,String> fieldNameOpenBracketMap;
    //Maps to store the field name and the close bracket to be used in the query
    private Map<String,String> fieldNameCloseBracketMap;
    //Maps to store the field name and the order to be used in the query
    private Map<String,String> orderByFieldNameOrderMap;
    //Maps to store the field name and the nulls first/last to be used in the query
    private Map<String,String> orderByFieldNameNullsFirstLastMap;
    //Maps to store the field name and the value to be used in the query for where clause
    private Map<String,Object> fieldNameValueMap;
    //Set to store the fields to be selected in the query
    private Set<String> fields;
    //Set to store the fields to be grouped in the query
    private Set<String> groupByFields;
    //List to store the related child queries
    private List<SOQLQueryBuilder> innerQueries;
    //List to store the parent queries
    private List<SOQLQueryBuilder> parentQueries;
    //Name of the parent lookup field name for the parent fields query if it's not the main SObject type name
    private String parentLookupFieldName;

    private String strWhereStatement;
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
    private String lastWhereFieldName;
    private String lastOrderByFieldName;
    private Integer whereFieldNameCounter = 0;

    public SOQLQueryBuilder(SObjectType sObjectType){
        requireNonNull(sObjectType, 'SObject type cannot be null!');
        init(sObjectType.getDescribe().getName());
    }
    public SOQLQueryBuilder(String sObjectTypeName){
        requireNonNull(sObjectTypeName, 'SObject type cannot be null!');
        try{
            ((SObject) Type.forName(sObjectTypeName).newInstance())
                    .getSObjectType();
        }catch (Exception e){
            throw new SObjectException('Invalid SObject type: ' + sObjectTypeName);
        }
        init(sObjectTypeName);
    }
    private void init(String sObjectTypeName){
        this.sObjectTypeName = sObjectTypeName;
        this.fieldNameValueMap = new Map<String,Object>();
        this.fieldNameOperatorMap = new Map<String,String>();
        this.fieldNameLogicalOperatorMap = new Map<String,String>();
        this.fieldNameOpenBracketMap = new Map<String,String>();
        this.fieldNameCloseBracketMap = new Map<String,String>();
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
    * Sets the parent lookup field name to be used in the SOQL query when adding a parent query and the
     * lookup relationship field name is not the same as the parent SObject type name.
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Contact.getSObjectType())
              .selectSpecificFields(new List<SObjectField>{Contact.LastName})
                 .addParentQuery(new SOQLQueryBuilder(Contact.getSObjectType())
                         .selectSpecificFields(new List<SObjectField>{Contact.Name})
                         .setParentLookupFieldName('ReportsTo'));

        String expectedQueryString = 'SELECT LastName,ReportsTo.Name FROM Contact;
    *
    * @param parentLookupFieldName the parent lookup field name to be set.
    * @return SOQLQueryBuilder the current instance of the builder.
    */
    public SOQLQueryBuilder setParentLookupFieldName(String parentLookupFieldName){
        requireNonNull(parentLookupFieldName, 'Parent lookup field name cannot be null!');
        this.parentLookupFieldName = parentLookupFieldName;
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
        this.fields.addAll(getCustomFieldNamesForSObjectType(this.sObjectTypeName,includeLargeText));
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
        this.fields.addAll(getAllFieldNamesForSObjectType(this.sObjectTypeName,includeLargeText));
        return this;
    }
    /**
    * Selects all standard fields for the SObject type in the query builder.
    *
    * @return SOQLQueryBuilder the current instance of the builder.
    */
    public SOQLQueryBuilder selectStandardFields(){
        this.fields.addAll(getStandardFieldNamesForSObjectType(this.sObjectTypeName));
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
        requireNonNull(field, 'Field cannot be null!');
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
     * Sets the WHERE clause in the SOQL query based on the provided string SOQL where statement.
     * @example
     * SOQLQueryBuilder soqlQueryBuilder = new SOQLQueryBuilder(Account.getSObjectType())
                .selectSpecificFields(new List<SObjectField>{Account.Name})
                .whereStatement('Name Like \'%Test account name%\'');

        String expectedQueryString = 'SELECT Name FROM Account  WHERE Name Like \'%Test account name%\'';
     *
     * @param whereStatement the string WHERE statement for the SOQL query
     * @return the SOQLQueryBuilder object with the WHERE statement provided
 */
    public SOQLQueryBuilder whereStatement(String whereStatement){
        requireNonNull(whereStatement, 'WHERE statement cannot be null!');
        this.strWhereStatement = whereStatement;
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
        String fieldNameId = setLogicalOperator(fieldName,'');
        this.fieldNameOpenBracketMap.put(fieldNameId,OPEN_BRACKET);
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
        String fieldNameId = setLogicalOperator(fieldName,'');
        this.fieldNameOpenBracketMap.put(fieldNameId,OPEN_BRACKET);
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
        String fieldNameId = setLogicalOperator(fieldName,OP_AND);
        this.fieldNameOpenBracketMap.put(fieldNameId,OPEN_BRACKET);
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
        String fieldNameId = setLogicalOperator(fieldName,OP_AND);
        this.fieldNameCloseBracketMap.put(fieldNameId,CLOSE_BRACKET);
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
        String fieldNameId = setLogicalOperator(fieldName,OP_OR);
        this.fieldNameOpenBracketMap.put(fieldNameId,OPEN_BRACKET);
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
        String fieldNameId = setLogicalOperator(fieldName,OP_OR);
        this.fieldNameCloseBracketMap.put(fieldNameId,CLOSE_BRACKET);
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
    * Returns the result of the SOQL query as a list of sObjects.
    *
    * @return the result of the SOQL query as a list of sObjects
    */
    public List<SObject> getResultList(){
        return Database.query(generateQuery(null));
    }
    /**
     * Returns the result of the SOQL query as a map of sObjects.
     * @return  the result of the SOQL query as a map of sObjects
     * where the key is the Id of the sObject and the value is the sObject itself.
     */
    public Map<Id,SObject> getResultMap(){
        return new Map<Id, SObject>(getResultList());
    }
    /**
     * Returns the result of the SOQL query as a single sObject.
     * If the query returns more than one sObject, the first one is returned.
     *
     * @return the result of the SOQL query as a single sObject
     * or null if the query returns no sObject.
     */
    public SObject getSingleResult(){
        List<SObject> sObjects = getResultList();
        return sObjects.size() > 0 ? sObjects.get(0) : null;
    }
    /**
     * Returns the result of the SOQL query as a single sObject.
     * If the query returns more than one sObject, the first one is returned.
     *
     * @param messageIfNull the message to use in the exception if the query returns no sObject
     * @return the result of the SOQL query as a single sObject
     * @throws SObjectException if the query returns no sObject
     */
    public SObject getSingleResult(String messageIfNull){
        requireNonNull(messageIfNull, 'The messageIfNull cannot be null for the getSingleResult method!');
        List<SObject> sObjects = getResultList();
        if(sObjects.size()>0){
            return sObjects.get(0);
        }
        throw new SObjectException(messageIfNull);
    }

    /**
     * Returns the number of records returned by the SOQL query
     * @return the number of records that a dynamic SOQL query would return when executed
     */
    public Integer getIntegerResult(){
        return Database.countQuery(generateQuery(null));
    }
    /**
    * Returns the result of the SOQL query as an array of AggregateResult.
    *
    * @return AggregateResult[] the result of the SOQL query
    */
    public AggregateResult[] getAggregateResult(){
        return (AggregateResult[]) Database.query(generateQuery(null));
    }
    /**
       * Returns the SOQL query string used to generate the result.
       *
       * @return the SOQL query string used to generate the result.
    */
    public override String toString(){
        return this.generateQuery(null);
    }
    private String setLogicalOperator(String fieldName,String logicalOperator){
        String fieldNameId = generateIdFromFieldName(fieldName);
        this.lastWhereFieldName = fieldNameId;
        this.fieldNameLogicalOperatorMap.put(fieldNameId,logicalOperator);
        return fieldNameId;
    }
    private void setOperator(String operator,Object value){
        this.fieldNameOperatorMap.put(this.lastWhereFieldName,operator);
        this.fieldNameValueMap.put(this.lastWhereFieldName,value);
    }

    private String generateIdFromFieldName(String fieldName){
        Integer counter = this.whereFieldNameCounter++;
        String state = this.isWhereStatement ? WHERE_STR : HAVING_STR;
        return fieldName+':'+counter+':'+state;
    }
    private String extractFieldNameFromId(String idStr){
        return idStr.substring(0,idStr.indexOf(':'));
    }
    /**
     * Generates and returns the final SOQL query string based on the criteria set in the query builder object.
     * @param childRelationshipName Optional parameter, if specified, will override the sObject type name for the FROM clause in the query.
     * @return The final SOQL query string.
  */
    private String generateQuery(String childRelationshipName){
        //the query string is built based on the sObject type name
        //or if the child relationship name specified it is building as an inner child query
        String sObjectTypeNameInQuery = childRelationshipName!=null ? childRelationshipName : this.sObjectTypeName;
        String limitStatement = this.limitNumber!=null ? LIMIT_STR+' '+this.limitNumber: '';
        String forUpdateStatement = this.forUpdate ? FOR_UPDATE_STR : '';
        String forViewStatement = this.forView ? FOR_VIEW_STR : '';
        String updateTrackingStatement = this.updateTracking ? UPDATE_TRACKING_STR : '';
        String updateViewstatStatement = this.updateViewStat ? UPDATE_VIEWSTAT_STR : '';
        String forReferenceStatement = this.forReference ? FOR_REFERENCE_STR : '';
        String allRowsStatement = this.allRows ? ALL_ROWS_STR : '';
        String offsetStatement = this.offsetNumber!=null ? OFFSET_STR+' '+this.offsetNumber: '';
        String groupByStatement = this.groupByFields.size()>0 ? GROUP_BY_STR+' '+String.join(new List<String>(this.groupByFields),','): '';
        String strCustomWhereStatement = this.strWhereStatement !=null ? this.strWhereStatement : '';
        String withStatement = this.withStatement !=null ? WITH_STR+' '+this.withStatement : '';
        String usingScopeStatement = this.usingScopeStatement !=null ? USING_SCOPE_STR+' '+this.usingScopeStatement : '';
        //generate the inner related child queries
        String innerQueryString = generateInnerQueriesString();
        //generate the related parent fields
        String parentFields = generateParentFields();
        //generate the where statement
        String whereStatement = generateWhereStatement();
        //generate the having statement
        String havingStatement = generateHavingStatement();
        //generate the order by statement
        String orderByStatement = generateOrderStatement();

        //if no fields are specified, add the default field
        if(this.fields.size()==0){
            this.fields.add(DEFAULT_FIELD);
        }
        //
        String queryStatement = SELECT_STR+' '+String.join(new List<String>(this.fields),',');

        if(innerQueryString.length()>0){
            queryStatement+=','+innerQueryString;
        }
        if(parentFields.length()>0){
            queryStatement+= ','+parentFields;
        }
        //add the from clause
        queryStatement +=' '+ FROM_STR+' '+ sObjectTypeNameInQuery;

        if(whereStatement.length()>0){
            queryStatement += ' '+whereStatement;
        }
        if(strCustomWhereStatement.length()>0){
            if(whereStatement.isWhitespace()){
                strCustomWhereStatement = ' '+WHERE_STR+' '+strCustomWhereStatement;
            }
            queryStatement += ' '+strCustomWhereStatement;
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
        if(havingStatement.length()>0){
            queryStatement += ' '+havingStatement;
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
        return queryStatement;
    }

    /**
    * Generates the inner query string the related child queries to be used by the parent SOQL query.
    * @example (SELECT Name FROM Contacts),(SELECT Name FROM Opportunities)
     *
    * @return the related child queries to be used by the parent SOQL query.
    */
    private String generateInnerQueriesString(){
        String innerQueryString = '';
        if(this.innerQueries.size()>0){
            for(SOQLQueryBuilder innerQueryBuilder:innerQueries){
                innerQueryString += '('+innerQueryBuilder.generateQuery(
                       getChildRelationshipName(this.sObjectTypeName,innerQueryBuilder.sObjectTypeName))+'),';
            }
            innerQueryString = innerQueryString.substring(0,innerQueryString.lastIndexOf(','));
        }
        return innerQueryString;
    }
    /**
     * Generates the representation of related parent query fields by iterating over
     * the list of parent queries and converting the fields to parent fields.
     * @example Account.Name, ReportsTo.Name
     *
     * @return a string containing the parent fields separated by commas
     */
    private String generateParentFields(){
        String parentFieldsString = '';
        if(this.parentQueries.size()>0){
            for(SOQLQueryBuilder parentQueryBuilder:this.parentQueries){
                String sObjectTypeName = parentQueryBuilder.parentLookupFieldName != null ?
                        parentQueryBuilder.parentLookupFieldName : convertSObjectTypeNameToParent(parentQueryBuilder.sObjectTypeName);

                Set<String> parentFields = convertFieldsToParentFields(sObjectTypeName,parentQueryBuilder.fields);
                parentFieldsString += String.join(new List<String>(parentFields),',')+',';
            }
            parentFieldsString = parentFieldsString.substring(0,parentFieldsString.lastIndexOf(','));
        }
        return parentFieldsString;
    }
    /**
     * Builds a SQL WHERE statement based on the field names and values stored in the fieldNameValueMap.
     * @example WHERE Name = 'John' AND Age = 30
     * @return a string containing the WHERE statement with logical operators and values.
    */
    private String generateWhereStatement(){
        return generateLogicalOperatorStatement(WHERE_STR);
    }
    /**
     * Builds a SQL HAVING statement based on the field names and values stored in the fieldNameValueMap.
     * @example HAVING COUNT(Name) > 10
     * @return a string containing the HAVING statement with logical operators and values.
     */
    private String generateHavingStatement(){
        return generateLogicalOperatorStatement(HAVING_STR);
    }
    /**
     * Builds a logical SQL operator statement (i.e. WHERE or HAVING) based on the given statementOperator
     * and the field names and values stored in the fieldNameValueMap.
     *
     * @param statementOperator a string containing the SQL logical operator. Must be either "WHERE" or "HAVING".
     *
     * @return a string containing the logical operator statement with conditions and values.
     */
    private String generateLogicalOperatorStatement(String statementOperator){
        String stringStatement = '';
        if(fieldNameValueMap.keySet().size()>0){
            for(String fieldNameId : fieldNameValueMap.keySet()){
                if(fieldNameId.endsWithIgnoreCase(statementOperator)){
                    stringStatement += generateLogicalStatement(fieldNameId);
                }
            }
            stringStatement = stringStatement.length()>0 ? statementOperator+' '+ stringStatement: '';
        }
        return stringStatement;
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
    private String generateOrderStatement(){
        String orderStatement = orderByFieldNameOrderMap.keySet().size()>0 ? ORDER_BY_STR+' ': '';
        if(orderByFieldNameOrderMap.keySet().size()>0){
            for(String fieldName: orderByFieldNameOrderMap.keySet()){
                String nullsLastFirst = orderByFieldNameNullsFirstLastMap.get(fieldName) == null ? '':orderByFieldNameNullsFirstLastMap.get(fieldName);
                String orderStr = orderByFieldNameOrderMap.get(fieldName);
                orderStatement += fieldName +' '+orderStr +' '+nullsLastFirst+', ';
            }
            orderStatement = orderStatement.substring(0,orderStatement.lastIndexOf(','));
        }
        return orderStatement;
    }
    /**
     * Generates a logical statement for a given field name ID.
     *
     * @param fieldNameId the field name ID for which to generate the logical statement
     * @return a logical statement as a String using the value, operator, and brackets defined in the fieldNameValueMap, fieldNameOperatorMap,
     *         fieldNameOpenBracketMap, and fieldNameCloseBracketMap instance variables
     */
    private String generateLogicalStatement(String fieldNameId){
        Object value = this.fieldNameValueMap.get(fieldNameId);
        String valueString = '';
        String openBracket = this.fieldNameOpenBracketMap.get(fieldNameId) == null? ' ': this.fieldNameOpenBracketMap.get(fieldNameId);
        String closeBracket = this.fieldNameCloseBracketMap.get(fieldNameId) == null? ' ': this.fieldNameCloseBracketMap.get(fieldNameId);

        if(value instanceof String){
            valueString = '\''+String.escapeSingleQuotes((String) value)+'\'';
        }else if(value instanceof List<Object>){
            valueString = convertListToString((List<Object>) value);
        }else if(value instanceof Datetime){
            valueString = ((Datetime) value).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        }
        else{
            valueString = String.valueOf(value);
        }
        String operator = fieldNameOperatorMap.get(fieldNameId);
        if(operator.equals(OP_NOT_LIKE)){
            return fieldNameLogicalOperatorMap.get(fieldNameId)+' '
                    +openBracket+'('+ 'NOT '+extractFieldNameFromId(fieldNameId) +' '
                    +'LIKE'
                    +valueString+') '+closeBracket+' ';
        }else{
            return fieldNameLogicalOperatorMap.get(fieldNameId)+' '
                    +openBracket+ extractFieldNameFromId(fieldNameId) +' '
                    +operator+' '
                    +valueString+closeBracket+' ';
        }
    }
    /**
     * Converts a List of Objects to a String representation to be used in a SOQL query.
     *
     * @param objects the List of Objects to convert
     * @return a String representation of the List, in the format '(obj1, obj2, ..., objN)'
    */
    private String convertListToString(List<Object> objects){
        String str = OPEN_BRACKET;
        for(Object obj:objects){
            if(obj instanceof String){
                str += '\''+String.escapeSingleQuotes((String) obj)+'\',';
            }else if(obj instanceof Datetime){
                str += ((Datetime) obj).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')+',';
            }else{
                str += obj+',';
            }
        }
        if(objects.size()>0){
            str = str.substring(0,str.lastIndexOf(','));
        }
        str += CLOSE_BRACKET;
        return str;
    }
    /**
     * This method is used to convert the given sObject type name to its parent object type name, if it ends with '__c'.
     * The 'c' character is removed from the end of the type name and replaced with 'r'.
     * If the given sObject type name does not end with '__c', it is returned as is.
     *
     * @param sObjectTypeName - the sObject type name to be converted
     * @return the parent sObject type name
    */
    @TestVisible
    private String convertSObjectTypeNameToParent(String sObjectTypeName){
        String parentsObjectTypeName = sObjectTypeName;
        if(parentsObjectTypeName.endsWithIgnoreCase('__c')){
            parentsObjectTypeName = sObjectTypeName.substring(0,sObjectTypeName.lastIndexOfIgnoreCase('c'));
            parentsObjectTypeName += 'r';
        }
        return parentsObjectTypeName;
    }
    /**
     * This method is used to convert a set of field names to their equivalent parent field names.
     * The parent object type name and the set of field names are given as input parameters.
     *
     * @param parentsObjectTypeName - the parent object type name
     * @param fieldNames - the set of field names to be converted
     * @return the set of parent field names
  */
   private Set<String> convertFieldsToParentFields(String parentsObjectTypeName,Set<String> fieldNames){
        Set<String> parentFieldNames = new Set<String>();
        for(String fieldName:fieldNames){
            parentFieldNames.add(parentsObjectTypeName+'.'+fieldName);
        }
        return parentFieldNames;
    }
    /**
     * Retrieves the names of all fields of an sObject type specified by sObjectTypeName,
     * including custom fields and the standard fields.
     * If includeLargeText parameter is true, large text fields are also included in the returned list.
     *
     * @param sObjectTypeName the name of the sObject type to retrieve field names for
     * @param includeLargeText a Boolean value indicating whether or not to include large text fields
     * @return a List object containing the names of all fields of the specified sObject type
     */
    public static List<String> getAllFieldNamesForSObjectType(String sObjectTypeName,Boolean includeLargeText){
        return getFieldNamesForSObject(sObjectTypeName,true,true,includeLargeText);
    }
    /**
     * Retrieves the names of all standard fields of an sObject type specified by sObjectType.
     *
     * @param sObjectType the name of the sObject type to retrieve standard field names for
     * @return a List object containing the names of all standard fields of the specified sObject type
    */
    public static List<String> getStandardFieldNamesForSObjectType(String sObjectType){
        return getFieldNamesForSObject(sObjectType,false,true,true);
    }
    /**
     * Retrieves the names of all custom fields of an sObject type specified by sObjectType.
     * If includeLargeText parameter is true, large text fields are also included in the returned list.
     *
     * @param sObjectType the name of the sObject type to retrieve custom field names for
     * @param includeLargeText a Boolean value indicating whether or not to include large text fields
     * @return a List object containing the names of all custom fields of the specified sObject type
     */
    public static List<String> getCustomFieldNamesForSObjectType(String sObjectType,Boolean includeLargeText){
        return getFieldNamesForSObject(sObjectType,true,false,includeLargeText);
    }
    /**
     * Retrieves the list of API names of all fields on the given SObject type that meet the specified criteria.
     *
     * @param objectType     the name of the SObject type to retrieve fields for
     * @param isCustom       a boolean value indicating whether custom fields should be included in the returned list
     * @param isStandard     a boolean value indicating whether standard fields should be included in the returned list
     * @param includeLargeText a boolean value indicating whether large text (>255) fields should be included in the returned list
     *
     * @return A list of API names of all fields on the given SObject type that meet the specified criteria.
     */
    public static List<String> getFieldNamesForSObject(String objectType,Boolean isCustom,Boolean isStandard,Boolean includeLargeText){
        List<String> fieldNames = new List<String>();
        List<Schema.SObjectField> sObjectFields = getFieldsForSObject(objectType,isCustom,isStandard,includeLargeText);

        for(Schema.SObjectField field: sObjectFields){
            fieldNames.add(field.getDescribe().getName());
        }
        return fieldNames;
    }
    /**
    * Returns a list of SObject fields for a given SObject type.
    *
    * @param objectType     the name of the SObject type to retrieve fields for
    * @param isCustom       a boolean value indicating whether custom fields should be included in the returned list
    * @param isStandard     a boolean value indicating whether standard fields should be included in the returned list
    * @param includeLargeText a boolean value indicating whether large text (>255) fields should be included in the returned list
    *
    * @return a list of SObject fields for the given SObject type
    */
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
    /**
     * Returns all fields for a given SObject type.
     *
     * @param sObjectTypeName the name of the SObject type to retrieve fields for
     *
     * @return a list of all fields for the given SObject type
    */
    public static List<Schema.SObjectField> getAllFieldsForSObjectType(String sObjectTypeName){
        SObjectType type = Schema.getGlobalDescribe().get(sObjectTypeName);
        Map<String,Schema.SObjectField> sObjectFields = type.getDescribe().fields.getMap();

        return sObjectFields.values();
    }
    /**
     * Returns the name of a child relationship between a parent and child SObject type.
     *
     * @param parentSobjectName the name of the parent SObject type
     * @param childSobjectName  the name of the child SObject type
     *
     * @return the name of the child relationship between the parent and child SObject type,
      *         or null if no such relationship exists
    */
    public static String getChildRelationshipName(String parentSobjectName, String childSobjectName) {
        SObjectType parentsObjType = ((SObject) Type.forName(parentSobjectName).newInstance())
                .getSObjectType();
        SObjectType childSObjectType = ((SObject) Type.forName(childSobjectName).newInstance())
                .getSObjectType();
        return getChildRelationshipName(parentsObjType,childSObjectType);
    }
    /**
     * Returns the name of a child relationship between a parent and child SObject type.
     *
     * @param parentSObjectType the parent SObject type
     * @param childSObjectType  the child SObject type
     *
     * @return the name of the child relationship between the parent and child SObject type,
      *         or null if no such relationship exists
     */
    public static String getChildRelationshipName(SObjectType parentSObjectType, SObjectType childSObjectType) {
        for(Schema.ChildRelationship childRelationShip :parentSObjectType.getDescribe().getChildRelationships()){
            if(childRelationShip.getChildSObject() ==childSObjectType){
                return childRelationShip.getRelationshipName();
            }
        }
        return null;
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

}