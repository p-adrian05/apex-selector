global with sharing class ObjectUtil {

    private static Id STANDARD_PRICEBOOK_ID = null;

    global static Object requireNonNull(Object obj, String message){
        if (obj == null){
            throw new IllegalArgumentException(message);
        }
        return obj;
    }
    global static String requireNonNull(String str, String message){
        if (str == null){
            throw new IllegalArgumentException(message);
        }
        return str;
    }
    global static List<Object> requireNonEmpty(List<Object> objs, String message){
        if(objs == null){
            requireNonNull(objs,message);
        }else if (objs?.size()==0){
            throw new IllegalArgumentException(message);
        }
        return objs;
    }
    /**
     * Try to cast a String value which can be the types below.
     *  ********Date Time****
     * In the case of Datetime, the value should be serialized in gmt format like: 2022-03-16T10:20:44.431Z
     * For example: Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
     *
     * @param type The of the value in String, such as: Integer, String, Decimal,Date, Datetime
     * @param value A string value to cast with the given type.

     *
     * @return an Object that is casted for the desired type.
     */
    global static Object castStringToType(String type,String value){
        if(value == null || value == '' || value.isWhitespace()){
            return null;
        }
        try{
            switch on type {
                when 'String'{
                    return value;
                }
                when 'Decimal'{
                    return Decimal.valueOf(value);
                }
                when 'Integer'{
                    return Integer.valueOf(value);
                }
                when 'Date'{
                    return (Date) JSON.deserialize('"'+value+'"',Date.class);
                }
                when 'Datetime'{
                    return (Datetime) JSON.deserialize('"'+value+'"',Datetime.class);
                }
                when 'Boolean'{
                    return Boolean.valueOf(value.toLowerCase());
                }
            }
        }catch (Exception e){
            throw new TypeException('Failed to cast value: '+value+' to type: '+type+': '+ e.getMessage());
        }
        return value;
    }

    global static Boolean isMap(Object obj) {
        if(obj == null){
            return false;
        }
        String str = String.valueOf(obj);
        String firstCharacter = str.substring(0, 1);
        String lastCharacter = str.substring(str.length() - 1, str.length());
        return !(obj instanceof String)
                && '{'.equals(firstCharacter)
                && '}'.equals(lastCharacter);
    }
    global static String getType(Object o) {
        if(o==null) return '';              // we can't say much about null with our current techniques
        if(o instanceof SObject)            return ((SObject)o).getSObjectType().getDescribe().getName()+'';
        if(o instanceof Boolean)            return 'Boolean';
        if(o instanceof Id)                 return 'Id';
        if(o instanceof String)             return 'String';
        if(o instanceof Blob)               return 'Blob';
        if(o instanceof Date)               return 'Date';
        if(o instanceof Datetime)           return 'Datetime';
        if(o instanceof Time)               return 'Time';
        if(o instanceof String)             return 'String';
        if(o instanceof Integer)            return 'Integer';
        if(o instanceof Long)               return 'Long';
        if(o instanceof Decimal)            return 'Decimal';  // we can't distinguish between decimal and double
        if(o instanceof Double)             return 'Double';   // we can't distinguish between decimal and double
        if(o instanceof List<Object>)       return 'List';
        return 'Object';                    // actually we can't detect maps and sets and maps
    }

    global static Id getStandardPricebookId(){
        if(STANDARD_PRICEBOOK_ID == null){
            List<Pricebook2> pricebooks = [SELECT Id FROM Pricebook2 ORDER BY CreatedDate ASC LIMIT 1];
            if(pricebooks == null || pricebooks.size()==0){
                throw new SObjectException('Standard Pricebook Id not found!');
            }
            STANDARD_PRICEBOOK_ID = pricebooks.get(0).Id;
        }
        return STANDARD_PRICEBOOK_ID;
    }
}