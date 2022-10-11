@IsTest
public with sharing class ObjectUtilTest {

    @IsTest
    public static void testRequireNonNullObjectWithObjectShouldReturnObject(){
        Object obj = new List<String>{};
        Object resultObj = ObjectUtil.requireNonNull(obj,'Message');

        System.assert(obj == resultObj);
    }
    @IsTest
    public static void testRequireNonNullObjectWithNullShouldThrowException(){
        Object obj = null;
        try {
            ObjectUtil.requireNonNull(obj, 'Message');
        }catch (Exception e) {
            System.assert(e != null);
        }
    }
    @IsTest
    public static void testRequireNonNullStringWithStringShouldReturnString(){
        String test = 'test';
        String resultTest = ObjectUtil.requireNonNull(test,'Message');

        System.assert(test.equals(resultTest));
    }
    @IsTest
    public static void testRequireNonNullStringWithNullShouldThrowException(){
        String test = null;
        try {
            ObjectUtil.requireNonNull(test, 'Message');
        }catch (Exception e) {
            System.assert(e != null);
        }
    }
    @IsTest
    public static void testRequireNonEmptyStringWithStringShouldReturnString(){
        List<String> listObj = new List<String>{'test'};
        List<Object> resultListObj = ObjectUtil.requireNonEmpty(listObj,'Message');

        System.assert(listObj == resultListObj);
    }
    @IsTest
    public static void testRequireNonEmptyListWithEmptyListShouldThrowException(){
        List<String> listObj = new List<String>{};
        try {
            ObjectUtil.requireNonEmpty(listObj, 'Message');
        }catch (Exception e) {
            System.assert(e != null);
        }
    }
    @IsTest
    public static void testRequireNonEmptyListWithNullShouldThrowException(){
        List<String> listObj = null;
        try {
            ObjectUtil.requireNonEmpty(listObj, 'Message');
        }catch (Exception e) {
            System.assert(e != null);
        }
    }
    @IsTest
    public static void testCastStringToTypeWithStringTypeShouldReturnString(){
        String test = 'test';
        String resultTest = (String) ObjectUtil.castStringToType('String',test);

        System.assert(test.equals(resultTest));
    }
    @IsTest
    public static void testCastStringToTypeWithIntegerTypeShouldReturnInteger(){
        Integer test = 1;
        Integer resultTest = (Integer) ObjectUtil.castStringToType('Integer', String.valueOf(test));

        System.assert(test == resultTest);
    }
    @IsTest
    public static void testCastStringToTypeWithDecimalTypeShouldReturnDecimal(){
        Decimal test = 1.1;
        Decimal resultTest = (Decimal) ObjectUtil.castStringToType('Decimal', String.valueOf(test));

        System.assert(test == resultTest);
    }
    @IsTest
    public static void testCastStringToTypeWithNullValueShouldReturnNull(){
        try {
            Decimal test = null;
           Object obj = ObjectUtil.castStringToType('Decimal', String.valueOf(test));
            System.assertEquals(null,obj);
        }catch (TypeException e) {
            System.assert(e != null);
        }
    }
    @IsTest
    public static void testCastStringToTypeWithEmptyStringShouldReturnNull(){
       Object object1 =  ObjectUtil.castStringToType('String','');
       Object object2 =  ObjectUtil.castStringToType('String','   ');
       System.assertEquals(null,object1);
       System.assertEquals(null,object2);
    }

    @IsTest
    public static void testCastStringToTypeWithNotValidTypeShouldReturnValue(){
        String test = 'test';
        String resultTest = (String) ObjectUtil.castStringToType('String2',test);

        System.assert(resultTest == test);
    }
    @IsTest
    public static void testCastStringToTypeWithDateTypeShouldReturnDate(){
        Date dateT = Date.valueOf('2022-03-16');
        Date resultTest = (Date) ObjectUtil.castStringToType('Date', String.valueOf(dateT));

        System.assertEquals(String.valueOf(dateT),String.valueOf(resultTest));
    }
    @IsTest
    public static void testCastStringToTypeWithDateTimeTypeShouldReturnDateTime(){
        Datetime dTime = Datetime.valueOf('2022-03-16 09:42:28');
        Datetime resultTest = (Datetime) ObjectUtil.castStringToType('Datetime', dTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));

        System.assertEquals(String.valueOf(dTime),String.valueOf(resultTest));
    }
    @IsTest
    public static void testIsMapShouldReturnBoolean(){
       Map<String,String> stringMap = new Map<String,String>{'sd'=>'as'};
       System.assert(ObjectUtil.isMap(stringMap));
    }
    @IsTest
    public static void testGetTypeShouldReturnType(){
        String str = 'asd';
        Integer intN = 1;
        System.assert(ObjectUtil.getType(str) == 'String');
        System.assert(ObjectUtil.getType(intN) == 'Integer');
    }
    @IsTest
    public static void testGetStandardPricebookId(){
        try{
            Id priceBookId = ObjectUtil.getStandardPricebookId();

        }catch (Exception e){
            System.assert(e.getMessage().contains('Standard Pricebook Id not found'));
        }

    }
}