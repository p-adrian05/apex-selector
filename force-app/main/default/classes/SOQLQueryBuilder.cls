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
    private Map<String,String> fieldNameOperatorMap;
    private Map<String,String> fieldNameLogicalOperatorMap;
    private Map<String,String> fieldNameOpenBracketMap;
    private Map<String,String> fieldNameCloseBracketMap;
    private Map<String,String> orderByFieldNameOrderMap;
    private Map<String,String> orderByFieldNameNullsFirstLastMap;

    private Set<String> fields;
    private Integer limitNumber;
    private Integer offsetNumber;
    private Set<String> groupByFields;
    private String strWhereStatement;
    private String withStatement;
    private String usingScopeStatement;
    private Map<String,Object> fieldNameValueMap;
    private List<SOQLQueryBuilder> innerQueries;
    private List<SOQLQueryBuilder> parentQueries;
    private String parentSObjectTypeName;
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
        init(sObjectType.getDescribe().getName());
    }
    public SOQLQueryBuilder(String sObjectTypeName){
        try{
            SObjectType parentsObjType = ((SObject) Type.forName(sObjectTypeName).newInstance())
                    .getSObjectType();
        }catch (Exception e){
            throw new SObjectException('Invalid sobjectType: '+ sObjectTypeName);
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
    public SOQLQueryBuilder addInnerQuery(SOQLQueryBuilder databaseQuery){
        this.innerQueries.add(databaseQuery);
        return this;
    }
    public SOQLQueryBuilder addParentQuery(SOQLQueryBuilder parentQuery){
        this.parentQueries.add(parentQuery);
        return this;
    }
    public SOQLQueryBuilder setParentSObjectTypeName(String parentSObjectTypeName){
        this.parentSObjectTypeName = parentSObjectTypeName;
        return this;
    }
    public SOQLQueryBuilder addFunction(SOQLFunction soqlFunction){
        this.fields.add(soqlFunction.toString());
        return this;
    }
    public SOQLQueryBuilder selectCustomFields(Boolean includeLargeText){
        this.fields.addAll(getCustomFieldNamesForSObjectType(this.sObjectTypeName,includeLargeText));
        this.fields.add(DEFAULT_FIELD);
        return this;
    }
    public SOQLQueryBuilder selectAllFields(Boolean includeLargeText){
        this.fields.addAll(getAllFieldNamesForSObjectType(this.sObjectTypeName,includeLargeText));
        return this;
    }
    public SOQLQueryBuilder selectStandardFields(){
        this.fields.addAll(getStandardFieldNamesForSObjectType(this.sObjectTypeName));
        return this;
    }
    public SOQLQueryBuilder selectSpecificFields(List<SObjectField> fields){
        List<String> fieldsString = new List<String>();
        if(fields!=null){
            for(SObjectField field: fields){
                fieldsString.add(field.getDescribe().getName());
            }
        }
        return selectSpecificFields(fieldsString);
    }
    public SOQLQueryBuilder selectSpecificFields(List<String> fields){
        if(fields!=null){
            this.fields.addAll(fields);
        }
        return this;
    }
    public SOQLQueryBuilder addLimit(Integer limitNumber){
        this.limitNumber = limitNumber;
        return this;
    }
    public SOQLQueryBuilder addOffset(Integer offsetNumber){
        this.offsetNumber = offsetNumber;
        return this;
    }
    public SOQLQueryBuilder forUpdate(){
        this.forUpdate = true;
        return this;
    }
    public SOQLQueryBuilder forView(){
        this.forView = true;
        return this;
    }
    public SOQLQueryBuilder forReference(){
        this.forReference = true;
        return this;
    }
    public SOQLQueryBuilder updateViewStat(){
        this.updateViewStat = true;
        return this;
    }
    public SOQLQueryBuilder updateTracking(){
        this.updateTracking = true;
        return this;
    }
    public SOQLQueryBuilder allRows(){
        this.allRows = true;
        return this;
    }
    public SOQLQueryBuilder with(String withStatement){
        if(this.withStatement == null){
            this.withStatement = withStatement;
        }else{
            this.withStatement += ' '+withStatement;
        }
        return this;
    }
    public SOQLQueryBuilder withSecurityEnforced(){
        if(this.withStatement == null){
            this.withStatement = SECURITY_ENFORCED_STR;
        }else{
            this.withStatement += ' '+SECURITY_ENFORCED_STR;
        }
        return this;
    }
    public SOQLQueryBuilder usingScope(FilterScope filterScope){
        this.usingScopeStatement = filterScope.name();
        return this;
    }
    public SOQLQueryBuilder groupBy(SObjectField field){
        return groupBy(field.getDescribe().getName());
    }
    public SOQLQueryBuilder groupBy(String fieldName){
        this.groupByFields.add(fieldName);
        return this;
    }
    public SOQLQueryBuilder groupBy(SOQLFunction soqlFunction){
        this.groupByFields.add(soqlFunction.toString());
        return this;
    }
    public SOQLQueryBuilder orderBy(SObjectField field){
        return orderBy(field.getDescribe().getName());
    }
    public SOQLQueryBuilder orderBy(String fieldName){
        this.orderByFieldNameOrderMap.put(fieldName,ASC_STR);
        this.lastOrderByFieldName = fieldName;
        return this;
    }
    public SOQLQueryBuilder ascending(){
        this.orderByFieldNameOrderMap.put(this.lastOrderByFieldName,ASC_STR);
        return this;
    }
    public SOQLQueryBuilder descending(){
        this.orderByFieldNameOrderMap.put(this.lastOrderByFieldName,DESC_STR);
        return this;
    }
    public SOQLQueryBuilder nullsLast(){
        this.orderByFieldNameNullsFirstLastMap.put(this.lastOrderByFieldName,NULLS_LAST_STR);
        return this;
    }
    public SOQLQueryBuilder nullsFirst(){
        this.orderByFieldNameNullsFirstLastMap.put(this.lastOrderByFieldName,NULLS_FIRST_STR);
        return this;
    }
    public SOQLQueryBuilder whereStatement(String whereStatement){
        this.strWhereStatement = whereStatement;
        return this;
    }
    public SOQLQueryBuilder whereClause(SObjectField field){
        return whereClause(field.getDescribe().getName());
    }
    public SOQLQueryBuilder whereClause(String fieldName){
        this.isWhereStatement = true;
        setLogicalOperator(fieldName,'');
        return this;
    }
    public SOQLQueryBuilder whereOpenBracket(SObjectField field){
        return whereOpenBracket(field.getDescribe().getName());
    }
    public SOQLQueryBuilder whereOpenBracket(String fieldName){
        this.isWhereStatement = true;
        String fieldNameId = setLogicalOperator(fieldName,'');
        this.fieldNameOpenBracketMap.put(fieldNameId,OPEN_BRACKET);
        return this;
    }
    public SOQLQueryBuilder havingClause(String fieldName){
        this.isWhereStatement = false;
        setLogicalOperator(fieldName,'');
        return this;
    }
    public SOQLQueryBuilder havingClause(SObjectField field){
        havingClause(field.getDescribe().getName());
        return this;
    }
    public SOQLQueryBuilder havingClause(SOQLFunction function){
        havingClause(function.toString());
        return this;
    }
    public SOQLQueryBuilder havingOpenBracket(String fieldName){
        this.isWhereStatement = false;
        String fieldNameId = setLogicalOperator(fieldName,'');
        this.fieldNameOpenBracketMap.put(fieldNameId,OPEN_BRACKET);
        return this;
    }
    public SOQLQueryBuilder havingOpenBracket(SObjectField field){
        havingOpenBracket(field.getDescribe().getName());
        return this;
    }
    public SOQLQueryBuilder havingOpenBracket(SOQLFunction function){
        havingOpenBracket(function.toString());
        return this;
    }
    public SOQLQueryBuilder andCondition(SObjectField field){
        return andCondition(field.getDescribe().getName());
    }
    public SOQLQueryBuilder andCondition(String fieldName){
        setLogicalOperator(fieldName,OP_AND);
        return this;
    }
    public SOQLQueryBuilder andOpenBracket(SObjectField field){
        return andOpenBracket(field.getDescribe().getName());
    }
    public SOQLQueryBuilder andOpenBracket(String fieldName){
        String fieldNameId = setLogicalOperator(fieldName,OP_AND);
        this.fieldNameOpenBracketMap.put(fieldNameId,OPEN_BRACKET);
        return this;
    }
    public SOQLQueryBuilder andCloseBracket(SObjectField field){
        return andCloseBracket(field.getDescribe().getName());
    }
    public SOQLQueryBuilder andCloseBracket(String fieldName){
        String fieldNameId = setLogicalOperator(fieldName,OP_AND);
        this.fieldNameCloseBracketMap.put(fieldNameId,CLOSE_BRACKET);
        return this;
    }
    public SOQLQueryBuilder orCondition(SObjectField field){
        return orCondition(field.getDescribe().getName());
    }
    public SOQLQueryBuilder orCondition(String fieldName){
        setLogicalOperator(fieldName,OP_OR);
        return this;
    }
    public SOQLQueryBuilder orOpenBracket(SObjectField field){
        return orOpenBracket(field.getDescribe().getName());
    }
    public SOQLQueryBuilder orOpenBracket(String fieldName){
        String fieldNameId = setLogicalOperator(fieldName,OP_OR);
        this.fieldNameOpenBracketMap.put(fieldNameId,OPEN_BRACKET);
        return this;
    }
    public SOQLQueryBuilder orCloseBracket(SObjectField field){
        return orCloseBracket(field.getDescribe().getName());
    }
    public SOQLQueryBuilder orCloseBracket(String fieldName){
        String fieldNameId = setLogicalOperator(fieldName,OP_OR);
        this.fieldNameCloseBracketMap.put(fieldNameId,CLOSE_BRACKET);
        return this;
    }
    public SOQLQueryBuilder equals(Object value){
        setOperator(OP_EQUALS,value);
        return this;
    }
    public SOQLQueryBuilder notEquals(Object value){
        setOperator(OP_NOT_EQUALS,value);
        return this;
    }
    public SOQLQueryBuilder greaterThan(Object value){
        setOperator(OP_GREATER,value);
        return this;
    }
    public SOQLQueryBuilder greaterOrEquals(Object value){
        setOperator(OP_GREATER_EQUALS,value);
        return this;
    }
    public SOQLQueryBuilder lessOrEquals(Object value){
        setOperator(OP_LESS_EQUALS,value);
        return this;
    }
    public SOQLQueryBuilder lessThan(Object value){
        setOperator(OP_LESS,value);
        return this;
    }
    public SOQLQueryBuilder includes(List<String> values){
        setOperator(OP_INCLUDES,values);
        return this;
    }
    public SOQLQueryBuilder excludes(List<String> values){
        setOperator(OP_EXCLUDES,values);
        return this;
    }
    public SOQLQueryBuilder inside(List<Object> values){
        setOperator(OP_IN,values);
        return this;
    }
    public SOQLQueryBuilder notInside(List<Object> values){
        setOperator(OP_NOT_IN,values);
        return this;
    }
    public SOQLQueryBuilder likeValue(String value){
        setOperator(OP_LIKE,value);
        return this;
    }
    public SOQLQueryBuilder notLikeValue(String value){
        setOperator(OP_NOT_LIKE,value);
        return this;
    }

    public List<SObject> getResultList(){
        return Database.query(generateQuery(null));
    }
    public Map<Id,SObject> getResultMap(){
        return new Map<Id, SObject>(getResultList());
    }
    public SObject getSingleResult(){
        List<SObject> sObjects = getResultList();
        return sObjects.size() > 0 ? sObjects.get(0) : null;
    }
    public SObject getSingleResult(String messageIfNull){
        List<SObject> sObjects = getResultList();
        if(sObjects.size()>0){
            return sObjects.get(0);
        }
        throw new SObjectException(messageIfNull);
    }
    public Integer getIntegerResult(){
        return Database.countQuery(generateQuery(null));
    }

    public AggregateResult[] getAggregateResult(){
        return (AggregateResult[]) Database.query(generateQuery(null));
    }

    public override String toString(){
        return this.generateQuery(null);
    }

    private String generateQuery(String childRelationshipName){
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
        String innerQueryString = generateInnerQueriesString();
        String parentFields = generateParentFields();
        String whereStatement = generateWhereStatement();
        String havingStatement = generateHavingStatement();
        String orderByStatement = generateOrderStatement();

        if(this.fields.size()==0){
            this.fields.add(DEFAULT_FIELD);
        }

        String queryStatement = SELECT_STR+' '+String.join(new List<String>(this.fields),',');

        if(innerQueryString.length()>0){
            queryStatement+=','+innerQueryString;
        }
        if(parentFields.length()>0){
            queryStatement+= ','+parentFields;
        }

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
    private String generateParentFields(){
        String parentFieldsString = '';
        if(this.parentQueries.size()>0){

            for(SOQLQueryBuilder parentQueryBuilder:this.parentQueries){
                String sObjectTypeName = parentQueryBuilder.parentSObjectTypeName != null ?
                        parentQueryBuilder.parentSObjectTypeName : convertSObjectTypeNameToParent(parentQueryBuilder.sObjectTypeName);

                Set<String> parentFields = convertFieldsToParentFields(sObjectTypeName,parentQueryBuilder.fields);
                parentFieldsString += String.join(new List<String>(parentFields),',')+',';
            }
            parentFieldsString = parentFieldsString.substring(0,parentFieldsString.lastIndexOf(','));
        }
        return parentFieldsString;
    }
    private String generateWhereStatement(){
        return generateLogicalOperatorStatement(WHERE_STR);
    }
    private String generateHavingStatement(){
        return generateLogicalOperatorStatement(HAVING_STR);
    }
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
    private String convertSObjectTypeNameToParent(String sObjectTypeName){
        String parentsObjectTypeName = sObjectTypeName;
        if(parentsObjectTypeName.endsWithIgnoreCase('__c')){
            parentsObjectTypeName = sObjectTypeName.substring(0,sObjectTypeName.lastIndexOfIgnoreCase('c'));
            parentsObjectTypeName += 'r';
        }
        return parentsObjectTypeName;
    }
   private Set<String> convertFieldsToParentFields(String parentsObjectTypeName,Set<String> fieldNames){
        Set<String> parentFieldNames = new Set<String>();
        for(String fieldName:fieldNames){
            parentFieldNames.add(parentsObjectTypeName+'.'+fieldName);
        }
        return parentFieldNames;
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

    public static List<String> getAllFieldNamesForSObjectType(String sObjectTypeName,Boolean includeLargeText){
        return getFieldNamesForSObject(sObjectTypeName,true,true,includeLargeText);
    }
    public static List<String> getStandardFieldNamesForSObjectType(String sObjectType){
        return getFieldNamesForSObject(sObjectType,false,true,true);
    }
    public static List<String> getCustomFieldNamesForSObjectType(String sObjectType,Boolean includeLargeText){
        return getFieldNamesForSObject(sObjectType,true,false,includeLargeText);
    }

    private static List<String> getFieldNamesForSObject(String objectType,Boolean isCustom,Boolean isStandard,Boolean includeLargeText){
        List<String> fieldNames = new List<String>();
        List<Schema.SObjectField> sObjectFields = getFieldsForSObject(objectType,isCustom,isStandard,includeLargeText);

        for(Schema.SObjectField field: sObjectFields){
            fieldNames.add(field.getDescribe().getName());
        }
        return fieldNames;
    }
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
    public static List<Schema.SObjectField> getAllFieldsForSObjectType(String sObjectTypeName){
        SObjectType type = Schema.getGlobalDescribe().get(sObjectTypeName);
        Map<String,Schema.SObjectField> sObjectFields = type.getDescribe().fields.getMap();

        return sObjectFields.values();
    }
    public static String getChildRelationshipName(String parentSobjectName, String childSobjectName) {
        SObjectType parentsObjType = ((SObject) Type.forName(parentSobjectName).newInstance())
                .getSObjectType();
        SObjectType childSObjectType = ((SObject) Type.forName(childSobjectName).newInstance())
                .getSObjectType();
        return getChildRelationshipName(parentsObjType,childSObjectType);
    }

    public static String getChildRelationshipName(SObjectType parentSObjectType, SObjectType childSObjectType) {
        for(Schema.ChildRelationship childRelationShip :parentSObjectType.getDescribe().getChildRelationships()){
            if(childRelationShip.getChildSObject() ==childSObjectType){
                return childRelationShip.getRelationshipName();
            }
        }
        return null;
    }

}