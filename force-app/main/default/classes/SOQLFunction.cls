/**
    SOQLFunction is a class that helps you to build SOQL functions like COUNT, SUM, AVG, MIN, MAX, etc.
    Supports inner functions like COUNT(COUNT(Id)) and aliases like COUNT(Id) AS Total
 */
public with sharing class SOQLFunction {

    private FunctionName name;
    private List<String> fieldNames;
    private SOQLFunction innerFunction;
    private String alias;

    public SOQLFunction(){
        this.fieldNames = new List<String>();
    }

    public FunctionName getName() {
        return name;
    }
    public String getAlias() {
        return alias;
    }
    public SOQLFunction setName(FunctionName name) {
        this.name = name;
        return this;
    }

    public List<String> getFieldNames() {
        return fieldNames;
    }

    public SOQLFunction addFieldName(String fieldName) {
        this.fieldNames.add(fieldName);
        return this;
    }
    public SOQLFunction addFieldName(SObjectField field) {
        if(this.fieldNames==null){
          this.fieldNames = new List<String>();
        }
        this.fieldNames.add(field.getDescribe().getName());
        return this;
    }
    public SOQLFunction setFieldNames(List<String> fieldNames) {
        this.fieldNames = fieldNames;
        return this;
    }
    public SOQLFunction setAlias(String alias) {
        this.alias = alias;
        return this;
    }
    public SOQLFunction getInnerFunction() {
        return innerFunction;
    }

    public SOQLFunction setInnerFunction(SOQLFunction innerFunction) {
        this.innerFunction = innerFunction;
        return this;
    }

    public static SOQLFunction of(FunctionName name){
        return new SOQLFunction().setName(name);
    }
    public static SOQLFunction of(FunctionName name,String fieldName){
        return new SOQLFunction().addFieldName(fieldName).setName(name);
    }
    public static SOQLFunction of(FunctionName name,SOQLFunction innerFunction){
        return SOQLFunction.of(name).setInnerFunction(innerFunction);
    }
    public static SOQLFunction of(FunctionName name,SObjectField field){
        return SOQLFunction.of(name,field.getDescribe().getName());
    }

    public enum FunctionName {
       COUNT,
       COUNT_DISTINCT,
        AVG,
        MIN,
        MAX,
        SUM,
        convertTimezone,
        HOUR_IN_DAY,
        CALENDAR_MONTH,
        CALENDAR_QUARTER,
        CALENDAR_YEAR,
        DAY_IN_MONTH,
        DAY_IN_WEEK,
        DAY_IN_YEAR,
        DAY_ONLY,
        FISCAL_MONTH,
        FISCAL_QUARTER,
        FISCAL_YEAR,
        WEEK_IN_MONTH,
        WEEK_IN_YEAR,
        FORMAT,
        convertCurrency,
        ROLLUP,
        GROUPING,
        CUBE
    }
    public override String toString() {
        if (innerFunction != null) {
            return this.name.name() + '(' + this.innerFunction.toString() + ')';
        }
        String fields = String.join(this.fieldNames,',');
        String alias = this.alias==null?'':+' '+this.alias;
        return this.name.name() + '(' + fields + ')'+alias;
    }

}